-- =====================================================================
-- migracion_seguridad.sql
-- Aplica sobre una base de datos YA existente (db_tgd_uts) los cambios de
-- esta iteración: columna de contraseña más ancha, índices y restricciones
-- únicas del flujo de trabajo.
--
--   mysql -uroot db_tgd_uts < sql/migracion_seguridad.sql
--
-- Las contraseñas almacenadas con el formato heredado
-- SHA-256(password + '|tguts-salt') NO se re-escriben aquí: el sistema las
-- migra automáticamente a PBKDF2 la primera vez que cada usuario inicia
-- sesión (ver login.jsp / common/seguridad.jsp).
-- =====================================================================

-- 1. La contraseña pasa de 64 a 255 caracteres (salt + hash PBKDF2).
ALTER TABLE usuarios MODIFY password VARCHAR(255) NOT NULL;

-- 2. Una sola entrega final y una sola sustentación por anteproyecto.
ALTER TABLE entrega_final ADD UNIQUE KEY uq_entrega_ant (anteproyecto_id);
ALTER TABLE sustentacion   ADD UNIQUE KEY uq_sust_ant (anteproyecto_id);

-- 3. Índices de apoyo a las consultas más frecuentes.
ALTER TABLE anteproyectos  ADD KEY idx_ant_estado (estado);
ALTER TABLE ideas          ADD KEY idx_ideas_estado (estado);
ALTER TABLE notificaciones ADD KEY idx_notif_usuario (usuario_id, leido);
ALTER TABLE tramites       ADD KEY idx_tram_estado (estado);
