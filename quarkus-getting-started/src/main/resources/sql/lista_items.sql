SELECT i.producto_id, p.nombre, m.nombre AS marca, p.presentacion, p.cantidad AS cantidad_producto,
       p.unidad, (p.foto IS NOT NULL) AS tiene_foto, i.cantidad
FROM lista_items i
JOIN productos p ON p.id = i.producto_id
JOIN marcas m    ON m.id = p.marca_id
WHERE i.lista_id = CAST(:lista_id AS bigint)
ORDER BY lower(p.nombre), i.producto_id
