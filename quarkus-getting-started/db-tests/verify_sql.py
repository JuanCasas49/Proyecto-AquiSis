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
              descripcion=None, direccion=None, estado="validado", evidencia=None, evidencia_tipo=None):
    if producto_id is None:
        r = run("registrar_producto", nombre=nombre, descripcion=descripcion, marca=marca, categoria=categoria,
                presentacion=presentacion, cantidad=cantidad, unidad=unidad,
                foto=psycopg2.Binary(foto) if foto else None, foto_tipo=foto_tipo, usuario_id=usuario_id)[0]
        producto_id, nuevo = r["producto_id"], r["nuevo"]
    else:
        nuevo = False
    rep = run("registrar_precio", producto_id=producto_id, almacen=almacen, sede=sede, ciudad=ciudad,
              direccion=direccion, precio=precio, fecha=fecha, usuario_id=usuario_id, estado=estado,
              evidencia=psycopg2.Binary(evidencia) if evidencia else None, evidencia_tipo=evidencia_tipo)[0]["reporte_id"]
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

# ============================================================ HU-08 =========
print("\n10. HU-08 Registro colaborativo: estado pendiente + evidencia")
def moderador(nombre):
    m = run("crear_usuario", nombre=nombre, email=f"mod.{nombre}.{T}@example.com")[0]
    with conn.cursor() as cur:
        cur.execute("UPDATE usuarios SET rol='moderador' WHERE id=%s", (m["id"],))
    conn.commit()
    return m["id"]

base_pid, _, _ = registrar(nombre=f"Yogur {T}", marca="Alpina", categoria="Lácteos y huevos", presentacion="Vaso",
                           cantidad=150, unidad="g", almacen="Éxito", sede="Éxito Usaquén", ciudad="Bogotá",
                           precio=2000, usuario_id=u["id"])
conn.commit()
check("usuario nuevo tiene rol 'usuario'", u["rol"] == "usuario")
jpg = b"\xff\xd8\xff\xe0evidencia"
_, rep_pend, _ = registrar(producto_id=base_pid, almacen="D1", sede="D1 Usaquén", ciudad="Bogotá", precio=1500,
                           usuario_id=u["id"], estado="pendiente", evidencia=jpg, evidencia_tipo="image/jpeg")
conn.commit()
comp = run("comparar_precios", producto_id=base_pid, ciudad=None, establecimiento_id=None, dias_vigencia=30)
check("el precio pendiente NO entra al comparador (solo el validado)", [c["almacen"] for c in comp] == ["Éxito"])
h = run("historial_producto", producto_id=base_pid, sede_id=None, dias_vigencia=30, limite=50)
pend = [x for x in h if x["estado"] == "pendiente"]
check("el historial muestra el reporte pendiente con evidencia", len(pend) == 1 and pend[0]["tiene_evidencia"] and pend[0]["variacion_cop"] is None)
fila = [x for x in buscar(q=f"Yogur {T}")][0]
check("el catálogo cuenta 1 pendiente y su precio mínimo sigue siendo el validado", fila["n_pendientes"] == 1 and fila["precio_min"] == Decimal("2000.00"))
ev = run("evidencia_reporte", reporte_id=rep_pend)
check("la evidencia se puede recuperar", len(ev) == 1 and bytes(ev[0]["evidencia"]) == jpg and ev[0]["evidencia_tipo"] == "image/jpeg")
check("reporte validado sin evidencia: no hay evidencia que devolver", run("evidencia_reporte", reporte_id=rep1) == [])
solo_pend, _, _ = registrar(nombre=f"Queso {T}", marca="Colanta", categoria="Lácteos y huevos", presentacion="Bloque",
                            cantidad=500, unidad="g", almacen="Ara", sede="Ara Suba", ciudad="Bogotá", precio=9000,
                            usuario_id=u["id"], estado="pendiente")
conn.commit()
q = buscar(q=f"Queso {T}")[0]
check("un producto con solo precios pendientes aparece sin precio oficial", q["precio_min"] is None and q["n_pendientes"] == 1 and q["n_sedes"] == 0)
check("y no aparece al filtrar por precio o almacén", buscar(q=f"Queso {T}", precio_min=1) == [])
mis = run("mis_reportes", usuario_id=u["id"], estado="pendiente", limite=50)
check("'mis reportes' filtra por estado", {m["reporte_id"] for m in mis} >= {rep_pend} and all(m["estado"] == "pendiente" for m in mis))
check("la cola de moderación incluye los pendientes", rep_pend in {x["reporte_id"] for x in run("reportes_pendientes", limite=500)})
expect_error("estado inicial inválido rechazado", lambda: registrar(producto_id=base_pid, estado="aprobado"), "22023")
expect_error("evidencia sin tipo rechazada", lambda: registrar(producto_id=base_pid, evidencia=jpg, evidencia_tipo=None), "22023")
expect_error("evidencia con tipo no permitido (check)", lambda: registrar(producto_id=base_pid, evidencia=jpg, evidencia_tipo="application/pdf"), "23514")

