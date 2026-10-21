# Registro de pruebas reales (E2E)

Fecha de ejecución: **21/10/2026**
Entorno: **Tomcat 8.5.96 + MySQL 8.0 (XAMPP)**, WAR compilado con **Maven (JDK 21, target 17)**.
Script de prueba: `pruebas/e2e_local.py` (Python 3, librería estándar, sin dependencias externas).
Base de datos: `db_tgd_uts` con script `tguts/sql/db_tgd_uts.sql` (datos de demostración).

---

## Resumen de cambios aplicados (validados en código y en ejecución)

| Cambio | Archivo(s) | Estado |
|---|---|---|
| Corrección de eliminación de calificaciones: `sql:transaction` de director y evaluador ahora incluyen `dataSource="${ds}"` | `tguts/src/main/webapp/anteproyecto_ver.jsp` | **APROBADO (código + E2E)** |
| Acceso a entrega final: estudiante ya no es redirigido si la entrega existe (ESTADO ENTREGADO/EN_REVISION/OBSERVADO/APROBADO); enlace visible en `anteproyecto_ver.jsp` para estado `ENTREGA_DOCUMENTO_FINAL` | `tguts/src/main/webapp/entrega_final.jsp`, `anteproyecto_ver.jsp` | **APROBADO (código + E2E)** |
| Coordinación puede asignar/cambiar director en **cualquier estado** (incluido APROBADO) — alineado con diapositiva del profesor | `tguts/src/main/webapp/coordinacion.jsp` | **APROBADO (código + E2E)** |
| Formularios de documentos: solo URL `http(s)` (se elimina subida de archivos) | `anteproyecto_form.jsp`, `entrega_final.jsp` | **APROBADO (código + E2E)** |
| Formatos: rutas locales en BD (p. ej. `formatos/FDC-124-Anteproyecto.pdf`) se convierten en enlaces clicables vía `c:url` | `tguts/src/main/webapp/formatos.jsp` | **APROBADO (código + E2E)** |
| Banco de ideas: formulario ofrece docentes con rol `DIRECTOR` o `EVALUADOR` (validado en servidor); edición persiste `docente_id` | `tguts/src/main/webapp/ideas.jsp` | **APROBADO (código + E2E)** |
| Validación servidor de director (rol `DIRECTOR` + `activo=1`) en formulario de estudiante | `tguts/src/main/webapp/anteproyecto_form.jsp` | **APROBADO (código + E2E)** |
| Eliminación de usuarios bloquea si el usuario ha revisado una entrega final (`entrega_final.revisado_por`) | `tguts/src/main/webapp/usuarios.jsp` | **APROBADO (código + E2E)** |
| Nombre institucional unificado: **Universitaria Tecnológica de Santander (UTS)** | `login.jsp`, `common/footer.jsp`, `README.md` | **APROBADO** |
| Datos de prueba marcados como **demostración** (no oficiales) en UI, SQL y README | `login.jsp`, `formatos.jsp`, `calendario.jsp`, `db_tgd_uts.sql`, `README.md` | **APROBADO** |

---

## Resultados E2E (19/19 APROBADOS)

