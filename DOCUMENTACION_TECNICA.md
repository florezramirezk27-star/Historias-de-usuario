# Documentación técnica — Sistema de Trabajos de Grado UTS

**Versión:** 1.0 (19/10/2026)
**Alcance:** Arquitectura, flujo de datos, seguridad, esquema BD, decisiones de diseño y operación.

---

## 1. Arquitectura general

```
┌─────────────────────────────────────────────────────────────────┐
│                        NAVEGADOR                                │
│  HTML5 + CSS3 (style.css) — sin JS obligatorio                 │
└──────────────────────────┬──────────────────────────────────────┘
                           │ HTTP/HTTPS
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    APACHE TOMCAT 9                              │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  JSP + JSTL (core, fmt, functions, sql) — 100 % vistas  │   │
│  │  common/                                                   │   │
│  │   ├── config.jsp      ← DataSource + Map "campos" POST    │   │
│  │   ├── guard.jsp       ← sesión + rol + usuario actual     │   │
│  │   ├── seguridad.jsp   ← PBKDF2, hash, migración           │   │
│  │   ├── verify_csrf.jsp ← token CSRF por sesión             │   │
│  │   ├── csrf.jsp        ← genera/obtiene token              │   │
│  │   ├── estado.jsp      ← badge visual de estado            │   │
│  │   ├── resolver.jsp    ← nombre por id (usuarios/ideas)    │   │
│  │   └── pgCampos/archivo_subido/pgGuardar ← subida (legacy) │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  ServletContextListener: PoolInicializador (HikariCP)    │   │
│  │  - Lee DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD   │   │
│  │  - Crea pool y lo publica en applicationScope.ds         │   │
│  └─────────────────────────────────────────────────────────┘   │
└──────────────────────────┬──────────────────────────────────────┘
                           │ JDBC (MySQL Connector/J 8.3)
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    MYSQL / MARIADB                              │
│  Base: db_tgd_uts  —  Tablas + índices + UNIQUE + datos demo   │
└─────────────────────────────────────────────────────────────────┘
```

**Puntos clave:**
- **Una sola clase Java:** `PoolInicializador` (inicializa pool HikariCP al arranque).
- **Toda la lógica de negocio** vive en archivos `.jsp` usando `<sql:query>`, `<sql:update>`, `<sql:transaction>`.
- **Configuración** 100 % declarativa: `web.xml`, `META-INF/context.xml`, variables de entorno.

---

## 2. Esquema de base de datos (resumen)

