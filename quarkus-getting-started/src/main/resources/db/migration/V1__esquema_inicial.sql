-- =============================================================================
-- V1: Esquema inicial - comparador de precios de almacenes de cadena (Colombia)
-- Tablas: usuarios, categorias, marcas, establecimientos, sedes, productos,
--         reportes_precio  (+ vista v_precio_vigente)
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS unaccent;

-- Fecha "de hoy" en Colombia (el servidor/Neon trabaja en UTC)
CREATE FUNCTION hoy_colombia() RETURNS date
LANGUAGE sql STABLE AS
$$ SELECT (now() AT TIME ZONE 'America/Bogota')::date $$;

-- Quita espacios sobrantes; devuelve NULL si queda vacío
CREATE FUNCTION normalizar_texto(t text) RETURNS text
LANGUAGE sql IMMUTABLE AS
$$ SELECT NULLIF(btrim(regexp_replace(coalesce(t, ''), '\s+', ' ', 'g')), '') $$;

-- ---------------------------------------------------------------- usuarios --
CREATE TABLE usuarios (
    id         BIGSERIAL PRIMARY KEY,
    nombre     VARCHAR(80)  NOT NULL CHECK (char_length(btrim(nombre)) >= 2),
    email      VARCHAR(160) NOT NULL CHECK (email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
    creado_en  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uq_usuarios_email ON usuarios (lower(email));

-- -------------------------------------------------------------- categorias --
CREATE TABLE categorias (
    id      BIGSERIAL PRIMARY KEY,
    nombre  VARCHAR(80) NOT NULL CHECK (char_length(btrim(nombre)) > 0)
);
CREATE UNIQUE INDEX uq_categorias_nombre ON categorias (lower(nombre));

-- ------------------------------------------------------------------ marcas --
CREATE TABLE marcas (
    id      BIGSERIAL PRIMARY KEY,
    nombre  VARCHAR(80) NOT NULL CHECK (char_length(btrim(nombre)) > 0)
);
CREATE UNIQUE INDEX uq_marcas_nombre ON marcas (lower(nombre));

-- --------------------------------------------------------- establecimientos --
-- Cadena / almacén: Éxito, D1, Ara, Jumbo...
CREATE TABLE establecimientos (
    id      BIGSERIAL PRIMARY KEY,
    nombre  VARCHAR(80) NOT NULL CHECK (char_length(btrim(nombre)) > 0)
);
CREATE UNIQUE INDEX uq_establecimientos_nombre ON establecimientos (lower(nombre));

-- ------------------------------------------------------------------- sedes --
-- Sucursal concreta de un almacén en una ciudad
CREATE TABLE sedes (
    id                 BIGSERIAL PRIMARY KEY,
    establecimiento_id BIGINT       NOT NULL REFERENCES establecimientos (id) ON DELETE RESTRICT,
    nombre             VARCHAR(120) NOT NULL CHECK (char_length(btrim(nombre)) > 0),
    ciudad             VARCHAR(80)  NOT NULL CHECK (char_length(btrim(ciudad)) > 0),
    direccion          VARCHAR(200)
);
CREATE UNIQUE INDEX uq_sedes_nombre_ciudad ON sedes (establecimiento_id, lower(nombre), lower(ciudad));
CREATE INDEX ix_sedes_ciudad ON sedes (lower(ciudad));

-- ---------------------------------------------------------------- productos --
CREATE TABLE productos (
    id           BIGSERIAL PRIMARY KEY,
    nombre       VARCHAR(160)  NOT NULL CHECK (char_length(btrim(nombre)) > 0),
    descripcion  VARCHAR(1000),
    marca_id     BIGINT        NOT NULL REFERENCES marcas (id)     ON DELETE RESTRICT,
    categoria_id BIGINT        NOT NULL REFERENCES categorias (id) ON DELETE RESTRICT,
    presentacion VARCHAR(60)   NOT NULL CHECK (char_length(btrim(presentacion)) > 0),   -- botella, bolsa, caja...
    cantidad     NUMERIC(10,3) NOT NULL CHECK (cantidad > 0),
    unidad       VARCHAR(5)    NOT NULL CHECK (unidad IN ('g', 'kg', 'ml', 'l', 'un')),
    foto         BYTEA         CHECK (foto IS NULL OR octet_length(foto) <= 1048576),   -- <= 1 MB
    foto_tipo    VARCHAR(30)   CHECK (foto_tipo IS NULL OR foto_tipo IN ('image/jpeg', 'image/png', 'image/webp')),
    creado_por   BIGINT        REFERENCES usuarios (id) ON DELETE SET NULL,
    creado_en    TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CHECK ((foto IS NULL) = (foto_tipo IS NULL))
);
-- Un mismo producto físico (nombre + marca + presentación + cantidad) existe una sola vez
CREATE UNIQUE INDEX uq_productos_identidad
    ON productos (lower(nombre), marca_id, lower(presentacion), cantidad, unidad);
CREATE INDEX ix_productos_marca     ON productos (marca_id);
CREATE INDEX ix_productos_categoria ON productos (categoria_id);

-- --------------------------------------------------------- reportes_precio --
-- Cada fila es un reporte; nunca se sobrescribe (así se conserva el historial)
CREATE TABLE reportes_precio (
    id            BIGSERIAL PRIMARY KEY,
    producto_id   BIGINT        NOT NULL REFERENCES productos (id) ON DELETE CASCADE,
    sede_id       BIGINT        NOT NULL REFERENCES sedes (id)     ON DELETE RESTRICT,
    usuario_id    BIGINT        REFERENCES usuarios (id)           ON DELETE SET NULL,
    precio_cop    NUMERIC(12,2) NOT NULL CHECK (precio_cop > 0 AND precio_cop <= 100000000),
    fecha_reporte DATE          NOT NULL DEFAULT hoy_colombia(),
    creado_en     TIMESTAMPTZ   NOT NULL DEFAULT now()
);
-- Soporta "último precio por sede" (DISTINCT ON) y el historial
CREATE INDEX ix_reportes_producto_sede_fecha
    ON reportes_precio (producto_id, sede_id, fecha_reporte DESC, id DESC);
CREATE INDEX ix_reportes_sede    ON reportes_precio (sede_id);
CREATE INDEX ix_reportes_usuario ON reportes_precio (usuario_id);

-- Precio más reciente reportado por cada (producto, sede)
CREATE VIEW v_precio_vigente AS
SELECT DISTINCT ON (r.producto_id, r.sede_id)
       r.id AS reporte_id, r.producto_id, r.sede_id, r.usuario_id,
       r.precio_cop, r.fecha_reporte
FROM reportes_precio r
ORDER BY r.producto_id, r.sede_id, r.fecha_reporte DESC, r.id DESC;
