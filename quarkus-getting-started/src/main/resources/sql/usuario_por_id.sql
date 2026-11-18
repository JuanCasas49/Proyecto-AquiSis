SELECT id, nombre, email, rol FROM usuarios WHERE id = CAST(:usuario_id AS bigint)
