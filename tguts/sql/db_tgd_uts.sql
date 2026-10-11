-- =====================================================================
-- Sistema de Trabajos de Grado UTS - Base de datos
-- XAMPP (MariaDB/MySQL). Ejecutar UNA sola vez (phpMyAdmin o consola).
--   mysql -uroot < sql/db_tgd_uts.sql
-- =====================================================================

CREATE DATABASE IF NOT EXISTS db_tgd_uts CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE db_tgd_uts;
SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- Usuarios (RF-04, RF-05 - el administrador crea usuarios y asigna rol)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS usuarios (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  nombre        VARCHAR(100) NOT NULL,
  email         VARCHAR(120) NOT NULL UNIQUE,
  password      VARCHAR(255) NOT NULL,               -- PBKDF2-HMAC-SHA256 (o SHA-256 heredado)
  rol           ENUM('ADMIN','COORDINACION','DIRECTOR','EVALUADOR','ESTUDIANTE') NOT NULL,
  codigo        VARCHAR(20)  NULL,                    -- solo estudiantes
  activo        TINYINT(1)   NOT NULL DEFAULT 1,
  creado_en     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Banco de ideas (RF-09 a RF-13)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ideas (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  titulo        VARCHAR(200) NOT NULL,
  descripcion   TEXT NULL,
  docente_id    INT NOT NULL,                          -- docente/director que publica
  estado        ENUM('PUBLICADA','SELECCIONADA','CERRADA') NOT NULL DEFAULT 'PUBLICADA',
  creado_en     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_ideas_estado (estado),
  CONSTRAINT fk_ideas_docente FOREIGN KEY (docente_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Anteproyectos (RF-14 a RF-24, RF-34 a RF-36)
-- Estados: BORRADOR → ENVIADO → APROBADO_DIRECTOR → APROBADO_EVALUADOR
--          → ENTREGA_DOCUMENTO_FINAL → REVISIÓN_FINAL → SUSTENTACIÓN → FINALIZADO
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS anteproyectos (
  id                    INT AUTO_INCREMENT PRIMARY KEY,
  estudiante_id         INT NOT NULL,
  idea_id               INT NULL,
  titulo                VARCHAR(200) NOT NULL,
  documento             VARCHAR(255) NULL,             -- archivo subido (anteproyecto)
  director_id           INT NULL,
  evaluador_id          INT NULL,
  estado                ENUM('BORRADOR','ENVIADO','APROBADO_DIRECTOR','APROBADO_EVALUADOR','RECHAZADO',
                             'ENTREGA_DOCUMENTO_FINAL','REVISIÓN_FINAL','SUSTENTACIÓN','FINALIZADO') NOT NULL DEFAULT 'BORRADOR',
  calificacion_director DECIMAL(3,1) NULL,
  observacion_director  TEXT NULL,
  calificacion_evaluador DECIMAL(3,1) NULL,
  observacion_evaluador TEXT NULL,
  creado_en             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_anteproyecto_estudiante (estudiante_id),
  KEY idx_ant_estado (estado),
  CONSTRAINT fk_ant_estudiante FOREIGN KEY (estudiante_id) REFERENCES usuarios(id),
  CONSTRAINT fk_ant_idea      FOREIGN KEY (idea_id)      REFERENCES ideas(id) ON DELETE SET NULL,
  CONSTRAINT fk_ant_director  FOREIGN KEY (director_id)  REFERENCES usuarios(id),
  CONSTRAINT fk_ant_evaluador FOREIGN KEY (evaluador_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Entrega del documento final (nueva etapa tras APROBADO_EVALUADOR)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS entrega_final (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  anteproyecto_id INT NOT NULL,
  titulo          VARCHAR(200) NOT NULL,
  documento       VARCHAR(255) NOT NULL,             -- archivo PDF/Word subido
  fecha_entrega   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  estado          ENUM('ENTREGADO','EN_REVISION','OBSERVADO','APROBADO') NOT NULL DEFAULT 'ENTREGADO',
  observaciones   TEXT NULL,
  revisado_por    INT NULL,                          -- director o coordinación que revisa
  creado_en       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_entrega_ant (anteproyecto_id),
  CONSTRAINT fk_entrega_ant FOREIGN KEY (anteproyecto_id) REFERENCES anteproyectos(id) ON DELETE CASCADE,
  CONSTRAINT fk_entrega_rev FOREIGN KEY (revisado_por) REFERENCES usuarios(id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Sustentación (acto público de defensa)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sustentacion (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  anteproyecto_id INT NOT NULL,
  fecha           DATE NOT NULL,
  hora            TIME NOT NULL,
  lugar           VARCHAR(200) NOT NULL,             -- aula, sala, virtual, etc.
  resultado       ENUM('APROBADO','RECHAZADO','PENDIENTE') NOT NULL DEFAULT 'PENDIENTE',
  observaciones   TEXT NULL,
  creado_en       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_sust_ant (anteproyecto_id),
  CONSTRAINT fk_sust_ant FOREIGN KEY (anteproyecto_id) REFERENCES anteproyectos(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Historial de calificaciones (RF-35)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS calificaciones (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  anteproyecto_id INT NOT NULL,
  usuario_id      INT NOT NULL,                       -- quién calificó
  rol_calificador ENUM('DIRECTOR','EVALUADOR') NOT NULL,
  calificacion    DECIMAL(3,1) NOT NULL,
  observacion     TEXT NULL,
  creado_en       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_cal_ant FOREIGN KEY (anteproyecto_id) REFERENCES anteproyectos(id) ON DELETE CASCADE,
  CONSTRAINT fk_cal_usr  FOREIGN KEY (usuario_id)      REFERENCES usuarios(id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Notificaciones del sistema (RF-37 - eventos del proceso)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notificaciones (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  usuario_id  INT NOT NULL,
  titulo      VARCHAR(150) NOT NULL,
  mensaje     VARCHAR(400) NOT NULL,
  evento      VARCHAR(60)  NOT NULL,                  -- evento que la disparó
  leido       TINYINT(1) NOT NULL DEFAULT 0,
  correo_log  VARCHAR(400) NULL,                      -- registro del correo (SMTP pendiente)
  creado_en   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_notif_usuario (usuario_id, leido),
  CONSTRAINT fk_notif_usr FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Calendario académico (RF-32)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS calendario (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  titulo       VARCHAR(150) NOT NULL,
  descripcion  VARCHAR(400) NULL,
  fecha_inicio DATE NOT NULL,
  fecha_fin    DATE NULL,
  tipo         ENUM('ACADEMICO','HITO','ENTREGA','EXAMEN') NOT NULL DEFAULT 'ACADEMICO'
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Formatos de grado (RF-33)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS formatos (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  nombre      VARCHAR(150) NOT NULL,
  descripcion VARCHAR(400) NULL,
  url         VARCHAR(300) NOT NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Trámites: retiro, prórroga y beneficios (RF-38 a RF-40)
-- Flujo mínimo: estudiante solicita, coordinación resuelve.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tramites (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  estudiante_id INT NOT NULL,
  tipo          ENUM('RETIRO','PRORROGA','BENEFICIO') NOT NULL,
  detalle       TEXT NOT NULL,
  estado        ENUM('PENDIENTE','APROBADO','RECHAZADO') NOT NULL DEFAULT 'PENDIENTE',
  respuesta     TEXT NULL,
  resuelto_por  INT NULL,
  creado_en     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_tram_estado (estado),
  CONSTRAINT fk_tram_est FOREIGN KEY (estudiante_id) REFERENCES usuarios(id),
  CONSTRAINT fk_tram_res FOREIGN KEY (resuelto_por)  REFERENCES usuarios(id)
) ENGINE=InnoDB;

-- =====================================================================
-- DATOS DE PRUEBA
-- Contraseñas almacenadas con PBKDF2-HMAC-SHA256 (SecurityUtil), sal
-- aleatoria por usuario. Correspondencia:
--   admin123 | coord123 | director123 | evaluador123 | estudiante123
-- NOTA: estas cuentas son solo para desarrollo/pruebas. En producción deben
-- eliminarse o cambiarse (la página de login no las muestra si DB_HOST está
-- definido).
-- =====================================================================

INSERT INTO usuarios (nombre, email, password, rol, codigo) VALUES
('Ana Torres',    'admin@uts.edu.co',      'pbkdf2_sha256$120000$E2EGc3IMb981N7cna8wBIQ==$GQFqndLwE8h58a+CF85imypcFzfRKRX5YDv1OS+MOP4=',      'ADMIN',       NULL),
('Carla Ruiz',    'coord@uts.edu.co',      'pbkdf2_sha256$120000$iumAR4qQ07c4wrdd89TcsA==$6CMK7GHdGfXr5dAWCrPwvhbQbDSPIYeoh/i6ww3+2uI=',      'COORDINACION',NULL),
('Carlos Gómez',  'director@uts.edu.co',   'pbkdf2_sha256$120000$dCGQZrznijppEq9zGWe+Bw==$b249GjAC31/NI/siIJci79dPjOscl0fiwVG2meSsUoU=',   'DIRECTOR',    NULL),
('María Rodríguez','evaluador@uts.edu.co', 'pbkdf2_sha256$120000$yin9bM6KrJjlqks2fAO8RA==$Psqj3wo3fyecfTkoBUEeB5gB1PCSBaz4l4KuFfxI56A=',  'EVALUADOR',   NULL),
('Juan Pérez',    'estudiante@uts.edu.co', 'pbkdf2_sha256$120000$3EPIQK8Mq4HmmuDMHXNiGg==$PPuaSGLv13vrHLQWW0PhgUw/iEfdZMN9u2kHXObiS9k=', 'ESTUDIANTE',  '123456'),
('Laura Gómez',   'estudiante2@uts.edu.co','pbkdf2_sha256$120000$MPK0aO7CMnbZA0qKgSnYeg==$na5B9spBSVUYcMn4mrfOLqfwREikMYSGT9KKnbqnbow=', 'ESTUDIANTE',  '123457');

INSERT INTO ideas (titulo, descripcion, docente_id, estado) VALUES
('Sistema de gestión de inventarios', 'Sistema web para administrar productos, entradas y salidas de inventario.', 3, 'PUBLICADA'),
('Plataforma de prácticas empresariales', 'Web que conecta estudiantes de la UTS con empresas para prácticas.', 3, 'PUBLICADA'),
('App de reservas de canchas', 'Aplicación web para reservar canchas deportivas del campus.', 3, 'PUBLICADA');

INSERT INTO calendario (titulo, descripcion, fecha_inicio, fecha_fin, tipo) VALUES
('Inicio de semestre', 'Primer día de clases del periodo.', '2026-08-10', NULL, 'ACADEMICO'),
('Fecha límite de anteproyectos', 'Entrega de anteproyectos al director.', '2026-10-30', NULL, 'ENTREGA'),
('Sustentación de trabajos de grado', 'Jornada de sustentaciones ante comité.', '2026-12-05', '2026-12-10', 'HITO');

INSERT INTO formatos (nombre, descripcion, url) VALUES
('FDC-124 · Formato de anteproyecto (idea)', 'Formato oficial FDC-124: plantilla para presentar la idea y el anteproyecto del trabajo de grado.', 'formatos/FDC-124-Anteproyecto.pdf'),
('FDC-125 · Documento final', 'Formato oficial FDC-125: plantilla para el documento final del trabajo de grado.', 'formatos/FDC-125-DocumentoFinal.pdf');
