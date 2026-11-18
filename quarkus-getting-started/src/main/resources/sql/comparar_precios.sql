-- Comparador: último precio por sede, de menor a mayor, con diferencias vs. el más económico.
WITH vig AS (
    SELECT v.reporte_id, v.sede_id, v.precio_cop, v.fecha_reporte,
           e.id AS establecimiento_id, e.nombre AS almacen, s.nombre AS sede, s.ciudad, s.direccion,
           (hoy_colombia() - v.fecha_reporte) AS dias
    FROM v_precio_vigente v
    JOIN sedes s            ON s.id = v.sede_id
    JOIN establecimientos e ON e.id = s.establecimiento_id
    WHERE v.producto_id = CAST(:producto_id AS bigint)
      AND (CAST(:ciudad AS text) IS NULL OR lower(s.ciudad) = lower(CAST(:ciudad AS text)))
      AND (CAST(:establecimiento_id AS bigint) IS NULL OR e.id = CAST(:establecimiento_id AS bigint))
), est AS (
    SELECT MIN(precio_cop) AS minimo, MAX(precio_cop) AS maximo, ROUND(AVG(precio_cop), 2) AS promedio
    FROM vig
)
SELECT vig.reporte_id, vig.sede_id, vig.establecimiento_id, vig.almacen, vig.sede, vig.ciudad, vig.direccion,
       vig.precio_cop, to_char(vig.fecha_reporte, 'YYYY-MM-DD') AS fecha, vig.dias,
       (vig.dias > CAST(:dias_vigencia AS integer)) AS desactualizado,
       (vig.precio_cop = est.minimo) AS es_mas_barato,
       (vig.precio_cop - est.minimo) AS diferencia_cop,
       CASE WHEN est.minimo > 0 THEN ROUND((vig.precio_cop - est.minimo) / est.minimo * 100, 1) END AS diferencia_pct,
       est.minimo, est.maximo, est.promedio
FROM vig CROSS JOIN est
ORDER BY vig.precio_cop ASC, vig.fecha_reporte DESC, vig.sede_id