| # | Caso | Resultado | Evidencia observada |
|---|---|---|---|
| 1 | Login 5 cuentas demo + rechazo credenciales inválidas | **APROBADO** | Todas redirigen a `home.jsp`; credencial mala queda en `login.jsp` con aviso |
| 2 | Formatos: ruta local `formatos/FDC-124-Anteproyecto.pdf` se renderiza como enlace | **APROBADO** | HTML contiene `href="/formatos/FDC-124-Anteproyecto.pdf"`; PDF devuelve HTTP 200 |
| 3 | Ideas: formulario ofrece docentes Director/Evaluador (no Coordinación) | **APROBADO** | `<option value="4">` (evaluador) presente; `value="2"` (coord) ausente |
| 4 | Ideas: edición actualiza `docente_id` en BD | **APROBADO** | Al crear: `docente_id=4`; al editar a director: `docente_id=3` |
| 5 | Estudiante: formulario rechaza director sin rol/activo (coord) | **APROBADO** | Estado permanece `BORRADOR`; mensaje "El director seleccionado no es un Director válido o está inactivo" |
| 6 | Estudiante: envío anteproyecto con director válido | **APROBADO** | Estado cambia a `ENVIADO` |
| 7 | Director: guarda calificación | **APROBADO** | `calificacion_director=4.5`, 1 fila en `calificaciones` |
| 8 | Director: **ELIMINA calificación** (transacción con datasource) | **APROBADO** | HTTP 200; `calificacion_director=NULL`; 0 filas en historial |
| 9 | Director: aprueba anteproyecto | **APROBADO** | Estado = `APROBADO_DIRECTOR` |
| 10 | Evaluador: elimina calificación (transacción con datasource) | **APROBADO** | HTTP 200; `calificacion_evaluador=NULL` |
| 11 | Evaluador: aprueba anteproyecto | **APROBADO** | Estado = `APROBADO_EVALUADOR` |
| 12 | Coordinación: asigna **nuevo director** a anteproyecto ya `APROBADO_EVALUADOR` | **APROBADO** | `director_id` actualizado a nuevo director (id 7) con estado previo `APROBADO_EVALUADOR` |
| 13 | Entrega final: enlace visible en `anteproyecto_ver.jsp` tras `APROBADO_EVALUADOR` | **APROBADO** | Enlace a `entrega_final.jsp?id=1` presente |
| 14 | Entrega final: estudiante entrega por URL → **no es redirigido**; puede consultar su entrega | **APROBADO** | Estado `ENTREGA_DOCUMENTO_FINAL`; GET a `entrega_final.jsp` devuelve 200 y muestra "Documento entregado" |
| 15 | Coordinación (coord2) revisa entrega → `OBSERVADO` | **APROBADO** | `entrega_final.estado=OBSERVADO`; `revisado_por=8` (coord2) |
| 16 | Usuario: **no se elimina** coordinación que revisó entrega final | **APROBADO** | `DELETE` bloqueado; usuario permanece en BD; mensaje "No se puede eliminar" |
| 17 | Entrega final: estudiante ve formulario **Corregir y reenviar** tras `OBSERVADO` | **APROBADO** | HTML contiene "Corregir y reenviar documento" |
| 18 | Entrega final: estudiante corrige y reenvía → `ENTREGADO` | **APROBADO** | `entrega_final.estado=ENTREGADO` |
| 19 | PDF base accesible directamente | **APROBADO** | `GET /formatos/FDC-124-Anteproyecto.pdf` → HTTP 200 |

---

## Detalles técnicos de los bugs corregidos

### 1. Eliminación de calificaciones sin datasource
**Síntoma:** `<sql:transaction>` sin `dataSource` → `javax.servlet.jsp.JspException: No DataSource specified for transaction`.
**Corrección:** Se añadió `dataSource="${ds}"` a ambos bloques (director y evaluador).

### 2. Acceso a entrega final perdido tras envío
**Síntoma:** Guarda `rol eq 'ESTUDIANTE' && not ((ant.estado eq 'APROBADO_EVALUADOR' && empty entrega) || ...)` redirigía al estudiante a `anteproyectos.jsp` si el estado no era exactamente `OBSERVADO`.
**Corrección:** Nueva guarda `rol eq 'ESTUDIANTE' && empty entrega && ant.estado ne 'APROBADO_EVALUADOR'`. El estudiante **siempre** ve su entrega si existe; solo ve el formulario de primera entrega en `APROBADO_EVALUADOR` sin entrega previa.

### 3. Asignación de director bloqueada tras aprobación
**Síntoma:** `director_id` solo editable en `BORRADOR`/`RECHAZADO`/`ENVIADO`; UPDATE con `CASE` preservaba el director en estados posteriores.
**Corrección:** Se eliminó la guarda y el `CASE`; `director_id = NULLIF(?, '')` siempre. UI: select siempre habilitado; nota informativa.

