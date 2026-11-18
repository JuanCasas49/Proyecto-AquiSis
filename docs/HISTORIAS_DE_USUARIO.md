# Historias de usuario implementadas

> Los mockups de las historias no venían adjuntos; la interfaz sigue el diseño existente de la app (Material 3, verde).
> "Supermercado" = almacén de cadena (Éxito, D1, Ara...).

## HU-06 — Gestión de listas de mercado (RF-05)
**Criterios:** crear múltiples listas con nombre propio · modificar la cantidad de cada producto · agregar y eliminar productos.

| Qué hace | Dónde |
|---|---|
| Pestaña **Listas**: crear (varias, nombre propio y único por usuario), renombrar y eliminar | `listas_screen.dart` |
| Abrir una lista: agregar productos desde el catálogo, **cambiar la cantidad (− / +)**, quitar productos | `lista_detalle_screen.dart`, `selector_producto_screen.dart` |
| Si el producto ya estaba, al agregarlo se suma la cantidad (máx. 999) | función SQL `agregar_item_lista` |
| Límites: 50 listas por usuario, 100 productos por lista, cantidad 1–999 | migración V4 |
| Cada lista es de su dueño: una lista ajena responde 404 | `ListaService` (`usuarioId`) |

API: `GET/POST /api/listas` · `GET/PUT/DELETE /api/listas/{id}` · `POST /api/listas/{id}/items` ·
`PUT/DELETE /api/listas/{id}/items/{productoId}` (el dueño se indica con `usuarioId`).

## HU-07 — Cálculo de valor y ahorro de la lista (RF-06)
**Criterios:** total sumando el precio vigente de cada producto por supermercado · ahorro en pesos y % frente al más costoso.

| Regla | Detalle |
|---|---|
| Total por supermercado | Σ (precio vigente × cantidad). Precio vigente = el reporte **validado** más reciente del producto en ese supermercado (en la ciudad elegida, si se filtra; con empate de fecha, el menor) |
| Ahorro | `más costoso − más económico` en pesos y `(ahorro / más costoso) × 100` en %, comparando solo supermercados que tienen **todos** los productos |
| Supermercado incompleto | Se muestra con total **parcial** y los productos que le faltan; no entra al cálculo del ahorro |
| Sin ahorro calculable | Con menos de 2 supermercados completos se explica en pantalla |
| Antigüedad | Aviso si algún precio usado tiene más de 30 días |

UI: pestaña **Valor y ahorro** dentro de la lista (filtro de ciudad opcional, detalle por producto al expandir cada supermercado).
API: `GET /api/listas/{id}/valoracion?usuarioId=&ciudad=`.

## HU-08 — Registro colaborativo de precios (RF-07)
**Criterios:** adjuntar una imagen como evidencia (opcional, recomendada) · el precio queda **pendiente** hasta ser validado.

| Qué hace | Dónde |
|---|---|
| Foto de evidencia (cámara o galería, máx. 1 MB) al registrar un producto y al reportar un precio; aviso "recomendada" | `evidencia_picker.dart` |
| Todo precio nuevo nace `pendiente`; solo los **validados** cuentan en catálogo, comparador y listas | vista `v_precio_vigente` |
| El catálogo y el detalle muestran "pendiente de validación"; el historial conserva pendientes y rechazados | |
| **Mis reportes** (Perfil): estado de cada precio enviado, motivo de rechazo y evidencia | `mis_reportes_screen.dart` |
| **Validar precios** (solo moderadores): ver la evidencia y validar o rechazar (con motivo) | `validacion_screen.dart` |

API: `POST /api/productos` y `POST /api/productos/{id}/precios` (campo opcional `evidenciaBase64`; la respuesta incluye `estado`) ·
`GET /api/precios/{id}/evidencia` · `GET /api/usuarios/{id}/reportes?estado=` · `GET /api/precios/pendientes?usuarioId=` ·
`POST /api/precios/{id}/validar` · `POST /api/precios/{id}/rechazar`.

### Moderadores
No hay panel de administración: un usuario pasa a moderador desde el **SQL Editor de Neon** (la app sincroniza el rol al abrir Perfil):
```sql
UPDATE usuarios SET rol = 'moderador' WHERE lower(email) = lower('su-correo@ejemplo.com');
```

### Desactivar la validación (modo demostración)
Con `app.precios.validacion-requerida=false` (o la variable de entorno `APP_PRECIOS_VALIDACION_REQUERIDA=false`) los precios nuevos
quedan validados al instante, como antes de HU-08. Por defecto está en `true`.

## Limitaciones
- Sin autenticación real: `usuarioId` lo envía el cliente (igual que antes). Un cliente malicioso podría suplantar a otro usuario o a un
  moderador; para producción hace falta JWT/OIDC.
- Los reportes existentes antes de HU-08 se migraron como `validado`.
- La validación es manual por moderadores; no hay validación comunitaria (por votos) ni notificaciones.
