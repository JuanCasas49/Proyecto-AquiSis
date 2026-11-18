-- =============================================================================
-- V4: HU-06 listas de mercado, HU-07 valoración (consulta), HU-08 registro
--     colaborativo con evidencia y estado "pendiente" hasta ser validado.
-- Los reportes existentes quedan como "validado" (eran anteriores a esta regla).
-- =============================================================================

-- ------------------------------------------------------ roles de usuario ----
ALTER TABLE usuarios
    ADD COLUMN rol VARCHAR(12) NOT NULL DEFAULT 'usuario' CHECK (rol IN ('usuario', 'moderador'));

-- ------------------------------- estado y evidencia de los reportes (HU-08) --
ALTER TABLE reportes_precio
    ADD COLUMN estado         VARCHAR(10) NOT NULL DEFAULT 'validado'
                              CHECK (estado IN ('pendiente', 'validado', 'rechazado')),
    ADD COLUMN evidencia      BYTEA       CHECK (evidencia IS NULL OR octet_length(evidencia) <= 1048576),
    ADD COLUMN evidencia_tipo VARCHAR(30) CHECK (evidencia_tipo IS NULL OR evidencia_tipo IN ('image/jpeg', 'image/png', 'image/webp')),
    ADD COLUMN validado_por   BIGINT      REFERENCES usuarios (id) ON DELETE SET NULL,
    ADD COLUMN validado_en    TIMESTAMPTZ,
    ADD COLUMN motivo_rechazo VARCHAR(200),
    ADD CONSTRAINT ck_reportes_evidencia_par CHECK ((evidencia IS NULL) = (evidencia_tipo IS NULL));

CREATE INDEX ix_reportes_pendientes ON reportes_precio (creado_en) WHERE estado = 'pendiente';

-- Solo los precios VALIDADOS son oficiales: catálogo, comparador y listas los usan a través de esta vista
CREATE OR REPLACE VIEW v_precio_vigente AS
SELECT DISTINCT ON (r.producto_id, r.sede_id)
       r.id AS reporte_id, r.producto_id, r.sede_id, r.usuario_id,
       r.precio_cop, r.fecha_reporte
FROM reportes_precio r
WHERE r.estado = 'validado'
ORDER BY r.producto_id, r.sede_id, r.fecha_reporte DESC, r.id DESC;

-- registrar_precio ahora recibe el estado inicial y la evidencia (foto) opcional
DROP FUNCTION registrar_precio(bigint, text, text, text, text, numeric, date, bigint);

CREATE FUNCTION registrar_precio(
    p_producto_id    bigint,
    p_almacen        text,
    p_sede           text,
    p_ciudad         text,
    p_direccion      text,
    p_precio         numeric,
    p_fecha          date,
    p_usuario_id     bigint,
    p_estado         text  DEFAULT 'validado',
    p_evidencia      bytea DEFAULT NULL,
    p_evidencia_tipo text  DEFAULT NULL
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
    v_estado     text := lower(COALESCE(normalizar_texto(p_estado), 'validado'));
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
    IF v_estado NOT IN ('pendiente', 'validado') THEN
        RAISE EXCEPTION 'El estado inicial debe ser pendiente o validado' USING ERRCODE = '22023';
    END IF;
    IF p_evidencia IS NOT NULL AND (p_evidencia_tipo IS NULL OR octet_length(p_evidencia) > 1048576) THEN
        RAISE EXCEPTION 'La evidencia no es válida (máximo 1 MB)' USING ERRCODE = '22023';
    END IF;

    INSERT INTO establecimientos (nombre) VALUES (v_almacen)
    ON CONFLICT ((lower(nombre))) DO UPDATE SET nombre = establecimientos.nombre
    RETURNING id INTO v_est_id;

    INSERT INTO sedes (establecimiento_id, nombre, ciudad, direccion)
    VALUES (v_est_id, v_sede, v_ciudad, v_direccion)
    ON CONFLICT (establecimiento_id, (lower(nombre)), (lower(ciudad)))
    DO UPDATE SET direccion = COALESCE(sedes.direccion, EXCLUDED.direccion)
    RETURNING id INTO v_sede_id;

    INSERT INTO reportes_precio (producto_id, sede_id, usuario_id, precio_cop, fecha_reporte,
                                 estado, evidencia, evidencia_tipo, validado_en)
    VALUES (p_producto_id, v_sede_id, p_usuario_id, round(p_precio, 2), v_fecha,
            v_estado, p_evidencia, CASE WHEN p_evidencia IS NULL THEN NULL ELSE p_evidencia_tipo END,
            CASE WHEN v_estado = 'validado' THEN now() END)
    RETURNING id INTO v_reporte_id;

    RETURN v_reporte_id;
END;
$$;

-- Validación / rechazo por un moderador (SQLSTATE P0403 = sin permiso, P0409 = ya procesado)
CREATE FUNCTION validar_reporte(p_reporte_id bigint, p_usuario_id bigint) RETURNS boolean
LANGUAGE plpgsql AS
$$
#variable_conflict use_column
DECLARE
    v_estado text;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM usuarios WHERE id = p_usuario_id AND rol = 'moderador') THEN
        RAISE EXCEPTION 'Solo un moderador puede validar precios' USING ERRCODE = 'P0403';
    END IF;
    SELECT estado INTO v_estado FROM reportes_precio WHERE id = p_reporte_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El reporte no existe' USING ERRCODE = 'P0002';
    END IF;
    IF v_estado <> 'pendiente' THEN
        RAISE EXCEPTION 'El reporte ya fue %', v_estado USING ERRCODE = 'P0409';
    END IF;
    UPDATE reportes_precio
       SET estado = 'validado', validado_por = p_usuario_id, validado_en = now(), motivo_rechazo = NULL
     WHERE id = p_reporte_id;
    RETURN true;
