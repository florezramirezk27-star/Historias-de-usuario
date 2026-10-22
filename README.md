# Historias-de-usuario

**Sistema de Trabajos de Grado — Universitaria Tecnológica de Santander (UTS)** — Aplicación web desarrollada en **JSP + JSTL** (Maven, empaquetado WAR) sobre una base de datos **MySQL/MariaDB (XAMPP)**.

> El nombre institucional de los logos (`img/images.png`, `img/fondologin.jpg`) es
> **Universitaria Tecnológica de Santander**. El documento y la interfaz usan ese mismo
> nombre (abreviado **UTS**) para mantener la consistencia.

El sistema gestiona todo el proceso de un trabajo de grado: desde la publicación de ideas por parte de los docentes, el registro y aprobación del anteproyecto, la asignación de director y evaluador, la entrega del documento final, la sustentación y las notificaciones del proceso, además de trámites (retiro, prórroga y beneficios), calendario académico, formatos e informes.

> Proyecto con la lógica 100 % en **JSP + JSTL** (core, fmt, functions y sql). La única clase
> **Java** es `PoolInicializador`, que crea el pool de conexiones JDBC (HikariCP).

---

## Tecnologías

| Componente | Detalle |
|---|---|
| Lenguaje de vistas | JSP + JSTL 1.2 |
| Empaquetado | Maven (WAR) |
| Servidor | Apache Tomcat 9 (Java EE `javax`); **verificado también en Tomcat 8.5.96** de XAMPP |
| Base de datos | MySQL / MariaDB vía XAMPP (**verificado en MariaDB 10.4.32**) |
| Conexión | JSTL `<sql:setDataSource>` + pool **HikariCP** + MySQL Connector/J 8.3 |
| Formularios | Apache Commons FileUpload 1.5 / Commons IO 2.15 (parseo de `campos`; los documentos se registran por **URL**, no se suben archivos) |
| Seguridad | PBKDF2-HMAC-SHA256 (JDK nativo), token CSRF, sesiones con rotación, guardas por rol |

---

## Requisitos

- **JDK 17 o superior** (el `pom.xml` compila con `maven.compiler.release=17`; la build verificada se hizo con **JDK 21**)
- Apache Maven 3.6+
- Apache Tomcat 9 (o Tomcat 8.5 de XAMPP, que es el entorno en el que se ejecutaron las pruebas)
- XAMPP (MySQL / MariaDB) iniciado

---

## Puesta en marcha

1. **Crear la base de datos** (una sola vez):

   ```bash
   mysql -uroot < tguts/sql/db_tgd_uts.sql
   ```

   O importar `tguts/sql/db_tgd_uts.sql` desde phpMyAdmin. La base se llama `db_tgd_uts` e incluye **datos de demostración** (usuarios, ideas, calendario y formatos de ejemplo; no son datos oficiales).

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

### Entorno verificado en las pruebas

| Componente | Versión / ruta |
|---|---|
| Servlet container | **Apache Tomcat 8.5.96** — `C:\xampp\tomcat` |
| Base de datos | **MariaDB 10.4.32** — `C:\xampp\mysql\bin\mysql.exe` (root, sin contraseña), puerto 3306 |
| Aplicación | `http://localhost:8080/tguts/` (contexto WAR `tguts`) |
| Build | Maven con JDK 21 → `maven.compiler.release=17` |

---

## Usuarios de demostración

> Estas cuentas son **datos de demostración**, no usuarios reales de la institución.

| Rol | Correo | Contraseña |
|---|---|---|
| Administrador | `admin@uts.edu.co` | `admin123` |
| Coordinación | `coord@uts.edu.co` | `coord123` |
| Director | `director@uts.edu.co` | `director123` |
| Evaluador | `evaluador@uts.edu.co` | `evaluador123` |
| Estudiante | `estudiante@uts.edu.co` | `estudiante123` |
| Estudiante (2.º) | `estudiante2@uts.edu.co` | `estudiante123` |

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
| `formatos.jsp` | Formatos de grado (plantillas base de demostración) |
| `tramites.jsp` | Retiro, prórroga y beneficios |
| `notificaciones.jsp` | Notificaciones del proceso |
| `informes.jsp` | Reportes e informes |
| `coordinacion.jsp` | Panel de coordinación |

