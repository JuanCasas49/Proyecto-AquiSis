SELECT producto_id, nuevo FROM obtener_o_crear_producto(
    CAST(:nombre AS text), CAST(:descripcion AS text), CAST(:marca AS text), CAST(:categoria AS text),
    CAST(:presentacion AS text), CAST(:cantidad AS numeric), CAST(:unidad AS text),
    CAST(:foto AS bytea), CAST(:foto_tipo AS text), CAST(:usuario_id AS bigint))
