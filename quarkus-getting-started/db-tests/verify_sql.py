#!/usr/bin/env python3
"""
Verificación de la capa SQL contra un PostgreSQL REAL (Neon o local).

Aplica las migraciones de src/main/resources/db/migration y ejecuta los MISMOS
archivos .sql de src/main/resources/sql que usa el backend Quarkus, con la misma
conversión de parámetros nombrados (:nombre).

Uso:
    export VERIFY_DSN="postgresql://usuario:clave@host/db?sslmode=require"   # base DESECHABLE (ej. rama de Neon)
    python3 verify_sql.py            # aplica migraciones si la base está vacía y corre las pruebas
    python3 verify_sql.py --reset    # borra el esquema public antes (¡destructivo!)

NUNCA lo apuntes a la base de producción con --reset.
"""
import os, re, sys, uuid, glob, datetime
from decimal import Decimal
import psycopg2, psycopg2.extras

ROOT = os.path.join(os.path.dirname(__file__), "..", "src", "main", "resources")
DSN = os.environ.get("VERIFY_DSN")
if not DSN:
    sys.exit("Defina VERIFY_DSN (ver cabecera del archivo).")

def sql_file(name):
    with open(os.path.join(ROOT, "sql", name + ".sql"), encoding="utf-8") as f:
        return f.read()

def convert(sql):
    """:nombre -> %(nombre)s (ignora ::cast, comillas simples y escapa %)."""
    out, i, quote = [], 0, False
    while i < len(sql):
        ch = sql[i]
        if ch == "'":
            quote = not quote; out.append(ch)
        elif ch == "%":
            out.append("%%")
        elif not quote and ch == ":" and sql[i + 1:i + 2] == ":":
            out.append("::"); i += 1
        elif not quote and ch == ":" and re.match(r"[A-Za-z_]", sql[i + 1:i + 2] or " "):
            m = re.match(r"[A-Za-z_][A-Za-z0-9_]*", sql[i + 1:])
            out.append("%(" + m.group(0) + ")s"); i += len(m.group(0))
        else:
            out.append(ch)
        i += 1
    return "".join(out)

conn = psycopg2.connect(DSN)
conn.autocommit = False

def run(name, **params):
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute(convert(sql_file(name)), params)
        return cur.fetchall() if cur.description else []

DEFAULT_FILTROS = dict(q=None, categoria_id=None, marca_id=None, establecimiento_id=None, ciudad=None,
                       precio_min=None, precio_max=None, orden="nombre", limite=50, desplazamiento=0)

def buscar(**kw):
    p = dict(DEFAULT_FILTROS); p.update(kw)
    return run("buscar_productos", **p)

def registrar(nombre="Leche entera", marca="Alquería", categoria="Lácteos y huevos", presentacion="Bolsa",
              cantidad=1100, unidad="ml", almacen="Éxito", sede="Éxito Chapinero", ciudad="Bogotá",
              precio=4500, fecha=None, usuario_id=None, producto_id=None, foto=None, foto_tipo=None,
              descripcion=None, direccion=None):
    if producto_id is None:
        r = run("registrar_producto", nombre=nombre, descripcion=descripcion, marca=marca, categoria=categoria,
                presentacion=presentacion, cantidad=cantidad, unidad=unidad,
                foto=psycopg2.Binary(foto) if foto else None, foto_tipo=foto_tipo, usuario_id=usuario_id)[0]
        producto_id, nuevo = r["producto_id"], r["nuevo"]
    else:
        nuevo = False
    rep = run("registrar_precio", producto_id=producto_id, almacen=almacen, sede=sede, ciudad=ciudad,
              direccion=direccion, precio=precio, fecha=fecha, usuario_id=usuario_id)[0]["reporte_id"]
    return producto_id, rep, nuevo

passed, failed = 0, 0
def check(desc, cond):
    global passed, failed
    if cond: passed += 1; print("  OK   ", desc)
    else:    failed += 1; print("  FALLA", desc)

def expect_error(desc, fn, sqlstate):
    global passed, failed
    try:
        fn(); conn.rollback(); failed += 1; print("  FALLA", desc, "(no hubo error)")
    except psycopg2.Error as e:
        conn.rollback()
        if e.pgcode == sqlstate: passed += 1; print("  OK   ", desc, "->", e.pgcode)
        else: failed += 1; print("  FALLA", desc, "SQLSTATE", e.pgcode, str(e).strip()[:100])