### Catálogo de requisitos funcionales (RF-01 … RF-43)

| RF | Requisito | RF | Requisito |
|---|---|---|---|
| RF-01 | Autenticación de usuarios | RF-23 | Aprobar/rechazar el anteproyecto (evaluador) |
| RF-02 | Validación de credenciales y sesión | RF-24 | Notificar la evaluación al estudiante y a la coordinación |
| RF-03 | Panel inicial y menú según el rol | RF-25 | Gestión (CRUD) de ideas por administración/coordinación |
| RF-04 | Crear usuarios | RF-26 | Asignar director y evaluador (coordinación) |
| RF-05 | Consultar la ficha de un usuario | RF-27 | Buscar estudiantes por nombre, código o correo |
| RF-06 | Listar los usuarios registrados | RF-28 | Ficha del estudiante y de su proyecto |
| RF-07 | Editar usuarios | RF-29 | Informe de estado por estudiante |
| RF-08 | Eliminar usuarios (con control de dependencias) | RF-30 | Informe de estado por director |
| RF-09 | Publicar una idea de trabajo de grado | RF-31 | Informe de estado por evaluador |
| RF-10 | Consultar el banco de ideas | RF-32 | Calendario académico (consulta y CRUD) |
| RF-11 | Seleccionar una idea | RF-33 | Formatos de grado (consulta y CRUD) |
| RF-12 | Un solo anteproyecto por estudiante | RF-34 | Consulta del estado y de la sustentación por el estudiante |
| RF-13 | Crear el anteproyecto al seleccionar la idea | RF-35 | Historial de calificaciones |
| RF-14 | Registrar y editar la información del anteproyecto | RF-36 | Entrega del documento final por URL |
| RF-15 | Consultar el anteproyecto propio | RF-37 | Notificaciones del proceso |
| RF-16 | Enviar el anteproyecto al director | RF-38 | Solicitud de retiro del proyecto |
| RF-17 | Ver los anteproyectos asignados como director | RF-39 | Solicitud de prórroga |
| RF-18 | Consultar el detalle del anteproyecto | RF-40 | Solicitud de beneficio |
| RF-19 | Calificar el anteproyecto (director) | RF-41 | Revisión del documento final (observar / revisar / aprobar) |
| RF-20 | Aprobar/rechazar el anteproyecto (director) | RF-42 | Programar la sustentación |
| RF-21 | Ver los anteproyectos aprobados (evaluador) | RF-43 | Registrar el resultado de la sustentación |
| RF-22 | Calificar el anteproyecto (evaluador) | RNF-02 | Control de acceso por rol (menú y guardas de página) |
| | | RNF-03 | Control de propiedad (cada rol solo ve sus datos) |

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
├── README.md              # Documentación e historias de usuario
├── DOCUMENTACION_TECNICA.md  # Arquitectura, esquema BD, seguridad y decisiones
├── GUION.md               # Guion de demostración paso a paso (todo en tablas)
├── TEST_RESULTS.md        # Registro histórico de las pruebas E2E
├── DEPLOY_RENDER.md       # Guía de despliegue en Render
├── Dockerfile             # Imagen Tomcat 9 + WAR (Render)
├── render.yaml            # Blueprint de despliegue en Render
├── .dockerignore
├── .gitignore
├── docs/
│   ├── generar_informe.py # Genera el documento final consolidado (.docx)
│   ├── verificar_informe.py
│   ├── Sistema_Trabajos_de_Grado_UTS.docx  # Documento final (42 páginas)
│   └── Sistema_Trabajos_de_Grado_UTS.pdf   # Versión PDF del documento final
├── Sistema_Trabajos_de_Grado_UTS.zip       # Paquete con el documento y las fuentes
└── tguts/
    ├── pom.xml            # Configuración Maven (WAR)
    ├── sql/
    │   ├── db_tgd_uts.sql        # Script de base de datos + datos de prueba
    │   ├── migracion_seguridad.sql  # Actualiza bases existentes (opcional)
    │   └── migracion_reprobacion.sql # Agrega el estado REPROBADO al ENUM (opcional)
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
- **Documentos por enlace (URL):** el anteproyecto y el documento final se registran
  mediante una **URL** (`http://`/`https://`); no se suben archivos. `descargar.jsp` se
  conserva únicamente para compatibilidad con registros antiguos que apunten a un archivo.
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

