-- Verifica además que la lista pertenezca al usuario (si no, no se devuelve nada -> 404)
SELECT l.id, l.nombre FROM listas_mercado l
WHERE l.id = CAST(:lista_id AS bigint) AND l.usuario_id = CAST(:usuario_id AS bigint)
