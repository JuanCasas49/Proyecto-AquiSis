-- =============================================================================
-- V3: Datos base (solo catálogos; NO se insertan productos ni precios de ejemplo
-- para no contaminar la base compartida). Idempotente.
-- =============================================================================
INSERT INTO categorias (nombre) VALUES
    ('Lácteos y huevos'), ('Carnes y pescados'), ('Frutas y verduras'), ('Despensa'),
    ('Granos y cereales'), ('Bebidas'), ('Panadería y repostería'), ('Snacks y dulces'),
    ('Congelados'), ('Aseo del hogar'), ('Cuidado personal'), ('Bebés'), ('Mascotas')
ON CONFLICT ((lower(nombre))) DO NOTHING;

INSERT INTO establecimientos (nombre) VALUES
    ('Éxito'), ('Carulla'), ('Jumbo'), ('Metro'), ('D1'), ('Ara'), ('Olímpica'),
    ('Alkosto'), ('Makro'), ('PriceSmart'), ('Surtimax'), ('Cruz Verde')
ON CONFLICT ((lower(nombre))) DO NOTHING;
