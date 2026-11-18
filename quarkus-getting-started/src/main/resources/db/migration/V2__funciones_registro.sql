-- =============================================================================
-- V2: Funciones de registro (atómicas y seguras ante concurrencia)
--  * obtener_o_crear_producto: reutiliza categoría/marca/producto si ya existen
--  * registrar_precio:         reutiliza almacén/sede y agrega un reporte de precio
-- Los errores de validación usan SQLSTATE 22023 (mensaje en español, apto para el usuario)
-- y P0002 cuando algo no existe.
-- =============================================================================

CREATE FUNCTION obtener_o_crear_producto(
    p_nombre       text,
    p_descripcion  text,
    p_marca        text,
    p_categoria    text,
    p_presentacion text,
    p_cantidad     numeric,
    p_unidad       text,
    p_foto         bytea,
    p_foto_tipo    text,
    p_usuario_id   bigint
) RETURNS TABLE (producto_id bigint, nuevo boolean)
LANGUAGE plpgsql AS
$$
#variable_conflict use_column
DECLARE
    v_nombre       text := normalizar_texto(p_nombre);
    v_descripcion  text := normalizar_texto(p_descripcion);
    v_marca        text := normalizar_texto(p_marca);
    v_categoria    text := normalizar_texto(p_categoria);
    v_presentacion text := normalizar_texto(p_presentacion);
    v_unidad       text := lower(normalizar_texto(p_unidad));
    v_marca_id     bigint;
    v_categoria_id bigint;
    v_id           bigint;
BEGIN
    IF v_nombre IS NULL       THEN RAISE EXCEPTION 'El nombre del producto es obligatorio'  USING ERRCODE = '22023'; END IF;
    IF v_marca IS NULL        THEN RAISE EXCEPTION 'La marca es obligatoria'                USING ERRCODE = '22023'; END IF;
    IF v_categoria IS NULL    THEN RAISE EXCEPTION 'La categoría es obligatoria'            USING ERRCODE = '22023'; END IF;
    IF v_presentacion IS NULL THEN RAISE EXCEPTION 'La presentación es obligatoria'         USING ERRCODE = '22023'; END IF;
    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RAISE EXCEPTION 'La cantidad debe ser mayor que cero' USING ERRCODE = '22023';
    END IF;
    IF v_unidad IS NULL OR v_unidad NOT IN ('g', 'kg', 'ml', 'l', 'un') THEN
        RAISE EXCEPTION 'La unidad debe ser una de: g, kg, ml, l, un' USING ERRCODE = '22023';
    END IF;
    IF char_length(v_nombre) > 160 OR char_length(v_marca) > 80 OR char_length(v_categoria) > 80
       OR char_length(v_presentacion) > 60 OR char_length(coalesce(v_descripcion, '')) > 1000 THEN
        RAISE EXCEPTION 'Alguno de los textos supera la longitud permitida' USING ERRCODE = '22023';
    END IF;
    IF p_foto IS NOT NULL AND (p_foto_tipo IS NULL OR octet_length(p_foto) > 1048576) THEN
        RAISE EXCEPTION 'La fotografía no es válida (máximo 1 MB)' USING ERRCODE = '22023';
    END IF;

    INSERT INTO marcas (nombre) VALUES (v_marca)
    ON CONFLICT ((lower(nombre))) DO UPDATE SET nombre = marcas.nombre
    RETURNING id INTO v_marca_id;

    INSERT INTO categorias (nombre) VALUES (v_categoria)
    ON CONFLICT ((lower(nombre))) DO UPDATE SET nombre = categorias.nombre
    RETURNING id INTO v_categoria_id;

    SELECT p.id INTO v_id FROM productos p
    WHERE lower(p.nombre) = lower(v_nombre) AND p.marca_id = v_marca_id
      AND lower(p.presentacion) = lower(v_presentacion)
      AND p.cantidad = p_cantidad AND p.unidad = v_unidad;

    IF v_id IS NOT NULL THEN
        -- El producto ya existía: solo completamos datos faltantes (foto / descripción)
        UPDATE productos p
           SET foto        = COALESCE(p.foto, p_foto),
               foto_tipo   = COALESCE(p.foto_tipo, CASE WHEN p.foto IS NULL THEN p_foto_tipo END),
               descripcion = COALESCE(p.descripcion, v_descripcion)
         WHERE p.id = v_id
           AND ((p.foto IS NULL AND p_foto IS NOT NULL) OR (p.descripcion IS NULL AND v_descripcion IS NOT NULL));
        RETURN QUERY SELECT v_id, false;
        RETURN;
    END IF;

    INSERT INTO productos (nombre, descripcion, marca_id, categoria_id, presentacion,
                           cantidad, unidad, foto, foto_tipo, creado_por)
    VALUES (v_nombre, v_descripcion, v_marca_id, v_categoria_id, v_presentacion,
            p_cantidad, v_unidad, p_foto, p_foto_tipo, p_usuario_id)
    ON CONFLICT ((lower(nombre)), marca_id, (lower(presentacion)), cantidad, unidad) DO NOTHING
    RETURNING id INTO v_id;

    IF v_id IS NULL THEN
        -- Otro usuario lo creó en el mismo instante
        SELECT p.id INTO v_id FROM productos p
        WHERE lower(p.nombre) = lower(v_nombre) AND p.marca_id = v_marca_id
          AND lower(p.presentacion) = lower(v_presentacion)
          AND p.cantidad = p_cantidad AND p.unidad = v_unidad;
        RETURN QUERY SELECT v_id, false;
    ELSE
        RETURN QUERY SELECT v_id, true;
    END IF;