```sql
-- Usuarios y autenticación
CREATE TABLE usuarios (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(150) NOT NULL,
  email VARCHAR(150) NOT NULL UNIQUE,
  password VARCHAR(255) NOT NULL,          -- PBKDF2: pbkdf2_sha256$iter$sal$hash
  rol ENUM('ADMIN','COORDINACION','DIRECTOR','EVALUADOR','ESTUDIANTE') NOT NULL,
  codigo VARCHAR(30),                      -- código estudiante / nómina docente
  activo TINYINT(1) DEFAULT 1,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_usuarios_rol_activo (rol, activo)
);

-- Banco de ideas
CREATE TABLE ideas (
  id INT AUTO_INCREMENT PRIMARY KEY,
  titulo VARCHAR(200) NOT NULL,
  descripcion TEXT,
  docente_id INT NOT NULL,                 -- FK usuarios (DIRECTOR/EVALUADOR)
  estado ENUM('PUBLICADA','SELECCIONADA','CERRADA') DEFAULT 'PUBLICADA',
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (docente_id) REFERENCES usuarios(id),
  INDEX idx_ideas_estado (estado)
);

-- Anteproyectos (núcleo del flujo)
CREATE TABLE anteproyectos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  estudiante_id INT NOT NULL,              -- FK usuarios (ESTUDIANTE)
  idea_id INT NOT NULL,                    -- FK ideas
  titulo VARCHAR(200) NOT NULL,
  director_id INT,                         -- FK usuarios (DIRECTOR)
  evaluador_id INT,                        -- FK usuarios (EVALUADOR)
  documento VARCHAR(500),                  -- URL (http/https) o ruta relativa
  estado ENUM('BORRADOR','ENVIADO','APROBADO_DIRECTOR','APROBADO_EVALUADOR',
              'ENTREGA_DOCUMENTO_FINAL','REVISIÓN_FINAL','SUSTENTACIÓN','FINALIZADO','RECHAZADO')
       DEFAULT 'BORRADOR',
  calificacion_director DECIMAL(3,1),
  observacion_director TEXT,
  calificacion_evaluador DECIMAL(3,1),
  observacion_evaluador TEXT,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (estudiante_id) REFERENCES usuarios(id),
  FOREIGN KEY (idea_id) REFERENCES ideas(id),
  FOREIGN KEY (director_id) REFERENCES usuarios(id),
  FOREIGN KEY (evaluador_id) REFERENCES usuarios(id),
  INDEX idx_anteproyectos_estado (estado),
  INDEX idx_anteproyectos_director (director_id),
  INDEX idx_anteproyectos_evaluador (evaluador_id),
  INDEX idx_anteproyectos_estudiante (estudiante_id)
);

-- Entrega final (documento de grado)
CREATE TABLE entrega_final (
  id INT AUTO_INCREMENT PRIMARY KEY,
  anteproyecto_id INT NOT NULL UNIQUE,     -- 1:1 con anteproyecto
  titulo VARCHAR(200) NOT NULL,
  documento VARCHAR(500) NOT NULL,         -- URL
  estado ENUM('ENTREGADO','EN_REVISION','OBSERVADO','APROBADO') DEFAULT 'ENTREGADO',
  observaciones TEXT,
  revisado_por INT,                        -- FK usuarios (DIR/COORD/ADMIN)
  fecha_entrega TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (anteproyecto_id) REFERENCES anteproyectos(id),
  FOREIGN KEY (revisado_por) REFERENCES usuarios(id)
);

-- Sustentación
CREATE TABLE sustentacion (
  id INT AUTO_INCREMENT PRIMARY KEY,
  anteproyecto_id INT NOT NULL UNIQUE,
  fecha DATETIME NOT NULL,
  lugar VARCHAR(200),
  resultado ENUM('APROBADO','RECHAZADO','PENDIENTE') DEFAULT 'PENDIENTE',
  acta_url VARCHAR(500),
  FOREIGN KEY (anteproyecto_id) REFERENCES anteproyectos(id)
);

-- Historial de calificaciones (auditoría)
CREATE TABLE calificaciones (
  id INT AUTO_INCREMENT PRIMARY KEY,
  anteproyecto_id INT NOT NULL,
  usuario_id INT NOT NULL,                 -- quien califica
  rol_calificador ENUM('DIRECTOR','EVALUADOR') NOT NULL,
  calificacion DECIMAL(3,1) NOT NULL,
  observacion TEXT,
  fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (anteproyecto_id) REFERENCES anteproyectos(id),
  FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
  UNIQUE KEY uk_calif_ant_rol (anteproyecto_id, rol_calificador, usuario_id)
);

-- Notificaciones (eventos del proceso)
CREATE TABLE notificaciones (
  id INT AUTO_INCREMENT PRIMARY KEY,
  usuario_id INT NOT NULL,
  titulo VARCHAR(200) NOT NULL,
  mensaje TEXT NOT NULL,
  evento VARCHAR(50) NOT NULL,
  correo_log TEXT,                         -- log de envío SMTP (pendiente)
  leida TINYINT(1) DEFAULT 0,
  creada_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
  INDEX idx_notif_usuario_leida (usuario_id, leida)
);

-- Calendario académico
CREATE TABLE calendario (
  id INT AUTO_INCREMENT PRIMARY KEY,
  titulo VARCHAR(150) NOT NULL,
  descripcion TEXT,
  fecha_inicio DATE NOT NULL,
  fecha_fin DATE,
  tipo ENUM('ACADEMICO','ENTREGA','HITO','OTRO') DEFAULT 'ACADEMICO'
);

-- Formatos de grado
CREATE TABLE formatos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(150) NOT NULL,
  descripcion TEXT,
  url VARCHAR(500) NOT NULL                -- http(s)://...  o  formatos/archivo.pdf
);

-- Trámites (retiro, prórroga, beneficios)
CREATE TABLE tramites (
  id INT AUTO_INCREMENT PRIMARY KEY,
  estudiante_id INT NOT NULL,
  tipo ENUM('RETIRO','PRORROGA','BENEFICIO') NOT NULL,
  estado ENUM('SOLICITADO','APROBADO','RECHAZADO') DEFAULT 'SOLICITADO',
  fecha_inicio DATE,
  fecha_fin DATE,
  motivo TEXT,
  resuelto_por INT,                        -- FK usuarios (COORD/ADMIN)
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (estudiante_id) REFERENCES usuarios(id),
  FOREIGN KEY (resuelto_por) REFERENCES usuarios(id),
  INDEX idx_tramites_estado (estado)
);
```

