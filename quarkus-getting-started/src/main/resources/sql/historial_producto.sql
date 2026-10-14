-- Todos los reportes de un producto, con variación frente al reporte anterior de la misma sede.
SELECT x.* FROM (
    SELECT r.id AS reporte_id, r.sede_id, e.nombre AS almacen, s.nombre AS sede, s.ciudad,
           r.precio_cop, to_char(r.fecha_reporte, 'YYYY-MM-DD') AS fecha,
           (hoy_colombia() - r.fecha_reporte) AS dias,
           ((hoy_colombia() - r.fecha_reporte) > CAST(:dias_vigencia AS integer)) AS desactualizado,
           COALESCE(u.nombre, 'Anónimo') AS usuario,
           r.precio_cop - LAG(r.precio_cop) OVER (PARTITION BY r.sede_id ORDER BY r.fecha_reporte, r.id) AS variacion_cop,
           r.fecha_reporte AS f, r.id AS rid
    FROM reportes_precio r
    JOIN sedes s            ON s.id = r.sede_id
    JOIN establecimientos e ON e.id = s.establecimiento_id
    LEFT JOIN usuarios u    ON u.id = r.usuario_id
    WHERE r.producto_id = CAST(:producto_id AS bigint)
) x
WHERE (CAST(:sede_id AS bigint) IS NULL OR x.sede_id = CAST(:sede_id AS bigint))
ORDER BY x.f DESC, x.rid DESC
LIMIT CAST(:limite AS integer)
