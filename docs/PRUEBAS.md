# Pruebas del proyecto

Todas las pruebas son **archivos nuevos**: no modifican el código de la aplicación ni el proceso actual.

## Qué cubre cada prueba

| Funcionalidad | Backend (Quarkus) | App (Flutter) | SQL / Neon |
|---|---|---|---|
| Registro de productos y precios (fotos, duplicados, validaciones) | `RegistroApiTest`, `ProductoResourceTest` | `registro_screen_test`, `api_service_test`, `home_shell_test` | `verify_sql.py` §2–3 |
| Catálogo, búsqueda y filtros combinables | `CatalogoBusquedaApiTest` | `catalogo_screen_test` | `verify_sql.py` §4 |
| Detalle del producto | `CatalogoBusquedaApiTest` (detalle) | `detalle_screen_test` | `verify_sql.py` §7 |
| Comparador: más barato, diferencias, ahorros | `ComparadorHistorialApiTest`, `ResumenComparacionTest` (unitaria) | `detalle_screen_test` | `verify_sql.py` §5 |
| Historial y advertencia de precios desactualizados | `ComparadorHistorialApiTest` | `detalle_screen_test` | `verify_sql.py` §5–6 |
| Usuarios (nombre + correo) | `UsuarioApiTest` | `perfil_screen_test`, `sesion_test` | `verify_sql.py` §1 |
| Listas de apoyo y conexión con Neon | `CatalogosApiTest` | `perfil_screen_test` (estado de conexión) | `verify_sql.py` §7–8 |
| Persistencia entre conexiones/dispositivos | `RegistroApiTest` + lecturas posteriores | — | `verify_sql.py` §8 |
| Consultas `.sql` y sus parámetros | `NamedSqlTest` (unitaria) | — | `verify_sql.py` |

## Cómo ejecutarlas

### 1. App Flutter (no necesita servidor ni internet: simula la API)
```powershell
cd flutter_client
flutter pub get
flutter test                      # todas
flutter test test/detalle_screen_test.dart   # una sola
```

### 2. Backend Quarkus
Las pruebas unitarias (`ResumenComparacionTest`, `NamedSqlTest`) no usan base de datos. Las `*ApiTest` y `ProductoResourceTest`
necesitan PostgreSQL y **crean datos de prueba** (nombres con un sufijo aleatorio, sin tocar datos existentes):

- **Con Docker Desktop encendido:** `./mvnw test` (Quarkus levanta una base PostgreSQL desechable automáticamente).
- **Sin Docker:** usa una **rama de Neon solo para pruebas** (Neon Console → Branches → Create branch), no la rama principal:
  ```powershell
  ./mvnw test "-Dquarkus.datasource.jdbc.url=jdbc:postgresql://HOST-DE-LA-RAMA/neondb?sslmode=require" `
              "-Dquarkus.datasource.username=USUARIO" "-Dquarkus.datasource.password=CLAVE"
  ```
- **Solo las unitarias (sin base de datos):**
  `./mvnw test "-Dtest=ResumenComparacionTest,NamedSqlTest"`

> En `quarkus:dev`, la consola de pruebas continuas ("Tests paused") ejecuta estas mismas pruebas al pulsar `r`:
> en modo dev usan la base configurada para pruebas (Docker o los `-D` anteriores), no la de `.env`.

### 3. Verificación directa del SQL contra PostgreSQL / Neon
```powershell
pip install -r quarkus-getting-started/db-tests/requirements.txt
$env:VERIFY_DSN="postgresql://usuario:clave@host/db?sslmode=require"   # rama de pruebas
python quarkus-getting-started/db-tests/verify_sql.py
```
Aplica las migraciones si la base está vacía y ejecuta 58 comprobaciones con los mismos archivos `.sql` del backend.
`--reset` borra el esquema `public`: úselo solo en bases desechables.

## Resultado de la verificación hecha al entregar

| Conjunto | Estado |
|---|---|
| `verify_sql.py` (58 comprobaciones, PostgreSQL 16) | Ejecutado: 58 correctas, 0 fallidas (dos corridas seguidas) |
| `ResumenComparacionTest` + `NamedSqlTest` (JUnit 5) | Ejecutadas: 11 correctas |
| Escenarios de las `*ApiTest` a nivel de servicio contra PostgreSQL | Ejecutados con un arnés temporal: 60 correctos (confirma los valores esperados) |
| `*ApiTest` (HTTP con RestAssured) | Compilan contra stubs; **no ejecutadas** (requieren Quarkus + Maven) |
| Pruebas Flutter | Estructura revisada; **no ejecutadas** (requieren el SDK de Flutter) |
