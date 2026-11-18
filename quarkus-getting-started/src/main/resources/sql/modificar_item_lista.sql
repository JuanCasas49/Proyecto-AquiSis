SELECT modificar_item_lista(CAST(:lista_id AS bigint), CAST(:usuario_id AS bigint),
                            CAST(:producto_id AS bigint), CAST(:cantidad AS integer)) AS cantidad