---

## 3. Flujo de estados del anteproyecto

```
BORRADOR
   │  (estudiante envía con director válido + URL)
   ▼
ENVIADO
   │  (director califica + aprueba)
   ▼
APROBADO_DIRECTOR
   │  (evaluador asignado automáticamente; evalúa + aprueba)
   ▼
APROBADO_EVALUADOR
   │  (estudiante entrega documento final por URL)
   ▼
ENTREGA_DOCUMENTO_FINAL
   │  (director/coord revisa: EN_REVISION / OBSERVADO / APROBADO)
   ▼
REVISIÓN_FINAL  (si APROBADO)  ←── OBSERVADO (estudiante corrige → ENTREGADO → vuelve aquí)
   │  (coordinación programa sustentación)
   ▼
SUSTENTACIÓN
   │  (resultado APROBADO/RECHAZADO)
   ▼
FINALIZADO  /  vuelve a REVISIÓN_FINAL
```

**Guardas de transición (en cada UPDATE):**
- `AND estado IN ('BORRADOR','RECHAZADO')` al enviar
- `AND estado = 'ENVIADO'` al calificar director
- `AND estado = 'APROBADO_DIRECTOR'` al calificar evaluador
- `AND estado = 'APROBADO_EVALUADOR'` al crear entrega
- `AND estado = 'ENTREGA_DOCUMENTO_FINAL'` al revisar/corregir
- `AND estado = 'REVISIÓN_FINAL'` al programar sustentación

---

## 4. Seguridad

| Capa | Implementación |
|------|----------------|
| **Contraseñas** | `pgHash()` → PBKDF2-HMAC-SHA256, 120k iteraciones, sal 16 B aleatoria. Formato: `pbkdf2_sha256$120000$<salB64>$<hashB64>`. Migración automática de SHA-256 heredado en primer login (`pgNecesitaMigrar`). |
| **Sesiones** | Rotación de ID en `login.jsp` (`invalidate()` + `getSession(true)`). Timeout 30 min (`web.xml`). Cookie `HttpOnly`, `SameSite=Lax` (`context.xml`). `tracking-mode=COOKIE`. |
| **CSRF** | Token por sesión (`common/csrf.jsp`). `<input name="csrf_token" value="${csrfToken}">` en todos los formularios. `common/verify_csrf.jsp` valida en **todo POST** (usa Map `campos` de `config.jsp`, compatible con `multipart`). |
| **Autorización** | `common/guard.jsp` → `sessionScope.usuario` y `rol`. Guardas por página (`rol eq '...'`), por propiedad (`estudiante_id = yo.id`, `director_id = yo.id`, etc.) y por estado (`AND estado = '...'`). |
| **Documentos** | **Solo URL** (`http://`/`https://`). Validación servidor (`fn:startsWith`). Subida de archivos retirada de formularios; `descargar.jsp` conservado para compatibilidad (valida sesión, rol, propiedad, ruta canónica). |
| **Inyección SQL** | Parámetros vinculados (`<sql:param>`) en todas las consultas JSTL. |
| **XSS** | Salida con `<c:out>` / `fn:escapeXml` en todos los datos dinámicos. |

---

## 5. Decisiones de diseño documentadas

| Tema | Decisión | Justificación / Acuerdo |
|------|----------|-------------------------|
| **Subida de archivos** | Retirada; solo URL | Acordado con profesor: "dejar solo URL y documentar". Infraestructura legacy conservada. |
| **Asignación de director** | Permitida en **todos los estados** | Diapositiva del profesor: "Agregar un director a un anteproyecto aprobado". |
| **Formato de documentos** | URL `http(s)` o ruta relativa `formatos/...` | BD ya trae rutas locales; JSP las convierte en enlaces con `c:url`. |
| **Banco de ideas – docente** | Roles `DIRECTOR` y `EVALUADOR` (no COORDINACION) | Alineado con validación servidor existente. |
| **Datos de prueba** | Marcados como **demostración** | Avisos en UI (`login.jsp`, `formatos.jsp`, `calendario.jsp`), comentarios en SQL, nota en README. |
| **Nombre institucional** | "Universitaria Tecnológica de Santander (UTS)" | OCR de logos (`images.png`, `fondologin.jpg`). Corregido "Universidad UTS". |
| **JDK** | 17 (pom.xml `maven.compiler.release=17`) | README actualizado (antes decía JDK 8). |