# ---------------------------------------------------------------- migraciones
if "--reset" in sys.argv:
    with conn.cursor() as cur:
        cur.execute("DROP SCHEMA public CASCADE; CREATE SCHEMA public;")
    conn.commit()
with conn.cursor() as cur:
    cur.execute("SELECT to_regclass('public.reportes_precio') IS NOT NULL")
    existe = cur.fetchone()[0]
if not existe:
    print("Aplicando migraciones...")
    for f in sorted(glob.glob(os.path.join(ROOT, "db", "migration", "V*.sql"))):
        with open(f, encoding="utf-8") as fh, conn.cursor() as cur:
            cur.execute(fh.read())
        print("  ", os.path.basename(f))
    conn.commit()

T = uuid.uuid4().hex[:6]            # sufijo único: la prueba no choca con datos existentes
hoy = run("detalle_producto", producto_id=0) or None  # (consulta válida, sin filas)
with conn.cursor() as cur:
    cur.execute("SELECT hoy_colombia()"); HOY = cur.fetchone()[0]

print("\n1. Usuarios")
u = run("crear_usuario", nombre="Juan Prueba", email=f"juan.{T}@example.com")[0]
u2 = run("crear_usuario", nombre="Juan P.", email=f"JUAN.{T}@example.com")[0]
conn.commit()
check("crear usuario devuelve id", u["id"] > 0)
check("mismo correo (sin importar mayúsculas) reutiliza el usuario", u2["id"] == u["id"])
expect_error("correo inválido rechazado", lambda: run("crear_usuario", nombre="Ana Gómez", email="no-es-correo"), "23514")

print("\n2. Registro de productos y precios")
nombre = f"Leche entera {T}"
pid, rep1, nuevo = registrar(nombre=nombre, usuario_id=u["id"], precio=4500, fecha=HOY - datetime.timedelta(days=60),
                             foto=b"\xff\xd8\xff\xe0fakejpeg", foto_tipo="image/jpeg", descripcion="Leche UHT")
conn.commit()
check("producto nuevo creado", nuevo and pid > 0 and rep1 > 0)
pid2, rep2, nuevo2 = registrar(nombre=nombre.upper(), marca="  alquería ", presentacion="BOLSA", usuario_id=u["id"],
                               almacen="D1", sede="D1 Suba", ciudad="Bogotá", precio=3900, fecha=HOY - datetime.timedelta(days=2))
conn.commit()
check("mismo producto (otra capitalización/espacios) NO se duplica", pid2 == pid and not nuevo2)
registrar(producto_id=pid, almacen="Ara", sede="Ara Kennedy", ciudad="Bogotá", precio=4100, fecha=HOY - datetime.timedelta(days=5), usuario_id=u["id"])
registrar(producto_id=pid, almacen="Éxito", sede="Éxito Laureles", ciudad="Medellín", precio=4700, fecha=HOY, usuario_id=u["id"])
# nuevo reporte en una sede ya existente (cambio de precio) -> historial
registrar(producto_id=pid, almacen="Éxito", sede="Éxito Chapinero", ciudad="Bogotá", precio=5000, fecha=HOY - datetime.timedelta(days=1), usuario_id=u["id"])
conn.commit()
with conn.cursor() as cur:
    cur.execute("SELECT count(*) FROM marcas WHERE lower(nombre)='alquería'"); check("la marca no se duplicó", cur.fetchone()[0] == 1)
    cur.execute("SELECT count(*) FROM sedes WHERE lower(nombre)='éxito chapinero'"); check("la sede no se duplicó", cur.fetchone()[0] == 1)
    cur.execute("SELECT count(*) FROM reportes_precio WHERE producto_id=%s", (pid,)); check("5 reportes guardados (historial conservado)", cur.fetchone()[0] == 5)
    cur.execute("SELECT foto_tipo, descripcion FROM productos WHERE id=%s", (pid,)); check("foto y descripción guardadas", cur.fetchone() == ("image/jpeg", "Leche UHT"))
foto = run("foto_producto", producto_id=pid)
check("foto recuperable (bytea)", len(foto) == 1 and bytes(foto[0]["foto"]).startswith(b"\xff\xd8"))

