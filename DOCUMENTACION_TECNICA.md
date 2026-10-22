# Documentación técnica — Sistema de Trabajos de Grado UTS

**Versión:** 2.0 (22/10/2026) — describe el código verificado con **99/99 pruebas E2E aprobadas**.
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
  nombre VARCHAR(100) NOT NULL,
  email VARCHAR(120) NOT NULL UNIQUE,
  password VARCHAR(255) NOT NULL,          -- PBKDF2: pbkdf2_sha256$iter$sal$hash
  rol ENUM('ADMIN','COORDINACION','DIRECTOR','EVALUADOR','ESTUDIANTE') NOT NULL,
  codigo VARCHAR(20) NULL,                 -- solo estudiantes
  activo TINYINT(1) NOT NULL DEFAULT 1,
  creado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Banco de ideas
CREATE TABLE ideas (
  id INT AUTO_INCREMENT PRIMARY KEY,
  titulo VARCHAR(200) NOT NULL,
  descripcion TEXT NULL,
  docente_id INT NOT NULL,                 -- FK usuarios (DIRECTOR/EVALUADOR)
  estado ENUM('PUBLICADA','SELECCIONADA','CERRADA') NOT NULL DEFAULT 'PUBLICADA',
  creado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (docente_id) REFERENCES usuarios(id),
  KEY idx_ideas_estado (estado)
);

-- Anteproyectos (núcleo del flujo)
CREATE TABLE anteproyectos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  estudiante_id INT NOT NULL,              -- FK usuarios (ESTUDIANTE)
  idea_id INT NULL,                        -- FK ideas
  titulo VARCHAR(200) NOT NULL,
  documento VARCHAR(255) NULL,             -- URL (http/https) o ruta relativa
  director_id INT NULL,                    -- FK usuarios (DIRECTOR)
  evaluador_id INT NULL,                   -- FK usuarios (EVALUADOR)
  estado ENUM('BORRADOR','ENVIADO','APROBADO_DIRECTOR','APROBADO_EVALUADOR',
              'ENTREGA_DOCUMENTO_FINAL','REVISIÓN_FINAL','SUSTENTACIÓN','FINALIZADO','RECHAZADO')
       NOT NULL DEFAULT 'BORRADOR',
  calificacion_director DECIMAL(3,1) NULL,
  observacion_director TEXT NULL,
  calificacion_evaluador DECIMAL(3,1) NULL,
  observacion_evaluador TEXT NULL,
  creado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (estudiante_id) REFERENCES usuarios(id),
  FOREIGN KEY (idea_id) REFERENCES ideas(id) ON DELETE SET NULL,
  FOREIGN KEY (director_id) REFERENCES usuarios(id),
  FOREIGN KEY (evaluador_id) REFERENCES usuarios(id),
  UNIQUE KEY uq_anteproyecto_estudiante (estudiante_id),
  KEY idx_ant_estado (estado)
);

-- Entrega final (documento de grado)
CREATE TABLE entrega_final (
  id INT AUTO_INCREMENT PRIMARY KEY,
  anteproyecto_id INT NOT NULL UNIQUE,     -- 1:1 con anteproyecto
  titulo VARCHAR(200) NOT NULL,
  documento VARCHAR(255) NOT NULL,         -- URL
  estado ENUM('ENTREGADO','EN_REVISION','OBSERVADO','APROBADO') NOT NULL DEFAULT 'ENTREGADO',
  observaciones TEXT NULL,
  revisado_por INT NULL,                   -- FK usuarios (DIR/COORD/ADMIN)
  fecha_entrega TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  creado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (anteproyecto_id) REFERENCES anteproyectos(id) ON DELETE CASCADE,
  FOREIGN KEY (revisado_por) REFERENCES usuarios(id)
);

-- Sustentación
CREATE TABLE sustentacion (
  id INT AUTO_INCREMENT PRIMARY KEY,
  anteproyecto_id INT NOT NULL UNIQUE,
  fecha DATE NOT NULL,
  hora TIME NOT NULL,
  lugar VARCHAR(200) NOT NULL,
  resultado ENUM('APROBADO','RECHAZADO','PENDIENTE') DEFAULT 'PENDIENTE',
  observaciones TEXT NULL,
  creado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (anteproyecto_id) REFERENCES anteproyectos(id) ON DELETE CASCADE
);

