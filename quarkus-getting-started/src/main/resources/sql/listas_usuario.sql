SELECT l.id, l.nombre, COUNT(i.producto_id) AS n_productos, COALESCE(SUM(i.cantidad), 0) AS n_unidades,
       to_char(l.actualizada_en AT TIME ZONE 'America/Bogota', 'YYYY-MM-DD') AS actualizada
FROM listas_mercado l
LEFT JOIN lista_items i ON i.lista_id = l.id
WHERE l.usuario_id = CAST(:usuario_id AS bigint)
GROUP BY l.id
ORDER BY l.actualizada_en DESC, l.id DESC