print("\n10b. Validación por moderador")
expect_error("un usuario común no puede validar -> P0403", lambda: run("validar_reporte", reporte_id=rep_pend, usuario_id=u["id"]), "P0403")
mod = moderador("ana")
expect_error("validar un reporte inexistente -> P0002", lambda: run("validar_reporte", reporte_id=999999999, usuario_id=mod), "P0002")
run("validar_reporte", reporte_id=rep_pend, usuario_id=mod); conn.commit()
comp = run("comparar_precios", producto_id=base_pid, ciudad=None, establecimiento_id=None, dias_vigencia=30)
check("al validarse, el precio entra al comparador y es el más barato", [c["almacen"] for c in comp] == ["D1", "Éxito"] and comp[0]["es_mas_barato"])
check("el catálogo ya no cuenta pendientes", buscar(q=f"Yogur {T}")[0]["n_pendientes"] == 0)
expect_error("validar dos veces -> P0409", lambda: run("validar_reporte", reporte_id=rep_pend, usuario_id=mod), "P0409")
with conn.cursor() as cur:
    cur.execute("SELECT estado, validado_por, validado_en IS NOT NULL FROM reportes_precio WHERE id=%s", (rep_pend,))
    check("queda registrado quién y cuándo validó", cur.fetchone() == ("validado", mod, True))
_, rep_rech, _ = registrar(producto_id=base_pid, almacen="Ara", sede="Ara Usaquén", ciudad="Bogotá", precio=100,
                           usuario_id=u["id"], estado="pendiente", evidencia=jpg, evidencia_tipo="image/jpeg")
conn.commit()
expect_error("usuario común no puede rechazar -> P0403", lambda: run("rechazar_reporte", reporte_id=rep_rech, usuario_id=u["id"], motivo="x"), "P0403")
expect_error("motivo demasiado largo -> 22023", lambda: run("rechazar_reporte", reporte_id=rep_rech, usuario_id=mod, motivo="x" * 201), "22023")
run("rechazar_reporte", reporte_id=rep_rech, usuario_id=mod, motivo="  Foto ilegible  "); conn.commit()
comp = run("comparar_precios", producto_id=base_pid, ciudad=None, establecimiento_id=None, dias_vigencia=30)
check("un precio rechazado NO entra al comparador", "Ara" not in [c["almacen"] for c in comp])
h = run("historial_producto", producto_id=base_pid, sede_id=None, dias_vigencia=30, limite=50)
rech = [x for x in h if x["estado"] == "rechazado"]
check("el historial conserva el rechazo con su motivo", len(rech) == 1 and rech[0]["motivo_rechazo"] == "Foto ilegible")
expect_error("rechazar uno ya procesado -> P0409", lambda: run("rechazar_reporte", reporte_id=rep_rech, usuario_id=mod, motivo="x"), "P0409")
check("la cola de moderación ya no incluye los procesados", rep_pend not in {x["reporte_id"] for x in run("reportes_pendientes", limite=500)}
      and rep_rech not in {x["reporte_id"] for x in run("reportes_pendientes", limite=500)})
check("usuario_por_id devuelve el rol", run("usuario_por_id", usuario_id=mod)[0]["rol"] == "moderador")

# ============================================================ HU-06 =========
print("\n11. HU-06 Listas de mercado")
def lista_nueva(usuario, nombre): 
    r = run("crear_lista", usuario_id=usuario, nombre=nombre)[0]["id"]; conn.commit(); return r
