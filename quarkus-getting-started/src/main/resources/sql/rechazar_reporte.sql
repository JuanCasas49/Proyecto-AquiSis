SELECT rechazar_reporte(CAST(:reporte_id AS bigint), CAST(:usuario_id AS bigint), CAST(:motivo AS text)) AS ok
