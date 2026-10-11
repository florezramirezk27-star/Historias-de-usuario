# Historias-de-usuario

**Sistema de Trabajos de Grado UTS** — Aplicación web desarrollada en **JSP + JSTL** (Maven, empaquetado WAR) sobre una base de datos **MySQL/MariaDB (XAMPP)**.

El sistema gestiona todo el proceso de un trabajo de grado: desde la publicación de ideas por parte de los docentes, el registro y aprobación del anteproyecto, la asignación de director y evaluador, la entrega del documento final, la sustentación y las notificaciones del proceso, además de trámites (retiro, prórroga y beneficios), calendario académico, formatos e informes.

> Proyecto con la lógica 100 % en **JSP + JSTL** (core, fmt, functions y sql). La única clase
> **Java** es `PoolInicializador`, que crea el pool de conexiones JDBC (HikariCP).

---

## Tecnologías

| Componente | Detalle |
|---|---|
| Lenguaje de vistas | JSP + JSTL 1.2 |
| Empaquetado | Maven (WAR) |
| Servidor | Apache Tomcat 9 (Java EE `javax`) |
| Base de datos | MySQL / MariaDB vía XAMPP |
| Conexión | JSTL `<sql:setDataSource>` + pool **HikariCP** + MySQL Connector/J 8.3 |
| Subida de archivos | Apache Commons FileUpload 1.5 / Commons IO 2.15 |
| Seguridad | PBKDF2-HMAC-SHA256 (JDK nativo), token CSRF, sesiones con rotación, guardas por rol |

---

## Requisitos

- JDK 8 o superior
- Apache Maven 3.6+
- Apache Tomcat 9
- XAMPP (MySQL / MariaDB) iniciado

---

## Puesta en marcha

1. **Crear la base de datos** (una sola vez):

   ```bash
   mysql -uroot < tguts/sql/db_tgd_uts.sql
   ```

   O importar `tguts/sql/db_tgd_uts.sql` desde phpMyAdmin. La base se llama `db_tgd_uts` e incluye datos de prueba.

2. **Compilar el WAR:**

   ```bash
   cd tguts
   mvn clean package
   ```

   Se genera `tguts/target/tguts.war`.

3. **Desplegar** copiando `tguts.war` a la carpeta `webapps/` de Tomcat y arrancando el servidor.

4. **Acceder** en el navegador:

   ```
   http://localhost:8080/tguts/
   ```

---

## Usuarios de prueba

| Rol | Correo | Contraseña |
|---|---|---|
| Administrador | `admin@uts.edu.co` | `admin123` |
| Coordinación | `coord@uts.edu.co` | `coord123` |
| Director | `director@uts.edu.co` | `director123` |
| Evaluador | `evaluador@uts.edu.co` | `evaluador123` |
| Estudiante | `estudiante@uts.edu.co` | `estudiante123` |

Las contraseñas de los datos de prueba ya vienen **hasheadas con PBKDF2-HMAC-SHA256**
(formato `pbkdf2_sha256$120000$<salB64>$<hashB64>`); en la página de login solo se
muestran como referencia cuando se corre en local (sin variables `DB_HOST` definidas).

---

## Roles y funcionalidades

- **ADMIN** — Gestión de usuarios y asignación de roles (`usuarios.jsp`).
- **COORDINACIÓN** — Panel de coordinación, aprobación de trámites e informes (`coordinacion.jsp`, `tramites.jsp`, `informes.jsp`).
- **DIRECTOR** — Publica ideas, dirige anteproyectos y registra calificaciones.
- **EVALUADOR** — Evalúa anteproyectos y registra observaciones/calificación.
- **ESTUDIANTE** — Selecciona ideas, crea y envía su anteproyecto, entrega el documento final y consulta su sustentación.

### Módulos principales

| Página | Descripción |
|---|---|
| `login.jsp` / `logout.jsp` | Autenticación y cierre de sesión |
| `home.jsp` | Panel inicial según el rol |
| `usuarios.jsp` | Administración de usuarios |
| `ideas.jsp` | Banco de ideas de trabajo de grado |
| `anteproyectos.jsp` | Listado y seguimiento de anteproyectos |
| `anteproyecto_form.jsp` | Registro/edición del anteproyecto |
| `anteproyecto_ver.jsp` | Detalle, revisión y calificación |
| `entrega_final.jsp` | Entrega del documento final |
| `sustentacion.jsp` | Programación y resultado de la sustentación |
| `calendario.jsp` | Calendario académico |
| `formatos.jsp` | Formatos oficiales de grado |
| `tramites.jsp` | Retiro, prórroga y beneficios |
| `notificaciones.jsp` | Notificaciones del proceso |
| `informes.jsp` | Reportes e informes |
| `coordinacion.jsp` | Panel de coordinación |

