SELECT foto, foto_tipo FROM productos WHERE id = CAST(:producto_id AS bigint) AND foto IS NOT NULL
