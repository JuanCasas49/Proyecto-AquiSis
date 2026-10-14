SELECT registrar_precio(
    CAST(:producto_id AS bigint), CAST(:almacen AS text), CAST(:sede AS text), CAST(:ciudad AS text),
    CAST(:direccion AS text), CAST(:precio AS numeric), CAST(:fecha AS date), CAST(:usuario_id AS bigint)) AS reporte_id