END;
$$;

CREATE FUNCTION rechazar_reporte(p_reporte_id bigint, p_usuario_id bigint, p_motivo text) RETURNS boolean
LANGUAGE plpgsql AS
$$
#variable_conflict use_column
DECLARE
    v_estado text;
    v_motivo text := normalizar_texto(p_motivo);
BEGIN
    IF NOT EXISTS (SELECT 1 FROM usuarios WHERE id = p_usuario_id AND rol = 'moderador') THEN
        RAISE EXCEPTION 'Solo un moderador puede rechazar precios' USING ERRCODE = 'P0403';
    END IF;
    IF char_length(coalesce(v_motivo, '')) > 200 THEN
        RAISE EXCEPTION 'El motivo admite máximo 200 caracteres' USING ERRCODE = '22023';
    END IF;
    SELECT estado INTO v_estado FROM reportes_precio WHERE id = p_reporte_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El reporte no existe' USING ERRCODE = 'P0002';
    END IF;
    IF v_estado <> 'pendiente' THEN
        RAISE EXCEPTION 'El reporte ya fue %', v_estado USING ERRCODE = 'P0409';
    END IF;
    UPDATE reportes_precio
       SET estado = 'rechazado', validado_por = p_usuario_id, validado_en = now(), motivo_rechazo = v_motivo
     WHERE id = p_reporte_id;
    RETURN true;
END;
$$;

-- --------------------------------------------- listas de mercado (HU-06) -----
CREATE TABLE listas_mercado (
    id             BIGSERIAL PRIMARY KEY,
    usuario_id     BIGINT      NOT NULL REFERENCES usuarios (id) ON DELETE CASCADE,
    nombre         VARCHAR(80) NOT NULL CHECK (char_length(btrim(nombre)) > 0),
    creada_en      TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizada_en TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- Cada usuario puede tener varias listas, pero con nombres distintos
CREATE UNIQUE INDEX uq_listas_usuario_nombre ON listas_mercado (usuario_id, lower(nombre));

CREATE TABLE lista_items (
    lista_id    BIGINT      NOT NULL REFERENCES listas_mercado (id) ON DELETE CASCADE,
    producto_id BIGINT      NOT NULL REFERENCES productos (id)      ON DELETE CASCADE,
    cantidad    INTEGER     NOT NULL CHECK (cantidad BETWEEN 1 AND 999),   -- unidades a comprar
    agregado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (lista_id, producto_id)
);
CREATE INDEX ix_lista_items_producto ON lista_items (producto_id);

CREATE FUNCTION crear_lista(p_usuario_id bigint, p_nombre text) RETURNS bigint
LANGUAGE plpgsql AS
$$
#variable_conflict use_column
DECLARE
    v_nombre text := normalizar_texto(p_nombre);
    v_id     bigint;
BEGIN
    IF v_nombre IS NULL THEN
        RAISE EXCEPTION 'El nombre de la lista es obligatorio' USING ERRCODE = '22023';
    END IF;
    IF char_length(v_nombre) > 80 THEN
        RAISE EXCEPTION 'El nombre de la lista admite máximo 80 caracteres' USING ERRCODE = '22023';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM usuarios WHERE id = p_usuario_id) THEN
        RAISE EXCEPTION 'El usuario no existe' USING ERRCODE = 'P0002';
    END IF;
    IF (SELECT count(*) FROM listas_mercado WHERE usuario_id = p_usuario_id) >= 50 THEN
        RAISE EXCEPTION 'Alcanzó el máximo de 50 listas' USING ERRCODE = '22023';
    END IF;
    INSERT INTO listas_mercado (usuario_id, nombre) VALUES (p_usuario_id, v_nombre) RETURNING id INTO v_id;
    RETURN v_id;
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'Ya tiene una lista llamada "%"', v_nombre USING ERRCODE = 'P0409';
END;
$$;

CREATE FUNCTION renombrar_lista(p_lista_id bigint, p_usuario_id bigint, p_nombre text) RETURNS boolean
LANGUAGE plpgsql AS
$$
#variable_conflict use_column
DECLARE
    v_nombre text := normalizar_texto(p_nombre);