print("\n3. Validaciones")
expect_error("precio 0 rechazado", lambda: registrar(producto_id=pid, precio=0), "22023")
expect_error("precio negativo rechazado", lambda: registrar(producto_id=pid, precio=-5), "22023")
expect_error("fecha futura rechazada", lambda: registrar(producto_id=pid, fecha=HOY + datetime.timedelta(days=3)), "22023")
expect_error("fecha de hace >2 años rechazada", lambda: registrar(producto_id=pid, fecha=HOY - datetime.timedelta(days=800)), "22023")
expect_error("producto inexistente -> P0002", lambda: registrar(producto_id=999999999), "P0002")
expect_error("unidad inválida rechazada", lambda: registrar(nombre=f"X{T}", unidad="galon"), "22023")
expect_error("cantidad 0 rechazada", lambda: registrar(nombre=f"X{T}", cantidad=0), "22023")
expect_error("marca vacía rechazada", lambda: registrar(nombre=f"X{T}", marca="   "), "22023")
expect_error("usuario inexistente (FK) rechazado", lambda: registrar(nombre=f"Y{T}", usuario_id=999999999), "23503")

print("\n4. Catálogo, búsqueda y filtros combinables")
otro, _, _ = registrar(nombre=f"Arroz blanco {T}", marca="Diana", categoria="Granos y cereales", presentacion="Bolsa",
                       cantidad=500, unidad="g", almacen="Jumbo", sede="Jumbo Calle 80", ciudad="Bogotá", precio=3200, fecha=HOY)
conn.commit()
r = buscar(q=T)
check("búsqueda por texto encuentra ambos productos", {x["id"] for x in r} == {pid, otro})
check("búsqueda ignora tildes y mayúsculas", {x["id"] for x in buscar(q=f"LECHE ENTERA {T}")} == {pid})
check("búsqueda por marca", pid in {x["id"] for x in buscar(q="alqueria")})
cat_id = run("categorias")[0]["id"]
with conn.cursor() as cur:
    cur.execute("SELECT id FROM categorias WHERE nombre='Granos y cereales'"); granos = cur.fetchone()[0]
    cur.execute("SELECT id FROM marcas WHERE nombre='Diana'"); diana = cur.fetchone()[0]
    cur.execute("SELECT id FROM establecimientos WHERE nombre='D1'"); d1 = cur.fetchone()[0]
check("filtro categoría", {x["id"] for x in buscar(q=T, categoria_id=granos)} == {otro})
check("filtro marca", {x["id"] for x in buscar(q=T, marca_id=diana)} == {otro})
check("filtro almacén (D1)", {x["id"] for x in buscar(q=T, establecimiento_id=d1)} == {pid})
check("filtro ciudad Medellín", {x["id"] for x in buscar(q=T, ciudad="medellín")} == {pid})
check("filtro rango de precio 3000-3500", {x["id"] for x in buscar(q=T, precio_min=3000, precio_max=3500)} == {otro})
check("rango 3800-4000 coincide con precio vigente de D1", {x["id"] for x in buscar(q=T, precio_min=3800, precio_max=4000)} == {pid})
check("el precio histórico viejo (4500 Éxito) ya no cuenta como vigente", pid not in {x["id"] for x in buscar(q=T, precio_min=4400, precio_max=4600)})
check("combinación: categoría + ciudad + precio", {x["id"] for x in buscar(q=T, categoria_id=granos, ciudad="Bogotá", precio_max=3500)} == {otro})
check("combinación sin coincidencias -> vacío", buscar(q=T, categoria_id=granos, ciudad="Medellín") == [])
orden = [x["id"] for x in buscar(q=T, orden="precio_asc")]
check("orden por precio ascendente", orden == [otro, pid])
orden = [x["id"] for x in buscar(q=T, orden="precio_desc")]
check("orden por precio descendente", orden == [pid, otro])
fila = [x for x in buscar(q=T) if x["id"] == pid][0]
check("resumen: mín 3900, máx 5000, 4 sedes", (fila["precio_min"], fila["precio_max"], fila["n_sedes"]) == (Decimal("3900.00"), Decimal("5000.00"), 4))
check("resumen: mejor almacén D1", fila["mejor_almacen"] == "D1" and fila["tiene_foto"])
check("paginación + total", len(buscar(q=T, limite=1)) == 1 and buscar(q=T, limite=1)[0]["total"] == 2)
check("el texto con % no actúa como comodín", buscar(q="%") == [])

print("\n5. Comparador de precios")
comp = run("comparar_precios", producto_id=pid, ciudad=None, establecimiento_id=None, dias_vigencia=30)
precios = [c["precio_cop"] for c in comp]
check("4 sedes ordenadas de menor a mayor", precios == sorted(precios) and len(comp) == 4)
check("el más barato es D1 Suba y está marcado", comp[0]["sede"] == "D1 Suba" and comp[0]["es_mas_barato"] and not any(c["es_mas_barato"] for c in comp[1:]))
check("diferencias: Ara +200 (5.1%), Éxito Chapinero +1100 (28.2%)",
      comp[1]["diferencia_cop"] == Decimal("200.00") and comp[1]["diferencia_pct"] == Decimal("5.1")
      and comp[-1]["diferencia_cop"] == Decimal("1100.00") and comp[-1]["diferencia_pct"] == Decimal("28.2"))
