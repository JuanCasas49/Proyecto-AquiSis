INSERT INTO usuarios (nombre, email)
VALUES (CAST(:nombre AS text), CAST(:email AS text))
ON CONFLICT ((lower(email))) DO UPDATE SET nombre = EXCLUDED.nombre
RETURNING id, nombre, email