ana = run("crear_usuario", nombre="Ana Listas", email=f"ana.l.{T}@example.com")[0]["id"]
beto = run("crear_usuario", nombre="Beto Listas", email=f"beto.l.{T}@example.com")[0]["id"]
conn.commit()
semana = lista_nueva(ana, "  Compra   de la semana ")
fiesta = lista_nueva(ana, "Fiesta")
check("se pueden crear varias listas con nombre propio", semana != fiesta and len(run("listas_usuario", usuario_id=ana)) == 2)
check("el nombre se normaliza", run("lista_cabecera", lista_id=semana, usuario_id=ana)[0]["nombre"] == "Compra de la semana")
expect_error("nombre repetido (sin importar mayúsculas) -> P0409", lambda: run("crear_lista", usuario_id=ana, nombre="FIESTA"), "P0409")
check("otro usuario puede usar el mismo nombre", lista_nueva(beto, "Fiesta") > 0)
expect_error("nombre vacío -> 22023", lambda: run("crear_lista", usuario_id=ana, nombre="   "), "22023")
expect_error("nombre muy largo -> 22023", lambda: run("crear_lista", usuario_id=ana, nombre="x" * 81), "22023")
expect_error("usuario inexistente -> P0002", lambda: run("crear_lista", usuario_id=999999999, nombre="Z"), "P0002")
check("una lista ajena no se puede consultar", run("lista_cabecera", lista_id=semana, usuario_id=beto) == [])
check("agregar producto devuelve la cantidad", run("agregar_item_lista", lista_id=semana, usuario_id=ana, producto_id=pid, cantidad=2)[0]["cantidad"] == 2)
conn.commit()
check("agregar de nuevo el mismo producto suma la cantidad", run("agregar_item_lista", lista_id=semana, usuario_id=ana, producto_id=pid, cantidad=3)[0]["cantidad"] == 5)
conn.commit()
run("agregar_item_lista", lista_id=semana, usuario_id=ana, producto_id=otro, cantidad=1); conn.commit()
items = run("lista_items", lista_id=semana)
check("la lista tiene 2 productos con su cantidad", {(i["producto_id"], i["cantidad"]) for i in items} == {(pid, 5), (otro, 1)})
check("modificar la cantidad", run("modificar_item_lista", lista_id=semana, usuario_id=ana, producto_id=pid, cantidad=7)[0]["cantidad"] == 7)
conn.commit()
check("la cantidad modificada se refleja", [i["cantidad"] for i in run("lista_items", lista_id=semana) if i["producto_id"] == pid] == [7])
check("resumen de listas: 2 productos y 8 unidades", [(l["n_productos"], l["n_unidades"]) for l in run("listas_usuario", usuario_id=ana) if l["id"] == semana] == [(2, 8)])
for c in (0, -1, 1000):
    expect_error(f"cantidad {c} fuera de 1..999 -> 22023", lambda c=c: run("modificar_item_lista", lista_id=semana, usuario_id=ana, producto_id=pid, cantidad=c), "22023")
expect_error("agregar con cantidad 0 -> 22023", lambda: run("agregar_item_lista", lista_id=semana, usuario_id=ana, producto_id=pid, cantidad=0), "22023")
expect_error("modificar un producto que no está -> P0002", lambda: run("modificar_item_lista", lista_id=fiesta, usuario_id=ana, producto_id=pid, cantidad=2), "P0002")
expect_error("producto inexistente -> P0002", lambda: run("agregar_item_lista", lista_id=semana, usuario_id=ana, producto_id=999999999, cantidad=1), "P0002")
expect_error("agregar en lista ajena -> P0002", lambda: run("agregar_item_lista", lista_id=semana, usuario_id=beto, producto_id=pid, cantidad=1), "P0002")
expect_error("modificar en lista ajena -> P0002", lambda: run("modificar_item_lista", lista_id=semana, usuario_id=beto, producto_id=pid, cantidad=1), "P0002")
expect_error("quitar en lista ajena -> P0002", lambda: run("quitar_item_lista", lista_id=semana, usuario_id=beto, producto_id=pid), "P0002")
run("agregar_item_lista", lista_id=semana, usuario_id=ana, producto_id=pid, cantidad=999); conn.commit()
check("la suma se limita a 999", [i["cantidad"] for i in run("lista_items", lista_id=semana) if i["producto_id"] == pid] == [999])
run("quitar_item_lista", lista_id=semana, usuario_id=ana, producto_id=otro); conn.commit()
check("eliminar un producto de la lista", [i["producto_id"] for i in run("lista_items", lista_id=semana)] == [pid])
expect_error("quitar un producto que no está -> P0002", lambda: run("quitar_item_lista", lista_id=semana, usuario_id=ana, producto_id=otro), "P0002")
run("renombrar_lista", lista_id=semana, usuario_id=ana, nombre="Mercado quincenal"); conn.commit()
check("renombrar la lista", run("lista_cabecera", lista_id=semana, usuario_id=ana)[0]["nombre"] == "Mercado quincenal")
expect_error("renombrar a un nombre existente -> P0409", lambda: run("renombrar_lista", lista_id=semana, usuario_id=ana, nombre="fiesta"), "P0409")
expect_error("renombrar lista ajena -> P0002", lambda: run("renombrar_lista", lista_id=semana, usuario_id=beto, nombre="Mía"), "P0002")
expect_error("eliminar lista ajena -> P0002", lambda: run("eliminar_lista", lista_id=semana, usuario_id=beto), "P0002")
run("eliminar_lista", lista_id=semana, usuario_id=ana); conn.commit()
with conn.cursor() as cur:
    cur.execute("SELECT count(*) FROM lista_items WHERE lista_id=%s", (semana,))
    check("al eliminar la lista se eliminan sus productos (cascada)", cur.fetchone()[0] == 0)
