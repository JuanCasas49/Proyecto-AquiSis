-- Catálogo con búsqueda y filtros combinables.
-- Los filtros de almacén, ciudad y precio se evalúan sobre el precio VIGENTE
-- (último reporte) de cada sede; el producto aparece si alguna sede cumple todo.
WITH vig AS (
    SELECT v.producto_id, v.precio_cop, v.fecha_reporte,
           e.nombre AS almacen, s.nombre AS sede, s.ciudad
    FROM v_precio_vigente v
    JOIN sedes s            ON s.id = v.sede_id
    JOIN establecimientos e ON e.id = s.establecimiento_id
    WHERE (CAST(:establecimiento_id AS bigint) IS NULL OR e.id = CAST(:establecimiento_id AS bigint))
      AND (CAST(:ciudad AS text) IS NULL OR lower(s.ciudad) = lower(CAST(:ciudad AS text)))
      AND (CAST(:precio_min AS numeric) IS NULL OR v.precio_cop >= CAST(:precio_min AS numeric))
      AND (CAST(:precio_max AS numeric) IS NULL OR v.precio_cop <= CAST(:precio_max AS numeric))
), resumen AS (
    SELECT producto_id,
           MIN(precio_cop)     AS precio_min,
           MAX(precio_cop)     AS precio_max,
           COUNT(*)            AS n_sedes,
           MAX(fecha_reporte)  AS ultima_fecha,
           (ARRAY_AGG(almacen ORDER BY precio_cop, fecha_reporte DESC))[1] AS mejor_almacen,
           (ARRAY_AGG(sede    ORDER BY precio_cop, fecha_reporte DESC))[1] AS mejor_sede,
           (ARRAY_AGG(ciudad  ORDER BY precio_cop, fecha_reporte DESC))[1] AS mejor_ciudad
    FROM vig
    GROUP BY producto_id
)
SELECT p.id, p.nombre, m.nombre AS marca, c.nombre AS categoria,
       p.presentacion, p.cantidad, p.unidad, (p.foto IS NOT NULL) AS tiene_foto,
       r.precio_min, r.precio_max, COALESCE(r.n_sedes, 0) AS n_sedes, r.ultima_fecha,
       (hoy_colombia() - r.ultima_fecha) AS dias_ultima,
       r.mejor_almacen, r.mejor_sede, r.mejor_ciudad,
       COUNT(*) OVER () AS total
FROM productos p
JOIN marcas m     ON m.id = p.marca_id
JOIN categorias c ON c.id = p.categoria_id
LEFT JOIN resumen r ON r.producto_id = p.id
WHERE (CAST(:q AS text) IS NULL
        OR strpos(lower(unaccent(p.nombre)), lower(unaccent(CAST(:q AS text)))) > 0
        OR strpos(lower(unaccent(m.nombre)), lower(unaccent(CAST(:q AS text)))) > 0)
  AND (CAST(:categoria_id AS bigint) IS NULL OR p.categoria_id = CAST(:categoria_id AS bigint))
  AND (CAST(:marca_id AS bigint) IS NULL OR p.marca_id = CAST(:marca_id AS bigint))
  AND (r.producto_id IS NOT NULL
        OR (CAST(:establecimiento_id AS bigint) IS NULL AND CAST(:ciudad AS text) IS NULL
            AND CAST(:precio_min AS numeric) IS NULL AND CAST(:precio_max AS numeric) IS NULL))
ORDER BY
    CASE WHEN CAST(:orden AS text) = 'precio_asc'  THEN r.precio_min END ASC  NULLS LAST,
    CASE WHEN CAST(:orden AS text) = 'precio_desc' THEN r.precio_min END DESC NULLS LAST,
    CASE WHEN CAST(:orden AS text) = 'reciente'    THEN r.ultima_fecha END DESC NULLS LAST,
    lower(p.nombre), p.id
LIMIT CAST(:limite AS integer) OFFSET CAST(:desplazamiento AS integer)