check("mín/máx/promedio", (comp[0]["minimo"], comp[0]["maximo"], comp[0]["promedio"]) == (Decimal("3900.00"), Decimal("5000.00"), Decimal("4425.00")))
check("la sede con el precio de hace 60 días NO aparece (se usa su reporte más reciente 1 día)", all(c["precio_cop"] != Decimal("4500.00") for c in comp))
solo_bog = run("comparar_precios", producto_id=pid, ciudad="bogotá", establecimiento_id=None, dias_vigencia=30)
check("comparar solo en Bogotá -> 3 sedes", len(solo_bog) == 3)
# producto con un precio viejo: advertencia de desactualizado
viejo, _, _ = registrar(nombre=f"Aceite {T}", marca="Gourmet", categoria="Despensa", presentacion="Botella", cantidad=1000, unidad="ml",
                        almacen="Olímpica", sede="Olímpica Centro", ciudad="Cali", precio=12000, fecha=HOY - datetime.timedelta(days=45))
conn.commit()
c = run("comparar_precios", producto_id=viejo, ciudad=None, establecimiento_id=None, dias_vigencia=30)[0]
check("precio de 45 días marcado como desactualizado", c["desactualizado"] and c["dias"] == 45)
check("precio de ayer NO desactualizado", not comp[-1]["desactualizado"])
b = [x for x in buscar(q=f"Aceite {T}")][0]
check("el catálogo también advierte antigüedad (dias_ultima=45)", b["dias_ultima"] == 45)

print("\n6. Historial")
h = run("historial_producto", producto_id=pid, sede_id=None, dias_vigencia=30, limite=100)
check("5 reportes, el más reciente primero", len(h) == 5 and h[0]["fecha"] == HOY.isoformat())
chap = [x for x in h if x["sede"] == "Éxito Chapinero"]
check("variación de Éxito Chapinero: 4500 -> 5000 (+500)", [x["variacion_cop"] for x in chap] == [Decimal("500.00"), None])
check("el reporte de hace 60 días queda marcado desactualizado", chap[-1]["desactualizado"] and chap[-1]["dias"] == 60)
check("usuario reportante visible (el nombre se actualiza al re-registrar el mismo correo)", h[0]["usuario"] == "Juan P.")
check("historial filtrado por sede", len(run("historial_producto", producto_id=pid, sede_id=chap[0]["sede_id"], dias_vigencia=30, limite=100)) == 2)

print("\n7. Catálogos")
check("categorías sembradas (>=13)", len(run("categorias")) >= 13)
check("establecimientos sembrados incluyen Éxito, D1, Ara", {"Éxito", "D1", "Ara"} <= {x["nombre"] for x in run("establecimientos")})
check("ciudades distintas", {"Bogotá", "Medellín", "Cali"} <= {x["ciudad"] for x in run("ciudades")})
check("sedes por almacén", {s["nombre"] for s in run("sedes", establecimiento_id=d1, ciudad=None)} >= {"D1 Suba"})
check("detalle de producto", run("detalle_producto", producto_id=pid)[0]["marca"] == "Alquería")

print("\n8. Persistencia entre conexiones/dispositivos")
conn2 = psycopg2.connect(DSN)
with conn2.cursor() as cur:
    cur.execute("SELECT count(*) FROM reportes_precio WHERE producto_id=%s", (pid,))
    check("una conexión nueva (otro usuario/dispositivo) ve los 5 reportes", cur.fetchone()[0] == 5)
conn2.close()

print("\n9. Idempotencia de la migración de datos base")
with open(os.path.join(ROOT, "db", "migration", "V3__datos_base.sql"), encoding="utf-8") as fh, conn.cursor() as cur:
    cur.execute("SELECT count(*) FROM categorias"); a = cur.fetchone()[0]
    cur.execute(fh.read())
    cur.execute("SELECT count(*) FROM categorias"); check("V3 se puede re-ejecutar sin duplicar", a == cur.fetchone()[0])
conn.commit()

print(f"\nResultado: {passed} correctas, {failed} fallidas")
sys.exit(1 if failed else 0)