check("la lista eliminada ya no existe", run("lista_cabecera", lista_id=semana, usuario_id=ana) == [])
# límite de 100 productos por lista
muchos = lista_nueva(ana, "Muchos")
with conn.cursor() as cur:
    for i in range(100):
        cur.execute("INSERT INTO productos (nombre, marca_id, categoria_id, presentacion, cantidad, unidad) "
                    "SELECT %s, id, (SELECT min(id) FROM categorias), 'Bolsa', 1, 'un' FROM marcas WHERE nombre='Alquería'", (f"Relleno {T} {i}",))
    cur.execute("INSERT INTO lista_items (lista_id, producto_id, cantidad) SELECT %s, id, 1 FROM productos WHERE nombre LIKE %s", (muchos, f"Relleno {T} %"))
conn.commit()
expect_error("una lista admite máximo 100 productos -> 22023", lambda: run("agregar_item_lista", lista_id=muchos, usuario_id=ana, producto_id=pid, cantidad=1), "22023")
check("pero se puede aumentar la cantidad de uno que ya está", run("agregar_item_lista", lista_id=muchos, usuario_id=ana,
      producto_id=run("lista_items", lista_id=muchos)[0]["producto_id"], cantidad=2)[0]["cantidad"] == 3)
conn.commit()

# ============================================================ HU-07 =========
print("\n12. HU-07 Valor total y ahorro de la lista por supermercado")
tz = HOY
def prod(nombre, marca, cat, pres, cant, uni):
    r = run("registrar_producto", nombre=f"{nombre} {T}", descripcion=None, marca=marca, categoria=cat, presentacion=pres,
            cantidad=cant, unidad=uni, foto=None, foto_tipo=None, usuario_id=u["id"])[0]["producto_id"]
    return r
pA = prod("Leche V", "Alquería", "Lácteos y huevos", "Bolsa", 1100, "ml")
pB = prod("Arroz V", "Diana", "Granos y cereales", "Bolsa", 500, "g")
pC = prod("Aceite V", "Gourmet", "Despensa", "Botella", 1000, "ml")
conn.commit()
def pr(pid_, alm, sede, ciudad, precio, dias=0, estado="validado"):
    registrar(producto_id=pid_, almacen=alm, sede=sede, ciudad=ciudad, precio=precio, fecha=tz - datetime.timedelta(days=dias),
              usuario_id=u["id"], estado=estado)
pr(pA, "ÉxitoV", "ÉxitoV Norte", "Bogotá", 5000); pr(pB, "ÉxitoV", "ÉxitoV Norte", "Bogotá", 3600); pr(pC, "ÉxitoV", "ÉxitoV Norte", "Bogotá", 12000)
pr(pA, "D1V", "D1V Sur", "Bogotá", 3900);  pr(pB, "D1V", "D1V Sur", "Bogotá", 3200)                       # D1V no tiene el aceite
pr(pA, "AraV", "AraV Centro", "Bogotá", 4100); pr(pB, "AraV", "AraV Centro", "Bogotá", 3500); pr(pC, "AraV", "AraV Centro", "Bogotá", 11000, dias=45)
pr(pA, "ÉxitoV", "ÉxitoV Sur", "Cali", 1000, dias=20)          # más barato pero MÁS ANTIGUO que el de Bogotá -> no es el vigente del almacén
pr(pA, "ÉxitoV", "ÉxitoV Norte", "Bogotá", 100, estado="pendiente")   # pendiente: debe ignorarse
conn.commit()
vl = lista_nueva(ana, "Valoración")
for pid_, cant in ((pA, 2), (pB, 1), (pC, 1)):
    run("agregar_item_lista", lista_id=vl, usuario_id=ana, producto_id=pid_, cantidad=cant)