BEGIN
    IF v_nombre IS NULL THEN
        RAISE EXCEPTION 'El nombre de la lista es obligatorio' USING ERRCODE = '22023';
    END IF;
    IF char_length(v_nombre) > 80 THEN
        RAISE EXCEPTION 'El nombre de la lista admite máximo 80 caracteres' USING ERRCODE = '22023';
    END IF;
    UPDATE listas_mercado SET nombre = v_nombre, actualizada_en = now()
     WHERE id = p_lista_id AND usuario_id = p_usuario_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La lista no existe' USING ERRCODE = 'P0002';
    END IF;
    RETURN true;
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'Ya tiene una lista llamada "%"', v_nombre USING ERRCODE = 'P0409';
END;
$$;

CREATE FUNCTION eliminar_lista(p_lista_id bigint, p_usuario_id bigint) RETURNS boolean
LANGUAGE plpgsql AS
$$
BEGIN
    DELETE FROM listas_mercado WHERE id = p_lista_id AND usuario_id = p_usuario_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La lista no existe' USING ERRCODE = 'P0002';
    END IF;
    RETURN true;
END;
$$;

-- Agrega un producto; si ya estaba en la lista, suma la cantidad (máx. 999). Devuelve la cantidad resultante.
CREATE FUNCTION agregar_item_lista(p_lista_id bigint, p_usuario_id bigint, p_producto_id bigint, p_cantidad integer)
RETURNS integer
LANGUAGE plpgsql AS
$$
#variable_conflict use_column
DECLARE
    v_lista bigint;
    v_total integer;
BEGIN
    IF p_cantidad IS NULL OR p_cantidad < 1 OR p_cantidad > 999 THEN
        RAISE EXCEPTION 'La cantidad debe estar entre 1 y 999' USING ERRCODE = '22023';
    END IF;
    SELECT id INTO v_lista FROM listas_mercado WHERE id = p_lista_id AND usuario_id = p_usuario_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La lista no existe' USING ERRCODE = 'P0002';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM productos WHERE id = p_producto_id) THEN
        RAISE EXCEPTION 'El producto no existe' USING ERRCODE = 'P0002';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM lista_items WHERE lista_id = p_lista_id AND producto_id = p_producto_id)
       AND (SELECT count(*) FROM lista_items WHERE lista_id = p_lista_id) >= 100 THEN
        RAISE EXCEPTION 'Una lista admite máximo 100 productos' USING ERRCODE = '22023';
    END IF;
    INSERT INTO lista_items (lista_id, producto_id, cantidad) VALUES (p_lista_id, p_producto_id, p_cantidad)
    ON CONFLICT (lista_id, producto_id)
    DO UPDATE SET cantidad = LEAST(999, lista_items.cantidad + EXCLUDED.cantidad)
    RETURNING cantidad INTO v_total;
    UPDATE listas_mercado SET actualizada_en = now() WHERE id = p_lista_id;
    RETURN v_total;
END;
$$;

-- Cambia la cantidad de un producto que ya está en la lista
CREATE FUNCTION modificar_item_lista(p_lista_id bigint, p_usuario_id bigint, p_producto_id bigint, p_cantidad integer)
RETURNS integer
LANGUAGE plpgsql AS
$$
#variable_conflict use_column
DECLARE
    v_lista bigint;
BEGIN
    IF p_cantidad IS NULL OR p_cantidad < 1 OR p_cantidad > 999 THEN
        RAISE EXCEPTION 'La cantidad debe estar entre 1 y 999' USING ERRCODE = '22023';
    END IF;
    SELECT id INTO v_lista FROM listas_mercado WHERE id = p_lista_id AND usuario_id = p_usuario_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La lista no existe' USING ERRCODE = 'P0002';
    END IF;
    UPDATE lista_items SET cantidad = p_cantidad WHERE lista_id = p_lista_id AND producto_id = p_producto_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El producto no está en la lista' USING ERRCODE = 'P0002';
    END IF;
    UPDATE listas_mercado SET actualizada_en = now() WHERE id = p_lista_id;
    RETURN p_cantidad;
END;
$$;

CREATE FUNCTION quitar_item_lista(p_lista_id bigint, p_usuario_id bigint, p_producto_id bigint) RETURNS boolean
LANGUAGE plpgsql AS
$$
#variable_conflict use_column
DECLARE
    v_lista bigint;
BEGIN
    SELECT id INTO v_lista FROM listas_mercado WHERE id = p_lista_id AND usuario_id = p_usuario_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La lista no existe' USING ERRCODE = 'P0002';
    END IF;
    DELETE FROM lista_items WHERE lista_id = p_lista_id AND producto_id = p_producto_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El producto no está en la lista' USING ERRCODE = 'P0002';
    END IF;
    UPDATE listas_mercado SET actualizada_en = now() WHERE id = p_lista_id;
    RETURN true;
END;
$$;