-- Historial de calificaciones (auditoría)
CREATE TABLE calificaciones (
  id INT AUTO_INCREMENT PRIMARY KEY,
  anteproyecto_id INT NOT NULL,
  usuario_id INT NOT NULL,                 -- quien califica
  rol_calificador ENUM('DIRECTOR','EVALUADOR') NOT NULL,
  calificacion DECIMAL(3,1) NOT NULL,
  observacion TEXT NULL,
  creado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (anteproyecto_id) REFERENCES anteproyectos(id) ON DELETE CASCADE,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
);

-- Notificaciones (eventos del proceso)
CREATE TABLE notificaciones (
  id INT AUTO_INCREMENT PRIMARY KEY,
  usuario_id INT NOT NULL,
  titulo VARCHAR(150) NOT NULL,
  mensaje VARCHAR(400) NOT NULL,
  evento VARCHAR(60) NOT NULL,
  correo_log VARCHAR(400) NULL,           -- log de envío SMTP (pendiente)
  leido TINYINT(1) NOT NULL DEFAULT 0,
  creado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
  KEY idx_notif_usuario_leida (usuario_id, leido)
);

-- Calendario académico
CREATE TABLE calendario (
  id INT AUTO_INCREMENT PRIMARY KEY,
  titulo VARCHAR(150) NOT NULL,
  descripcion VARCHAR(400) NULL,
  fecha_inicio DATE NOT NULL,
  fecha_fin DATE NULL,
  tipo ENUM('ACADEMICO','HITO','ENTREGA','EXAMEN') NOT NULL DEFAULT 'ACADEMICO'
);

-- Formatos de grado
CREATE TABLE formatos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(150) NOT NULL,
  descripcion VARCHAR(400) NULL,
  url VARCHAR(300) NOT NULL
);