END;
$$;

CREATE FUNCTION registrar_precio(
    p_producto_id bigint,
    p_almacen     text,
    p_sede        text,
    p_ciudad      text,
    p_direccion   text,
    p_precio      numeric,
    p_fecha       date,
    p_usuario_id  bigint
) RETURNS bigint
LANGUAGE plpgsql AS
$$
#variable_conflict use_column
DECLARE
    v_almacen    text := normalizar_texto(p_almacen);
    v_sede       text := normalizar_texto(p_sede);
    v_ciudad     text := normalizar_texto(p_ciudad);
    v_direccion  text := normalizar_texto(p_direccion);
    v_fecha      date := COALESCE(p_fecha, hoy_colombia());
    v_est_id     bigint;
    v_sede_id    bigint;
    v_reporte_id bigint;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM productos WHERE id = p_producto_id) THEN
        RAISE EXCEPTION 'El producto % no existe', p_producto_id USING ERRCODE = 'P0002';
    END IF;
    IF v_almacen IS NULL THEN RAISE EXCEPTION 'El almacén es obligatorio' USING ERRCODE = '22023'; END IF;
    IF v_sede IS NULL    THEN RAISE EXCEPTION 'La sede es obligatoria'    USING ERRCODE = '22023'; END IF;
    IF v_ciudad IS NULL  THEN RAISE EXCEPTION 'La ciudad es obligatoria'  USING ERRCODE = '22023'; END IF;
    IF char_length(v_almacen) > 80 OR char_length(v_sede) > 120 OR char_length(v_ciudad) > 80
       OR char_length(coalesce(v_direccion, '')) > 200 THEN
        RAISE EXCEPTION 'Alguno de los textos supera la longitud permitida' USING ERRCODE = '22023';
    END IF;
    IF p_precio IS NULL OR p_precio <= 0 OR p_precio > 100000000 THEN
        RAISE EXCEPTION 'El precio debe estar entre $1 y $100.000.000 COP' USING ERRCODE = '22023';
    END IF;
    IF v_fecha > hoy_colombia() THEN
        RAISE EXCEPTION 'La fecha del reporte no puede ser futura' USING ERRCODE = '22023';
    END IF;
    IF v_fecha < hoy_colombia() - 730 THEN
        RAISE EXCEPTION 'La fecha del reporte no puede tener más de 2 años' USING ERRCODE = '22023';
    END IF;

    INSERT INTO establecimientos (nombre) VALUES (v_almacen)
    ON CONFLICT ((lower(nombre))) DO UPDATE SET nombre = establecimientos.nombre
    RETURNING id INTO v_est_id;

    INSERT INTO sedes (establecimiento_id, nombre, ciudad, direccion)
    VALUES (v_est_id, v_sede, v_ciudad, v_direccion)
    ON CONFLICT (establecimiento_id, (lower(nombre)), (lower(ciudad)))
    DO UPDATE SET direccion = COALESCE(sedes.direccion, EXCLUDED.direccion)
    RETURNING id INTO v_sede_id;

    INSERT INTO reportes_precio (producto_id, sede_id, usuario_id, precio_cop, fecha_reporte)
    VALUES (p_producto_id, v_sede_id, p_usuario_id, round(p_precio, 2), v_fecha)
    RETURNING id INTO v_reporte_id;

    RETURN v_reporte_id;
END;
$$;
