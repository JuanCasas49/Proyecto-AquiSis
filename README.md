# Comparador de precios de almacenes de cadena (Colombia)

App móvil Flutter (`flutter_client`) + API REST Quarkus (`quarkus-getting-started`) + base de datos compartida en
**Neon PostgreSQL**. Permite registrar, consultar y comparar precios de productos en Éxito, D1, Ara, Jumbo, etc.

```
Flutter (móvil/web)  ──HTTP/JSON──►  Quarkus (API)  ──JDBC/SSL──►  Neon PostgreSQL
 flutter_client                      quarkus-getting-started        (datos compartidos)
```

> La app **nunca** se conecta directo a Neon: solo el backend conoce las credenciales (variables de entorno).

## 1. Configurar Neon (una sola vez)

1. En <https://console.neon.tech> abra su proyecto → **Connect**. Elija la base (p. ej. `neondb`) y el rol.
2. Con **Connection pooling activado** copie host, usuario y contraseña. Arme la URL JDBC:
   `jdbc:postgresql://<host-con-"-pooler">/<base>?sslmode=require`
3. (Recomendado) Copie también el host **sin** `-pooler` (conexión directa) para las migraciones → `DB_MIGRATION_URL`.
4. En `quarkus-getting-started` copie `.env.example` a `.env` y complete `DB_URL`, `DB_USER`, `DB_PASSWORD`
   (`.env` ya está en `.gitignore`).
5. **Rote la contraseña del rol en Neon** (Console → Roles → Reset password): la versión original de
   `application.properties` tenía credenciales escritas y siguen en el historial de Git si alguna vez se subieron.

Las tablas se crean solas al iniciar el backend (Flyway). Para probar sin tocar los datos reales cree una **rama** de
Neon (Branches → Create branch) y úsela en `.env` mientras desarrolla.

## 2. Ejecutar el backend

Requisitos: JDK 25 (el `pom.xml` usa `maven.compiler.release=25`; ajústelo si usa otra versión).

```bash
cd quarkus-getting-started
./mvnw quarkus:dev          # Windows: mvnw.cmd quarkus:dev
```

Comprobar: <http://localhost:8080/api/salud> → `{"estado":"ok","baseDeDatos":"conectada",...}`.

Pruebas de integración (`./mvnw test`): sin `DB_URL`, Quarkus levanta un PostgreSQL desechable (requiere Docker). Sin Docker:
`./mvnw test -Dquarkus.datasource.jdbc.url=<rama de prueba> -Dquarkus.datasource.username=... -Dquarkus.datasource.password=...`

Verificación independiente del SQL (sin Quarkus): `pip install -r db-tests/requirements.txt` y
`VERIFY_DSN="postgresql://..." python3 db-tests/verify_sql.py` (**use una base desechable**; `--reset` borra el esquema).

## 3. Ejecutar la app

```bash
cd flutter_client
flutter pub get
flutter run                                   # Android Emulator usa http://10.0.2.2:8080 por defecto
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8080   # celular físico: IP de su PC
flutter test
```

Para que **otros usuarios y dispositivos** usen la app sin su computador encendido, despliegue el backend
(hay `src/main/docker/Dockerfile.jvm`) en un host con HTTPS, defina allí `DB_URL`, `DB_USER`, `DB_PASSWORD`, y compile la app con
`--dart-define=API_BASE_URL=https://su-api`. Los datos ya viven en Neon y son compartidos.

## 4. API

| Método | Ruta | Uso |
|---|---|---|
| GET | `/api/productos?q&categoriaId&marcaId&establecimientoId&ciudad&precioMin&precioMax&orden&pagina&tamano` | Catálogo con filtros combinables (`orden`: `nombre`, `precio_asc`, `precio_desc`, `reciente`) |
| POST | `/api/productos` | Registra producto + primer precio (reutiliza el producto si ya existe) |
| GET | `/api/productos/{id}` · `/foto` | Detalle · fotografía |
| GET | `/api/productos/{id}/comparacion?ciudad&establecimientoId&unidades` | Precios por sede de menor a mayor, más económico, diferencias y ahorro |
| GET | `/api/productos/{id}/historial?sedeId&limite` | Reportes anteriores con variación y advertencia de antigüedad |
| POST | `/api/productos/{id}/precios` | Nuevo reporte de precio |
| GET | `/api/categorias` `/marcas` `/establecimientos` `/ciudades` `/sedes` | Listas de apoyo |
| POST | `/api/usuarios` | Identificación por nombre + correo |
| GET | `/api/salud` | Verifica la conexión con Neon |

Errores: `{"error": "mensaje en español"}` con 400/404/409/503. Estructura de la base: `quarkus-getting-started/docs/BASE_DE_DATOS.md`.

## 5. Limitaciones conocidas

- **Sin autenticación real:** el usuario se identifica solo con nombre + correo (sin contraseña) y la API es abierta. Sirve para
  atribuir reportes, no para seguridad. Siguiente paso recomendado: JWT/OIDC y límite de peticiones.
- CORS abierto (`*`) para desarrollo; restrinja el origen en producción.
- Los precios son reportados por usuarios: no hay moderación; un reporte erróneo solo se corrige con uno nuevo.
- Se retiró `quarkus-hibernate-orm-panache` (no había entidades) y `hibernate generation=update`; el esquema ahora lo controla Flyway y
  el acceso es JDBC/SQL (agregaciones `DISTINCT ON`, ventanas) para que cada consulta sea explícita y verificable.
- El endpoint inicial del cliente (`Producto{nombre, precio}`) se reemplazó: `ApiService.obtenerProductos()` se conserva pero devuelve el nuevo modelo.
