-- Todos los reportes de un producto (validados, pendientes y rechazados). La variación de precio
-- se calcula solo entre reportes VALIDADOS de la misma sede.
WITH base AS (
    SELECT r.id AS reporte_id, r.sede_id, e.nombre AS almacen, s.nombre AS sede, s.ciudad,
           r.precio_cop, r.fecha_reporte AS f, r.estado, (r.evidencia IS NOT NULL) AS tiene_evidencia,
           r.motivo_rechazo, COALESCE(u.nombre, 'Anónimo') AS usuario
    FROM reportes_precio r
    JOIN sedes s            ON s.id = r.sede_id
    JOIN establecimientos e ON e.id = s.establecimiento_id
    LEFT JOIN usuarios u    ON u.id = r.usuario_id
    WHERE r.producto_id = CAST(:producto_id AS bigint)
), variaciones AS (
    SELECT r.id AS reporte_id,
           r.precio_cop - LAG(r.precio_cop) OVER (PARTITION BY r.sede_id ORDER BY r.fecha_reporte, r.id) AS variacion_cop
    FROM reportes_precio r
    WHERE r.producto_id = CAST(:producto_id AS bigint) AND r.estado = 'validado'
)
SELECT b.reporte_id, b.sede_id, b.almacen, b.sede, b.ciudad, b.precio_cop,
       to_char(b.f, 'YYYY-MM-DD') AS fecha,
       (hoy_colombia() - b.f) AS dias,
       ((hoy_colombia() - b.f) > CAST(:dias_vigencia AS integer)) AS desactualizado,
       b.usuario, v.variacion_cop, b.estado, b.tiene_evidencia, b.motivo_rechazo
FROM base b
LEFT JOIN variaciones v ON v.reporte_id = b.reporte_id
WHERE (CAST(:sede_id AS bigint) IS NULL OR b.sede_id = CAST(:sede_id AS bigint))
ORDER BY b.f DESC, b.reporte_id DESC
LIMIT CAST(:limite AS integer)
