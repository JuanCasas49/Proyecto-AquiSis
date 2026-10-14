SELECT p.id, p.nombre, p.descripcion, m.nombre AS marca, c.nombre AS categoria,
       p.marca_id, p.categoria_id, p.presentacion, p.cantidad, p.unidad,
       (p.foto IS NOT NULL) AS tiene_foto, u.nombre AS creado_por,
       to_char(p.creado_en AT TIME ZONE 'America/Bogota', 'YYYY-MM-DD') AS creado_en
FROM productos p
JOIN marcas m     ON m.id = p.marca_id
JOIN categorias c ON c.id = p.categoria_id
LEFT JOIN usuarios u ON u.id = p.creado_por
WHERE p.id = CAST(:producto_id AS bigint)