---

## Flujo del anteproyecto

```
BORRADOR → ENVIADO → APROBADO_DIRECTOR → APROBADO_EVALUADOR
        → ENTREGA_DOCUMENTO_FINAL → REVISIÓN_FINAL → SUSTENTACIÓN → FINALIZADO
```

---

## Estructura del proyecto

```
parcia_2jstl/
├── README.md              # Documentación
├── DEPLOY_RENDER.md       # Guía de despliegue en Render
├── Dockerfile             # Imagen Tomcat 9 + WAR (Render)
├── render.yaml            # Blueprint de despliegue en Render
├── .dockerignore
├── .gitignore
└── tguts/
    ├── pom.xml            # Configuración Maven (WAR)
    ├── sql/
    │   ├── db_tgd_uts.sql        # Script de base de datos + datos de prueba
    │   └── migracion_seguridad.sql  # Actualiza bases existentes (opcional)
    └── src/
        ├── main/java/
        │   └── edu/uts/PoolInicializador.java   # Pool de conexiones (HikariCP)
        └── main/webapp/
            ├── *.jsp                # Páginas del sistema
            ├── common/              # config, seguridad (PBKDF2), CSRF, guardas
            ├── css/style.css        # Estilos
            ├── img/                 # Imágenes
            ├── formatos/            # Formatos oficiales
            └── WEB-INF/
                ├── web.xml
                └── META-INF/context.xml   # Cookie SameSite=Lax
```
> Las dependencias `.jar` NO se versionan: el WAR las empaqueta Maven desde `pom.xml`.
```

---

## Base de datos

Tablas principales en `db_tgd_uts`:

- `usuarios` — cuentas y roles (`ADMIN`, `COORDINACION`, `DIRECTOR`, `EVALUADOR`, `ESTUDIANTE`)
- `ideas` — banco de ideas publicadas por docentes
- `anteproyectos` — idea, director, evaluador, estado y calificaciones
- `entrega_final` — documento final del trabajo de grado
- `sustentacion` — fecha, lugar y resultado de la defensa
- `calificaciones` — historial de calificaciones
- `notificaciones` — eventos del proceso
- `calendario` — calendario académico
- `formatos` — formatos de grado (FDC-124, FDC-125)
- `tramites` — retiro, prórroga y beneficios

---

## Seguridad

Todo la lógica de seguridad vive en **archivos JSP/JSTL** (`common/seguridad.jsp`,
`common/verify_csrf.jsp`) y configuración declarativa (`web.xml`, `META-INF/context.xml`):

- **Contraseñas:** PBKDF2-HMAC-SHA256 (`pgHash`) con sal aleatoria por usuario y
  120 000 iteraciones (configurable con la variable de entorno `PBKDF2_ITERATIONS`).
  Los hashes SHA-256 heredados se migran automáticamente al primer login
  (`pgNecesitaMigrar` en `common/seguridad.jsp`).
- **Sesiones:** rotación del identificador al iniciar sesión (`login.jsp`), invalidación
  al cerrar (`logout.jsp`), timeout de 30 min, cookie `HttpOnly`, `SameSite=Lax` y
  `tracking-mode=COOKIE` (`web.xml` + `context.xml`).
- **CSRF:** token estable por sesión en `common/csrf.jsp`; `common/verify_csrf.jsp`
  valida toda petición POST (funciona también con formularios `multipart`, usa el Map
  `campos` que prepara `common/config.jsp`).
- **Autorización por operación:** guarda de sesión (`common/guard.jsp`), guardas de rol,
  de **propiedad** (el anteproyecto pertenece al usuario) y de **estado** en cada UPDATE
  (`AND estado = '...'` / `IN (...)`) para impedir transiciones ilegales o reenvíos.
- **Documentos híbridos (enlace o archivo):** el archivo se valida (extensión, tipo real
  por *magic bytes*, máximo 20 MB), se almacena con nombre UUID **fuera** del webapp
  (directorio `uploadDir/`) y se descarga a través de `descargar.jsp`, que verifica
  sesión, rol y propiedad, y exige una ruta canónica dentro del directorio.
- **Transacciones:** las operaciones compuestas (cambio de estado + notificación) se
  agrupan con `<sql:transaction>`.
- **Base de datos:** índices en estados/notificaciones y `UNIQUE` en entregas/sustentación;
  columnas `password VARCHAR(255)`.

### Migrar una base existente

Si ya tenías creada la base con el esquema anterior (hashes SHA-256, sin índices),
ejecuta una sola vez:

```bash
mysql -uroot < tguts/sql/migracion_seguridad.sql
```

Ese script amplía la columna `password`, crea los índices/`UNIQUE` y actualiza los hashes
de los usuarios de prueba. No elimina datos.

---

## Despliegue en la nube (Render)

> **Vercel no es compatible con este proyecto**: Vercel solo hospeda sitios estáticos y funciones *serverless* (Node/Python/Go/Ruby); no ejecuta Java, Tomcat ni JSP. El despliegue se hace en **Render** (Docker + Tomcat 9) con una base de datos **MySQL externa en Clever Cloud**.

El repositorio ya incluye todo lo necesario:

| Archivo | Para qué sirve |
|---|---|
| `Dockerfile` | Compila el WAR con Maven y lo sirve con **Tomcat 9**. |
| `.dockerignore` | Excluye `target/`, `.git`, etc. del build. |
| `render.yaml` | Infraestructura como código (Web Service + variables de entorno). |
| `common/config.jsp` | Lee la conexión desde variables de entorno (o XAMPP por defecto). |

### Pasos

1. Subir el proyecto a GitHub:
   ```bash
   git add .
   git commit -m "Deploy en Render"
   git push
   ```
2. En Render: **New > Blueprint** y conectar el repositorio (detecta `render.yaml`).
3. Cuando Render lo pida, pega el valor de `DB_PASSWORD` (no se guarda en el repositorio por seguridad).
4. Render compila la imagen con el `Dockerfile` y publica la app.

URL pública resultante: `https://tguts-xxxx.onrender.com`.

