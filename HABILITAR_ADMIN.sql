-- Proyecto AquiSis: habilitar el panel de moderacion para una cuenta existente.
-- 1) Reemplace el correo por el correo exacto con el que se registro en la app.
-- 2) Ejecute este archivo en Neon SQL Editor.
-- 3) Cierre sesion y vuelva a entrar en la app para sincronizar el rol.
-- IMPORTANTE: conceda este rol solo a una cuenta administradora de confianza.
UPDATE usuarios
SET rol = 'moderador'
WHERE lower(email) = lower('TU_CORREO_ADMIN@ejemplo.com');

-- Verifique que se actualizo exactamente una cuenta:
SELECT id, nombre, email, rol
FROM usuarios
WHERE lower(email) = lower('TU_CORREO_ADMIN@ejemplo.com');