Para bases creadas antes de la función de **reprobación definitiva** del evaluador,
ejecuta también (una sola vez):

```bash
mysql -uroot < tguts/sql/migracion_reprobacion.sql
```

Agrega el valor `REPROBADO` al `ENUM` de estado de `anteproyectos`. No elimina datos.

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

## Documento final del proyecto

| Archivo | Contenido |
|---|---|
| `docs/Sistema_Trabajos_de_Grado_UTS.docx` | Documento final consolidado (42 páginas): introducción, objetivos, marco referencial, catálogo RF-01…RF-43 y RNF-01…RNF-10, reglas de negocio, 28 historias de usuario, modelo de datos, arquitectura, seguridad, plan de trabajo, guion de demostración, registro de las 99 pruebas, despliegue, conclusiones y anexos |
| `docs/Sistema_Trabajos_de_Grado_UTS.pdf` | Versión PDF del mismo documento (índice actualizado con números de página) |
| `Sistema_Trabajos_de_Grado_UTS.zip` | Paquete con el documento (.docx y .pdf) y las fuentes del proyecto (documentación y SQL) |
| `docs/generar_informe.py` | Script que regenera el documento a partir de `README.md`, `GUION.md`, `TEST_RESULTS.md` y `DOCUMENTACION_TECNICA.md` |

```bash
python docs\generar_informe.py     # regenera el .docx y el .zip
```

---

## Notas

- Las credenciales de BD se leen de variables de entorno (`DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`) en `src/main/java/edu/uts/PoolInicializador.java`; sin ellas usa XAMPP (`localhost`, `root`, sin contraseña). `common/config.jsp` apunta a ese pool con `dataSource="${applicationScope.ds}"`.
- El envío real de correos (SMTP) está pendiente; por ahora las notificaciones se registran en la base de datos.
- Los documentos del anteproyecto y del trabajo de grado se registran como **enlaces (URL)**, no como archivos; por eso no dependen del disco del servidor. La subida de archivos se retiró de los formularios y se acordó documentar esta decisión con el profesor.
- Los contenidos iniciales (usuarios, ideas, calendario y formatos) son **datos de demostración**: se marcan en la interfaz y deben reemplazarse por los oficiales de la institución.
- La **revisión del documento final** solo está disponible en los estados `ENTREGA_DOCUMENTO_FINAL` y `REVISIÓN_FINAL`; en `SUSTENTACIÓN` y `FINALIZADO` el documento está cerrado y la revisión queda bloqueada. Observar el documento desde `REVISIÓN_FINAL` devuelve el trabajo a `ENTREGA_DOCUMENTO_FINAL` para que el estudiante pueda corregirlo.
- El **calendario** y los **formatos** admiten alta, consulta, edición y borrado por parte de administración y coordinación; todos los usuarios autenticados pueden consultarlos.

---

## Pruebas end-to-end (histórico)

Durante el desarrollo se verificó el sistema con una suite E2E de 99 casos (Python, librería estándar) ejecutada contra el entorno XAMPP local: **99/99 APROBADOS (66,2 s) el 22/10/2026**. El detalle caso por caso se conserva en [`TEST_RESULTS.md`](TEST_RESULTS.md).

> Los scripts de la suite y la salida completa de la ejecución se retiraron del repositorio; este apartado queda como registro histórico de la verificación.
