-- Cola de moderación: reportes pendientes de todos los usuarios, los más antiguos primero
SELECT r.id AS reporte_id, p.id AS producto_id, p.nombre AS producto, e.nombre AS almacen, s.nombre AS sede, s.ciudad,
       r.precio_cop, to_char(r.fecha_reporte, 'YYYY-MM-DD') AS fecha, r.estado,
       (r.evidencia IS NOT NULL) AS tiene_evidencia, r.motivo_rechazo, COALESCE(u.nombre, 'Anónimo') AS usuario
FROM reportes_precio r
JOIN productos p        ON p.id = r.producto_id
JOIN sedes s            ON s.id = r.sede_id
JOIN establecimientos e ON e.id = s.establecimiento_id
LEFT JOIN usuarios u    ON u.id = r.usuario_id
WHERE r.estado = 'pendiente'
ORDER BY r.creado_en ASC, r.id ASC
LIMIT CAST(:limite AS integer)