conn.commit()

def valorar(lista, ciudad=None):
    filas = run("lista_valoracion", lista_id=lista, ciudad=ciudad)
    mk = {}
    for f_ in filas:
        m = mk.setdefault(f_["almacen"], {"total": Decimal(0), "n": 0, "dias": []})
        if f_["precio_cop"] is not None:
            m["total"] += f_["precio_cop"] * f_["cantidad"]; m["n"] += 1; m["dias"].append(f_["dias"])
    return filas, mk
filas, mk = valorar(vl)
check("hay un renglón por producto y supermercado (3 x 3)", len(filas) == 9 and set(mk) == {"ÉxitoV", "D1V", "AraV"})
check("total ÉxitoV = 2x5000 + 3600 + 12000 = 25600 (ignora el pendiente y el precio más antiguo de Cali)", mk["ÉxitoV"]["total"] == Decimal("25600.00") and mk["ÉxitoV"]["n"] == 3)
check("D1V tiene 2 de 3 productos: total parcial 2x3900 + 3200 = 11000", mk["D1V"]["total"] == Decimal("11000.00") and mk["D1V"]["n"] == 2)
check("total AraV = 2x4100 + 3500 + 11000 = 22700", mk["AraV"]["total"] == Decimal("22700.00") and mk["AraV"]["n"] == 3)
sin = [f_ for f_ in filas if f_["almacen"] == "D1V" and f_["producto_id"] == pC][0]
check("el producto que un supermercado no tiene llega con precio nulo", sin["precio_cop"] is None)
check("se informa la antigüedad del precio (AraV aceite: 45 días)", [f_["dias"] for f_ in filas if f_["almacen"] == "AraV" and f_["producto_id"] == pC] == [45])
completos = {k: v["total"] for k, v in mk.items() if v["n"] == 3}
mas_barato, mas_caro = min(completos.values()), max(completos.values())
ahorro = mas_caro - mas_barato
check("ahorro entre completos: 25600 - 22700 = 2900 (11,3 % del más costoso)", ahorro == Decimal("2900.00") and round(ahorro / mas_caro * 100, 1) == Decimal("11.3"))
f_cali = valorar(vl, "cali")[1]
check("filtrando por ciudad Cali solo cuenta ÉxitoV con su precio de Cali", set(f_cali) == {"ÉxitoV"} and f_cali["ÉxitoV"]["n"] == 1 and f_cali["ÉxitoV"]["total"] == Decimal("2000.00"))
check("lista vacía no genera renglones", run("lista_valoracion", lista_id=fiesta, ciudad=None) == [])
# empate de fecha entre sedes del mismo almacén: gana el menor precio
pr(pA, "AraV", "AraV Norte", "Bogotá", 3000); conn.commit()
check("con la misma fecha en dos sedes del almacén se toma el menor precio", [f_["precio_cop"] for f_ in run("lista_valoracion", lista_id=vl, ciudad=None) if f_["almacen"] == "AraV" and f_["producto_id"] == pA] == [Decimal("3000.00")])
# al validar el precio pendiente cambia el total (solo precios validados cuentan)
with conn.cursor() as cur:
    cur.execute("SELECT id FROM reportes_precio WHERE producto_id=%s AND estado='pendiente'", (pA,))
    rid = cur.fetchone()[0]
run("validar_reporte", reporte_id=rid, usuario_id=mod); conn.commit()
check("al validarse el precio pendiente (100) pasa a ser el vigente de ÉxitoV", [f_["precio_cop"] for f_ in run("lista_valoracion", lista_id=vl, ciudad=None) if f_["almacen"] == "ÉxitoV" and f_["producto_id"] == pA] == [Decimal("100.00")])

# ---------------------------------------------------- migración con datos ---
print("\n13. Eliminar un usuario elimina sus listas")
with conn.cursor() as cur:
    cur.execute("DELETE FROM usuarios WHERE id=%s", (beto,))
    cur.execute("SELECT count(*) FROM listas_mercado WHERE usuario_id=%s", (beto,))
    check("cascada usuario -> listas", cur.fetchone()[0] == 0)
conn.commit()

print(f"\nResultado: {passed} correctas, {failed} fallidas")
sys.exit(1 if failed else 0)
