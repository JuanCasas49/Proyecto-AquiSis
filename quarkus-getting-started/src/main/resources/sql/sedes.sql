SELECT s.id, s.establecimiento_id, e.nombre AS almacen, s.nombre, s.ciudad, s.direccion
FROM sedes s JOIN establecimientos e ON e.id = s.establecimiento_id
WHERE (CAST(:establecimiento_id AS bigint) IS NULL OR s.establecimiento_id = CAST(:establecimiento_id AS bigint))
  AND (CAST(:ciudad AS text) IS NULL OR lower(s.ciudad) = lower(CAST(:ciudad AS text)))
ORDER BY lower(s.ciudad), lower(s.nombre)