La base de datos ya está creada e inicializada en Clever Cloud (tablas + datos de prueba).

### Variables de entorno

| Variable | Valor |
|---|---|
| `PORT` | `8080` (puerto de Tomcat que espera Render) |
| `DB_HOST` | `bpdhyrbabuc6fghivcj7-mysql.services.clever-cloud.com` |
| `DB_PORT` | `3306` |
| `DB_NAME` | `bpdhyrbabuc6fghivcj7` |
| `DB_USER` | `urgnhehtkdhpmazp` |
| `DB_PASSWORD` | *(secreto de Clever Cloud; se configura en Render)* |

**Notas de costo:** todo queda en plan gratuito (Web Service `free` en Render + MySQL addon gratuito de Clever Cloud). El Web Service se duerme tras ~15 min sin tráfico y tarda ~30–60 s en despertar.

Guía detallada: [`DEPLOY_RENDER.md`](DEPLOY_RENDER.md).

---

## Notas

- Las credenciales de BD se leen de variables de entorno (`DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`) en `src/main/java/edu/uts/PoolInicializador.java`; sin ellas usa XAMPP (`localhost`, `root`, sin contraseña). `common/config.jsp` apunta a ese pool con `dataSource="${applicationScope.ds}"`.
- El envío real de correos (SMTP) está pendiente; por ahora las notificaciones se registran en la base de datos.
- Los documentos subidos se guardan en `catalina.base/uploadDir/` (fuera del WAR), por lo que **no se conservan** si se borra el contenedor o el disco efímero de Render. Usa enlaces externos para documentos que deban perdurar, o adjunta un volumen.

---

## Pruebas end-to-end con Docker (local)

```bash
# 1) Imagen de MySQL con el esquema
docker network create tguts_net
docker run -d --name tguts_mysql --network tguts_net \
  -e MYSQL_ROOT_PASSWORD=rootpw \
  -v "%CD%\tguts\sql\db_tgd_uts.sql:/docker-entrypoint-initdb.d/01.sql:ro" \
  mysql:8

# 2) Compilar y desplegar Tomcat 9
cd tguts && mvn -B clean package
docker run -d --name tguts_tomcat --network tguts_net -p 18080:8080 \
  -e DB_HOST=tguts_mysql -e DB_PORT=3306 -e DB_NAME=db_tgd_uts \
  -e DB_USER=root -e DB_PASSWORD=rootpw \
  -v "%CD%\target\tguts.war:/usr/local/tomcat/webapps/ROOT.war:ro" \
  tomcat:9.0-jdk17-temurin

# 3) Abrir
#    http://localhost:18080/
```

Verificado de punta a punta: login, rotación de sesión, CSRF (POST sin token → 403),
selección de idea, subida de documento (multipart) y descarga protegida, calificación
(incluida la validación de valores no numéricos/fuera de rango), aprobaciones,
entrega final, sustentación y cierre del flujo hasta `FINALIZADO`.