### 4. Formatos con rutas locales aparecían como texto
**Síntoma:** BD inserta `formatos/FDC-124-Anteproyecto.pdf`; JSP solo convertía en enlace si `startsWith http/https`.
**Corrección:** Nueva rama `<c:when test="${not fn:startsWith(f.url, '/') && not fn:contains(f.url, '..')}">` con `<c:url value="/${f.url}"/>`. Validación de entrada acepta URL `http(s)` **o** ruta relativa segura.

### 5. Banco de ideas: roles incoherentes
**Síntoma:** Select en formulario `WHERE rol IN ('DIRECTOR', 'COORDINACION')`; validación servidor `IN ('DIRECTOR', 'EVALUADOR')`. Al editar, `docente_id` no se actualizaba.
**Corrección:** Select alineado a `('DIRECTOR', 'EVALUADOR')`. UPDATE de edición ramificado: admin/coord actualizan `docente_id`; director conserva autoría.

### 6. Validación de director solo en cliente
**Síntoma:** `<select>` filtra `rol='DIRECTOR' AND activo=1`, pero POST no revalidaba.
**Corrección:** Consulta servidor `SELECT 1 FROM usuarios WHERE id=? AND rol='DIRECTOR' AND activo=1` antes de aceptar.

### 7. Eliminación de usuarios omite revisor de entrega final
**Síntoma:** `qDep` sumaba anteproyectos/ideas/calificaciones/tramites, pero no `entrega_final.revisado_por`.
**Corrección:** Se añadió `+ (SELECT COUNT(*) FROM entrega_final WHERE revisado_por = ?)` con 8.º parámetro.

---

## Entorno de prueba reproducible

```bash
# 1) Red y MySQL con esquema
docker network create tguts_net
docker run -d --name tguts-mysql --network tguts_net \
  -e MYSQL_ROOT_PASSWORD=rootpw -e MYSQL_DATABASE=db_tgd_uts \
  -v "%CD%\tguts\sql\db_tgd_uts.sql:/docker-entrypoint-initdb.d/01.sql:ro" \
  mysql:8.0

# 2) Compilar WAR (requiere Maven + JDK 17)
cd tguts && mvn -B clean package

# 3) Tomcat 9 montando el WAR como ROOT
docker run -d --name tguts-tomcat --network tguts_net -p 18080:8080 \
  -e DB_HOST=tguts-mysql -e DB_PORT=3306 -e DB_NAME=db_tgd_uts \
  -e DB_USER=root -e DB_PASSWORD=rootpw \
  -v "%CD%\target\tguts.war:/usr/local/tomcat/webapps/ROOT.war:ro" \
  tomcat:9.0-jdk17-temurin

# 4) Ejecutar pruebas E2E (requiere Python 3)
python ../pruebas/e2e_tguts.py
```

**Nota:** El script `pruebas/e2e_tguts.py` usa solo la librería estándar de Python (`urllib`, `http.cookiejar`, `subprocess`); no requiere `requests` ni `beautifulsoup4`.

---

## Limitaciones y decisiones documentadas

- **Subida de archivos:** se retiró de los formularios de anteproyecto y entrega final (se acordó "dejar solo URL y documentar"). La infraestructura (`common/seguridad.jsp` → `pgCampos`, `archivo_subido`, `pgGuardar` y `descargar.jsp`) se conserva para compatibilidad con registros antiguos.
- **Calendario y formatos iniciales:** son **datos de demostración**, no documentos oficiales de la institución. La interfaz muestra avisos informativos y el SQL tiene comentarios explícitos.
- **Nombre institucional:** se corrigió "Universidad UTS" → "Universitaria Tecnológica de Santander (UTS)" en login, footer y README, acorde con el OCR de los logos (`images.png`, `fondologin.jpg`).

---

## Veredicto

**19/19 casos E2E aprobados** con evidencia real (códigos HTTP, URLs finales, consultas a BD y fragmentos de HTML). Todos los 10 pendientes resueltos y validados. Cambios listos para `git commit`/`push` y despliegue en Render.