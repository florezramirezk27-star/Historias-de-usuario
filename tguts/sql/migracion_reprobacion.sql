-- =====================================================================
-- migracion_reprobacion.sql
-- Agrega el estado «REPROBADO» al flujo del anteproyecto: decisión
-- DEFINITIVA del evaluador tras la aprobación del director. A diferencia
-- de RECHAZADO (aplazo), el anteproyecto reprobado es un estado terminal:
-- el estudiante no puede corregirlo ni volver a presentarlo.
--
--   mysql -uroot db_tgd_uts < sql/migracion_reprobacion.sql
--
-- En Clever Cloud: ejecutar el ALTER desde la consola SQL del addon.
-- El valor se agrega AL FINAL del ENUM para conservar los índices
-- existentes de las filas ya cargadas.
-- =====================================================================

ALTER TABLE anteproyectos
  MODIFY estado ENUM('BORRADOR','ENVIADO','APROBADO_DIRECTOR','APROBADO_EVALUADOR','RECHAZADO',
                     'ENTREGA_DOCUMENTO_FINAL','REVISIÓN_FINAL','SUSTENTACIÓN','FINALIZADO','REPROBADO')
  NOT NULL DEFAULT 'BORRADOR';
