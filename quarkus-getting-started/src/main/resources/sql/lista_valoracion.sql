-- HU-07: precio vigente (VALIDADO) de cada producto de la lista en cada supermercado (almacén).
-- Por supermercado se toma el reporte más reciente en cualquiera de sus sedes (opcionalmente de una ciudad);
-- si hay empate de fecha, el menor precio. Si el supermercado no tiene el producto, precio_cop es NULL.
WITH mercados AS (
    SELECT DISTINCT e.id, e.nombre
    FROM v_precio_vigente v
    JOIN sedes s            ON s.id = v.sede_id
    JOIN establecimientos e ON e.id = s.establecimiento_id
    WHERE v.producto_id IN (SELECT producto_id FROM lista_items WHERE lista_id = CAST(:lista_id AS bigint))
      AND (CAST(:ciudad AS text) IS NULL OR lower(s.ciudad) = lower(CAST(:ciudad AS text)))
)
SELECT it.producto_id, it.cantidad, mk.id AS establecimiento_id, mk.nombre AS almacen,
       pr.precio_cop, pr.sede, pr.ciudad,
       to_char(pr.fecha_reporte, 'YYYY-MM-DD') AS fecha,
       (hoy_colombia() - pr.fecha_reporte) AS dias
FROM lista_items it
CROSS JOIN mercados mk
LEFT JOIN LATERAL (
    SELECT v.precio_cop, v.fecha_reporte, s.nombre AS sede, s.ciudad
    FROM v_precio_vigente v
    JOIN sedes s ON s.id = v.sede_id
    WHERE v.producto_id = it.producto_id
      AND s.establecimiento_id = mk.id
      AND (CAST(:ciudad AS text) IS NULL OR lower(s.ciudad) = lower(CAST(:ciudad AS text)))
    ORDER BY v.fecha_reporte DESC, v.precio_cop ASC, v.reporte_id DESC
    LIMIT 1
) pr ON TRUE
WHERE it.lista_id = CAST(:lista_id AS bigint)
ORDER BY mk.nombre, it.producto_id