---

## 6. Despliegue

### Local (Docker)
```bash
docker network create tguts_net
docker run -d --name tguts-mysql --network tguts_net \
  -e MYSQL_ROOT_PASSWORD=rootpw -e MYSQL_DATABASE=db_tgd_uts \
  -v "%CD%\tguts\sql\db_tgd_uts.sql:/docker-entrypoint-initdb.d/01.sql:ro" mysql:8.0

cd tguts && mvn -B clean package

docker run -d --name tguts-tomcat --network tguts_net -p 18080:8080 \
  -e DB_HOST=tguts-mysql -e DB_PORT=3306 -e DB_NAME=db_tgd_uts \
  -e DB_USER=root -e DB_PASSWORD=rootpw \
  -v "%CD%\target\tguts.war:/usr/local/tomcat/webapps/ROOT.war:ro" \
  tomcat:9.0-jdk17-temurin
```
Acceso: `http://localhost:18080/`

### Render (cloud)
- `Dockerfile`: multi-stage (Maven build → Tomcat 9 JDK 17).
- `render.yaml`: Blueprint (Web Service + variables de entorno).
- Variables: `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` (secreto), `PORT=8080`.
- BD gestionada en Clever Cloud (MySQL).

---

## 7. Pruebas automatizadas (E2E)

**Script:** `pruebas/e2e_tguts.py` (Python 3, stdlib).
- Usa `urllib` + `http.cookiejar` + `subprocess` (docker exec mysql).
- 19 casos cubriendo los 10 pendientes + flujos completos.
- Evidencia real: códigos HTTP, URLs finales, consultas BD, fragmentos HTML.

**Ejecutar:**
```bash
python pruebas/e2e_tguts.py
# → 19/19 APROBADOS (ver TEST_RESULTS.md)
```

---

## 8. Mantenimiento y operación

| Tarea | Comando / Acción |
|-------|------------------|
| Reconstruir WAR | `cd tguts && mvn clean package` |
| Actualizar BD (migración seguridad) | `mysql -u... < tguts/sql/migracion_seguridad.sql` |
| Ver logs Tomcat | `docker logs tguts-tomcat` |
| Ver logs MySQL | `docker logs tguts-mysql` |
| Backup BD | `docker exec tguts-mysql mysqldump -uroot -prootpw db_tgd_uts > backup.sql` |
| Rotar contraseña PBKDF2 | Cambiar `PBKDF2_ITERATIONS` en entorno; hashes se migran en login. |

---

## 9. Limitaciones conocidas

1. **SMTP pendiente:** `correo_log` en `notificaciones` y `tramites` solo registra texto; no hay envío real.
2. **Archivos subidos (legacy):** `descargar.jsp` sirve archivos de `uploadDir/` (fuera del WAR). En contenedores efímeros (Render) **no persisten**; usar URLs externas.
3. **Calendario / Formatos iniciales:** Son plantillas/fechas de demostración. Deben reemplazarse por los oficiales antes de producción.
4. **Sin tests unitarios Java:** Solo `PoolInicializador` (clase única). La lógica está en JSP; pruebas funcionales vía E2E.
5. **Concurrencia:** `<sql:transaction>` serializa en BD; no hay bloqueo optimista en capa JSP.

---

## 10. Referencias cruzadas

| Documento | Contenido |
|-----------|-----------|
| `README.md` | Puesta en marcha, usuarios, despliegue, notas |
| `TEST_RESULTS.md` | Registro de pruebas E2E (19/19) con evidencia |
| `GUION.md` | Guion de demostración paso a paso (tablas) |
| `DEPLOY_RENDER.md` | Guía detallada de despliegue en Render |
| `tguts/sql/db_tgd_uts.sql` | Esquema completo + datos de demostración |
| `tguts/sql/migracion_seguridad.sql` | Migración de bases existentes (hashes, índices) |
| `pruebas/e2e_tguts.py` | Script de pruebas end-to-end reproducible |