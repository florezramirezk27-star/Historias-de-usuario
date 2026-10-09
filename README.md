# Historias-de-usuario

**Sistema de Trabajos de Grado UTS** — Aplicación web desarrollada en **JSP + JSTL** (Maven, empaquetado WAR) sobre una base de datos **MySQL/MariaDB (XAMPP)**.

El sistema gestiona todo el proceso de un trabajo de grado: desde la publicación de ideas por parte de los docentes, el registro y aprobación del anteproyecto, la asignación de director y evaluador, la entrega del documento final, la sustentación y las notificaciones del proceso, además de trámites (retiro, prórroga y beneficios), calendario académico, formatos e informes.

> Proyecto **sin clases `.java`**: toda la lógica se implementa con JSP y la librería **JSTL** (core, fmt, functions y sql).

---

## Tecnologías

| Componente | Detalle |
|---|---|
| Lenguaje de vistas | JSP + JSTL 1.2 |
| Empaquetado | Maven (WAR) |
| Servidor | Apache Tomcat 9 (Java EE `javax`) |
| Base de datos | MySQL / MariaDB vía XAMPP |
| Conexión | JSTL `<sql:setDataSource>` + MySQL Connector/J 8.3 |
| Subida de archivos | Apache Commons FileUpload 1.5 / Commons IO 2.15 |
| Seguridad | Hash SHA-256 con salt + token CSRF |

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

Las contraseñas se almacenan como `SHA-256(password + '|tguts-salt')`.

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
├── README.md
├── .gitignore
└── tguts/
    ├── pom.xml                  # Configuración Maven (WAR)
    ├── sql/
    │   └── db_tgd_uts.sql       # Script de base de datos + datos de prueba
    └── src/main/webapp/
        ├── *.jsp                # Páginas del sistema
        ├── common/              # Configuración, cabecera, menú, CSRF, guardas
        ├── css/style.css        # Estilos
        ├── img/                 # Imágenes
        ├── formatos/            # Formatos oficiales
        └── WEB-INF/
            ├── web.xml
            └── lib/             # Dependencias .jar
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

- Contraseñas con **SHA-256 + salt** (`|tguts-salt`).
- **Token CSRF** en formularios POST (`common/csrf.jsp`, `common/verify_csrf.jsp`).
- Control de acceso por rol mediante guardas (`common/guard.jsp`).

---

## Notas

- Los datos de conexión se configuran en `tguts/src/main/webapp/common/config.jsp` (usuario `root`, sin contraseña, para XAMPP por defecto).
- El envío real de correos (SMTP) está pendiente; por ahora las notificaciones se registran en la base de datos.
