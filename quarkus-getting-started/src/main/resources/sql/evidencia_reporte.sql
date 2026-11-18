SELECT evidencia, evidencia_tipo FROM reportes_precio
WHERE id = CAST(:reporte_id AS bigint) AND evidencia IS NOT NULL