-- Trámites (retiro, prórroga, beneficios)
CREATE TABLE tramites (
  id INT AUTO_INCREMENT PRIMARY KEY,
  estudiante_id INT NOT NULL,
  tipo ENUM('RETIRO','PRORROGA','BENEFICIO') NOT NULL,
  detalle TEXT NOT NULL,
  estado ENUM('PENDIENTE','APROBADO','RECHAZADO') NOT NULL DEFAULT 'PENDIENTE',
  respuesta TEXT NULL,
  resuelto_por INT NULL,                   -- FK usuarios (COORD/ADMIN)
  creado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (estudiante_id) REFERENCES usuarios(id),
  FOREIGN KEY (resuelto_por) REFERENCES usuarios(id),
  KEY idx_tramites_estado (estado)
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
REVISIÓN_FINAL  (si APROBADO)  ←── OBSERVADO (estudiante corrige → ENTREGADO → vuelve a ENTREGA_DOCUMENTO_FINAL)
   │  (coordinación programa sustentación)
   ▼
SUSTENTACIÓN
   │  (resultado APROBADO/RECHAZADO)
   ▼
FINALIZADO  /  vuelve a REVISIÓN_FINAL
```

**Guardas de transición (en cada UPDATE):**
- `AND estado IN ('BORRADOR','RECHAZADO')` al enviar
- `AND estado = 'ENVIADO'` al calificar el director
- `AND estado = 'APROBADO_DIRECTOR'` al calificar el evaluador
- `AND estado = 'APROBADO_EVALUADOR'` al crear la entrega final
- `AND estado = 'ENTREGA_DOCUMENTO_FINAL'` al corregir una entrega observada
- `AND estado = 'REVISIÓN_FINAL'` al programar la sustentación

**Ciclo de corrección del documento final (resuelto en esta versión):**

| Situación | Regla aplicada | Resultado |
|---|---|---|
| Entrega `OBSERVADO` o `EN_REVISION` mientras el trabajo está en `REVISIÓN_FINAL` | El anteproyecto **vuelve a `ENTREGA_DOCUMENTO_FINAL`** | El estudiante siempre puede corregir y reenviar |
| Revisión del documento en `SUSTENTACIÓN` o `FINALIZADO` | La revisión se **bloquea** (guarda por estado en el POST) y el formulario se oculta con el aviso "El documento final ya está cerrado…" | El documento no puede quedar observado sin posiblidad de corrección |
| Aprobación de la entrega (`APROBADO`) en `ENTREGA_DOCUMENTO_FINAL` | El anteproyecto pasa a `REVISIÓN_FINAL` | Habilita la programación de la sustentación |

> Esta regla sustituye la *limitación conocida* de la versión 1.0, en la que una entrega observada desde `REVISIÓN_FINAL` dejaba al estudiante sin formulario de corrección. Ahora está verificado por los casos **J-08, J-09, J-10, J-12, J-13 y J-16** de la suite E2E.

---

## 4. Seguridad

| Capa | Implementación |
|------|----------------|
| **Contraseñas** | `pgHash()` → PBKDF2-HMAC-SHA256, 120k iteraciones, sal 16 B aleatoria. Formato: `pbkdf2_sha256$120000$<salB64>$<hashB64>`. Migración automática de SHA-256 heredado en primer login (`pgNecesitaMigrar`). |
| **Sesiones** | Rotación de ID en `login.jsp` (`invalidate()` + `getSession(true)`). Timeout 30 min (`web.xml`). Cookie `HttpOnly`, `SameSite=Lax` (`context.xml`). `tracking-mode=COOKIE`. |
| **CSRF** | Token por sesión (`common/csrf.jsp`). `<input name="csrf_token" value="${csrfToken}">` en todos los formularios. `common/verify_csrf.jsp` valida en **todo POST** (usa Map `campos` de `config.jsp`, compatible con `multipart`). **Nota:** El procesamiento `multipart` en `pgCampos` guarda el archivo antes de validar sesión/CSRF; mover validación antes de `pgCampos` en próxima iteración. |
| **Autorización** | `common/guard.jsp` → `sessionScope.usuario` y `rol`. Guardas por página (`rol eq '...'`), por propiedad (`estudiante_id = yo.id`, `director_id = yo.id`, etc.) y por estado (`AND estado = '...'`). |
| **Documentos** | **Solo URL** (`http://`/`https://`) o ruta relativa segura (`formatos/...`). Validación servidor (`fn:startsWith`) y rama de ruta relativa que rechaza cualquier valor con `:`. Subida de archivos retirada de formularios; `descargar.jsp` conservado para compatibilidad (valida sesión, rol, propiedad, ruta canónica). |
| **Inyección SQL** | Parámetros vinculados (`<sql:param>`) en consultas JSTL. Excepción conocida: `tramites.jsp` usa `CONCAT` con expresión EL en notificación (línea 47); corregir en próxima iteración. |
| **XSS** | Salida con `<c:out>` / `fn:escapeXml` en todos los datos dinámicos. En `formatos.jsp` la URL del documento se escapa **antes** de construir el `href` (`href="${fn:escapeXml(fmtUrl)}"`), lo que cierra la inyección de HTML en ese enlace (caso E2E L-05). |

---

## 5. Decisiones de diseño documentadas

| Tema | Decisión | Justificación / Acuerdo |
|------|----------|-------------------------|
| **Subida de archivos** | Retirada; solo URL | Decisión de implementación pendiente de validar con el profesor. La diapositiva indica "subir anteproyectos". Infraestructura legacy conservada. |
| **Asignación de director** | Permitida en **todos los estados** | Diapositiva del profesor: "Agregar un director a un anteproyecto aprobado". |
| **Formato de documentos** | URL `http(s)` o ruta relativa `formatos/...` | BD ya trae rutas locales; JSP las convierte en enlaces con `c:url`. |
| **Banco de ideas – docente** | Roles `DIRECTOR` y `EVALUADOR` (no COORDINACION) | Alineado con validación servidor existente. |
| **Datos de prueba** | Marcados como **demostración** | Avisos en UI (`login.jsp`, `formatos.jsp`, `calendario.jsp`), comentarios en SQL, nota en README. |
| **Nombre institucional** | "Universitaria Tecnológica de Santander (UTS)" | OCR de logos (`images.png`, `fondologin.jpg`). Corregido "Universidad UTS". |
| **JDK** | 17 (pom.xml `maven.compiler.release=17`) | README actualizado (antes decía JDK 8); la build verificada se hizo con JDK 21. |
| **CRUD de calendario y formatos** | Consulta abierta a cualquier usuario autenticado; alta, edición y borrado solo para ADMIN/COORDINACIÓN | Coherente con el resto de módulos y con la verificación E2E (K-01…K-05, L-01…L-06). |
| **Búsqueda en coordinación** | Un único campo que busca por **nombre, código de matrícula o correo** | El enunciado del parcial pide la búsqueda por nombre y código; el correo se añadió por comodidad (casos F-01…F-04). |
| **Asignación de evaluador** | Solo es posible tras la aprobación del director | Evita asignar evaluación a un anteproyecto que todavía no tiene Avalúo de director (caso G-04). |

---

## 6. Despliegue

### Local con XAMPP (entorno verificado en las pruebas)

| Paso | Acción | Detalle |
|---|---|---|
| 1 | Base de datos | `C:\xampp\mysql\bin\mysql.exe -uroot -e "source tguts/sql/db_tgd_uts.sql"` → base `db_tgd_uts` |
| 2 | Compilar | `cd tguts && mvn clean package` → genera `tguts/target/tguts.war` |
| 3 | Desplegar | Copiar `tguts.war` a `C:\xampp\tomcat\webapps\` y reiniciar Tomcat |
| 4 | Acceso | `http://localhost:8080/tguts/` — Tomcat **8.5.96**, MariaDB **10.4.32** |

### Local con Docker (alternativa documentada, no ejecutada en esta versión)
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

## 7. Pruebas automatizadas (histórico)

Durante el desarrollo se verificó el sistema con una suite E2E de **99 casos** en 15 bloques (A–O), escrita en Python 3 con **solo librería estándar**, contra el entorno local XAMPP: **99/99 APROBADOS (66,2 s) el 22/10/2026**. La suite creaba sus propias cuentas `e2e-<rol>@uts.edu.co` y las borraba al terminar, por lo que los datos de demostración quedaban intactos (caso O-01).

> Los scripts de la suite y la salida íntegra de la ejecución se retiraron del repositorio. El detalle caso por caso, el alcance de cada bloque y los defectos corregidos se conservan en `TEST_RESULTS.md`.

---

## 8. Mantenimiento y operación

| Tarea | Comando / Acción |
|-------|------------------|
| Reconstruir WAR | `cd tguts && mvn clean package` |
| Actualizar BD (migración seguridad) | `mysql -u... < tguts/sql/migracion_seguridad.sql` (en PowerShell: `cmd /c "mysql -uroot < tguts\sql\migracion_seguridad.sql"`) |
| Consultar la BD del entorno local | `C:\xampp\mysql\bin\mysql.exe -uroot -N -B --default-character-set=utf8mb4 db_tgd_uts -e "<sql>"` |
| Ver logs Tomcat (local) | `C:\xampp\tomcat\logs\catalina.<fecha>.log` |
| Ver logs Tomcat (Docker) | `docker logs tguts-tomcat` |
| Ver logs MySQL (Docker) | `docker logs tguts-mysql` |
| Backup BD (Docker) | `docker exec tguts-mysql mysqldump -uroot -prootpw db_tgd_uts > backup.sql` |
| Rotar contraseña PBKDF2 | Cambiar `PBKDF2_ITERATIONS` en entorno; hashes se migran en login. |

---

## 9. Limitaciones conocidas

1. **SMTP pendiente:** `correo_log` en `notificaciones` y `tramites` solo registra texto; no hay envío real.
2. **Archivos subidos (legacy):** `descargar.jsp` sirve archivos de `uploadDir/` (fuera del WAR). En contenedores efímeros (Render) **no persisten**; usar URLs externas.
3. **Calendario / Formatos iniciales:** Son plantillas/fechas de demostración. Deben reemplazarse por los oficiales antes de producción.
4. **Sin tests unitarios Java:** Solo `PoolInicializador` (clase única). La lógica está en JSP; la verificación se hizo con una suite E2E funcional de 99 casos (hoy retirada del repositorio, ver sección 7).
5. **Concurrencia:** `<sql:transaction>` serializa en BD; no hay bloqueo optimista en capa JSP.
6. **Expresión EL dentro de `CONCAT` en `tramites.jsp`:** el `INSERT` de la notificación concatena una expresión JSTL en el `VALUES` (línea ~47). Es un punto a parametrizar en la próxima iteración.
7. **Procesamiento `multipart` antes de la validación:** `common/config.jsp` prepara el Map `campos` (y `pgCampos` guarda el archivo) antes de `common/verify_csrf.jsp`; en la interfaz actual los formularios ya no suben archivos, por lo que el riesgo es residual.

---

## 10. Referencias cruzadas

| Documento | Contenido |
|-----------|-----------|
| `README.md` | Puesta en marcha, usuarios, catálogo RF-01…RF-43, despliegue, notas |
| `TEST_RESULTS.md` | Registro histórico de las pruebas E2E (99/99) y detalle de los bugs corregidos |
| `GUION.md` | Guion de demostración paso a paso (todo en tablas) |
| `DEPLOY_RENDER.md` | Guía detallada de despliegue en Render |
| `tguts/sql/db_tgd_uts.sql` | Esquema completo + datos de demostración |
| `tguts/sql/migracion_seguridad.sql` | Migración de bases existentes (hashes, índices) |