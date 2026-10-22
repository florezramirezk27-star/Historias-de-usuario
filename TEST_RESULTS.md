# Registro de pruebas reales (E2E)

**Resultado de la última ejecución real: 99/99 APROBADOS (66,2 s).**

> **Nota:** los scripts de la suite E2E y la salida completa de la ejecución se retiraron del repositorio; este documento se conserva como **registro histórico** de la verificación.

| Dato | Valor |
|---|---|
| Fecha de ejecución | **22/10/2026 09:49:39** |
| Aplicación probada | `http://localhost:8080/tguts` (contexto WAR `tguts`) |
| Servidor | **Apache Tomcat 8.5.96** (instalación de XAMPP en `C:\xampp\tomcat`) |
| Base de datos | **MariaDB 10.4.32 / MySQL** de XAMPP, puerto 3306, base `db_tgd_uts` (`tguts/sql/db_tgd_uts.sql`) |
| Compilación del WAR | **Maven** con **JDK 21**, `maven.compiler.release=17` → `tguts/target/tguts.war` |
| Script de pruebas | Suite E2E propia en Python 3 (solo librería estándar), hoy retirada del repositorio |
| Evidencia de la ejecución | Salida completa generada por la propia suite (archivo retirado del repositorio) |
| Integridad de los datos | El caso **O-01** comprueba que la base queda exactamente como estaba tras la suite |

> **Alcance de la evidencia:** todas las afirmaciones de este documento proceden de esa ejecución real contra el WAR desplegado. La vía **Docker / puerto 18080** se conserva como alternativa documentada, pero **no se ejecutó** (el daemon de Docker no estaba disponible en el equipo donde se generaron las pruebas).

---

## 1. Cambios aplicados y validados en código y en ejecución

| # | Cambio | Archivo(s) | Evidencia |
|---|---|---|---|
| 1 | Eliminación de calificaciones con datasource (`<sql:transaction dataSource="${ds}">`) para director y evaluador | `anteproyecto_ver.jsp` | E-02, H-02 |
| 2 | El estudiante conserva el acceso a su entrega final (ya no es redirigido) | `entrega_final.jsp`, `anteproyecto_ver.jsp` | J-03 |
| 3 | Coordinación puede asignar/cambiar director en cualquier estado (diapositiva del profesor) | `coordinacion.jsp` | G-03 |
| 4 | Documentos solo por URL `http(s)` (se retira la subida de archivos) | `anteproyecto_form.jsp`, `entrega_final.jsp` | D-06, J-01 |
| 5 | Formatos con ruta local convertidos en enlace relativo con `c:url` | `formatos.jsp` | L-01 |
| 6 | Banco de ideas: el docente debe ser `DIRECTOR` o `EVALUADOR` (validado en servidor) y la edición sí actualiza `docente_id` | `ideas.jsp` | C-03, C-04 |
| 7 | Validación de servidor del director (rol `DIRECTOR` + `activo=1`) | `anteproyecto_form.jsp` | D-05 |
| 8 | La eliminación de usuarios comprueba también `entrega_final.revisado_por` | `usuarios.jsp` | B-08 |
| 9 | Nombre institucional unificado: **Universitaria Tecnológica de Santander (UTS)** | `login.jsp`, `common/footer.jsp`, `README.md` | A-01 |
| 10 | Datos de prueba marcados como **demostración** (no oficiales) en interfaz, SQL y documentación | `login.jsp`, `formatos.jsp`, `calendario.jsp`, `db_tgd_uts.sql`, `README.md` | K-05, L-06 |
| 11 | **Revisión del documento final acotada por estado**: solo es posible en `ENTREGA_DOCUMENTO_FINAL` y `REVISIÓN_FINAL`; en `SUSTENTACIÓN`/`FINALIZADO` la revisión queda bloqueada y el formulario se oculta con aviso | `entrega_final.jsp` | J-12, J-13, J-16 |
| 12 | **Observar desde `REVISIÓN_FINAL` devuelve el trabajo a `ENTREGA_DOCUMENTO_FINAL`**, de modo que el estudiante siempre pueda corregir y reenviar | `entrega_final.jsp` | J-08, J-09, J-10 |
| 13 | **Salida HTML escapada en la URL de los formatos** (`fn:escapeXml`): una URL con comillas y `<script>` ya no rompe la página | `formatos.jsp` | L-05 |
| 14 | **Eliminación de formatos** (`accion=eliminar`) con botón y aviso de éxito | `formatos.jsp` | L-04 |
| 15 | **Edición y eliminación de eventos del calendario** (`accion=editar`, `accion=eliminar`) con formulario en modo edición y columna de acciones | `calendario.jsp` | K-02, K-03 |
| 16 | **Búsqueda de estudiantes por nombre, código o correo** en el panel de coordinación | `coordinacion.jsp` | F-01…F-04 |
| 17 | **Asignación de evaluador validada por estado** (solo tras la aprobación del director) y **director validado por rol** | `coordinacion.jsp` | G-04, G-05 |
| 18 | Rutas relativas de formato seguras: se rechaza cualquier ruta con `:` y se exige `formatos/...` o URL absoluta | `formatos.jsp` | L-01, L-03 |
| 19 | Suite E2E ampliada de 19 a **99 casos**, con aislamiento de datos (`e2e-<rol>@uts.edu.co`) y restauración final de la base | Suite E2E (Python, retirada del repositorio) | O-01 |

---

## 2. Resultados E2E (99/99 APROBADOS)

### Bloque A — Acceso, sesión y seguridad (A-01 … A-12)

| Caso | Descripción | Evidencia observada | Resultado |
|---|---|---|---|
| A-01 | Login: las 5 cuentas de demostración acceden al sistema | las 5 cuentas demo (admin, coordinacion, director, evaluador, estudiante) ingresaron a home.jsp | **APROBADO** |
| A-02 | Login: se rechaza una credencial inválida | rechazó la contraseña incorrecta y mostró el aviso en login.jsp | **APROBADO** |
| A-03 | Guard: sin sesión no se puede entrar a un módulo protegido | petición sin sesión redirigida a login.jsp (HTTP 200) | **APROBADO** |
| A-04 | CSRF: un POST sin token es rechazado | redirección a 403.jsp?error=csrf y ningún registro creado | **APROBADO** |
| A-05 | CSRF: un token inválido es rechazado | redirección a 403.jsp?error=csrf con token incorrecto | **APROBADO** |
| A-06 | Roles: el estudiante no entra a la gestión de usuarios | HTTP 200, redirección a 403.jsp | **APROBADO** |
| A-07 | Roles: el director no entra a los informes | HTTP 200, redirección a 403.jsp | **APROBADO** |
| A-08 | Roles: el evaluador no entra al banco de ideas | HTTP 200, redirección a 403.jsp | **APROBADO** |
| A-09 | Roles: la coordinación no entra a la gestión de usuarios | HTTP 200, redirección a 403.jsp | **APROBADO** |
| A-10 | Roles: el estudiante no entra al módulo de coordinación | HTTP 200, redirección a 403.jsp | **APROBADO** |
| A-11 | Sesión: cerrar sesión invalida el acceso | la sesión se cerró y la página protegida volvió a exigir login | **APROBADO** |
| A-12 | Menú: cada rol ve solo los módulos que le corresponden | el menú lateral se construye según el rol (RF-03 / RNF-02) | **APROBADO** |

### Bloque B — Administración de usuarios (B-01 … B-09)

| Caso | Descripción | Evidencia observada | Resultado |
|---|---|---|---|
| B-01 | Usuarios: el administrador crea un director | usuario creado por el administrador (id=7) | **APROBADO** |
| B-02 | Usuarios: la cuenta creada puede iniciar sesión | el usuario creado por el administrador inició sesión correctamente | **APROBADO** |
| B-03 | Usuarios: el administrador edita un usuario | nombre actualizado a "Estudiante E2E Dos Editado" conservando el código 900002 | **APROBADO** |
| B-04 | Usuarios: se rechaza un correo ya registrado | el correo duplicado fue rechazado con el aviso correspondiente | **APROBADO** |
| B-05 | Usuarios: se valida el largo mínimo de la contraseña | la contraseña de menos de 8 caracteres fue rechazada | **APROBADO** |
| B-06 | Usuarios: el estudiante exige código de matrícula | el estudiante sin código fue rechazado | **APROBADO** |
| B-07 | Usuarios: se elimina un usuario sin dependencias | usuario temporal creado y eliminado correctamente | **APROBADO** |
| B-08 | Usuarios: no se elimina a quien tiene datos asociados | el administrador no pudo eliminar a un estudiante con anteproyecto asociado | **APROBADO** |
| B-09 | Usuarios: no se puede eliminar la cuenta propia | el administrador no pudo eliminar su propia cuenta | **APROBADO** |

### Bloque C — Banco de ideas (C-01 … C-07)

| Caso | Descripción | Evidencia observada | Resultado |
|---|---|---|---|
| C-01 | Ideas: el director publica una idea a su nombre | la idea se registró con docente_id=7 (el director) | **APROBADO** |
| C-02 | Ideas: la administración publica indicando el docente | la administración publicó la idea asignando al docente id=9 | **APROBADO** |
| C-03 | Ideas: se valida que el docente sea Director o Evaluador | se rechazó asignar como docente a un usuario que no es Director/Evaluador | **APROBADO** |
| C-04 | Ideas: la administración edita la idea y cambia el docente | la idea se editó y cambió de docente (id=9 → id=7) | **APROBADO** |
| C-05 | Ideas: cerrar una idea la retira de la bolsa del estudiante | la idea quedó en estado CERRADA y dejó de ofrecerse a los estudiantes | **APROBADO** |
| C-06 | Ideas: la administración elimina una idea | la idea se eliminó del banco de ideas | **APROBADO** |
| C-07 | Ideas: el estudiante no puede publicar ideas | redirección a 403.jsp: el estudiante no publica ideas | **APROBADO** |

### Bloque D — Anteproyecto del estudiante (D-01 … D-10)

| Caso | Descripción | Evidencia observada | Resultado |
|---|---|---|---|
| D-01 | Anteproyecto: el estudiante selecciona una idea y se registra su anteproyecto | anteproyecto id=2 en BORRADOR; la idea pasó a SELECCIONADA | **APROBADO** |
| D-02 | Anteproyecto: no se puede seleccionar una segunda idea | la segunda selección se rechazó con el aviso "Ya tienes un anteproyecto registrado" | **APROBADO** |
| D-03 | Anteproyecto: no se puede seleccionar una idea cerrada | la selección de una idea cerrada fue rechazada | **APROBADO** |
| D-04 | Anteproyecto: el estudiante completa y envía su anteproyecto | el anteproyecto pasó a ENVIADO con director id=7 y enlace del documento | **APROBADO** |
| D-05 | Anteproyecto: el director debe tener rol DIRECTOR activo | el servidor rechazó a la coordinación como director (estado BORRADOR) | **APROBADO** |
| D-06 | Anteproyecto: la URL del documento debe ser http o https | se rechazó una URL de documento que no es http/https | **APROBADO** |
| D-07 | Anteproyecto: se elimina un borrador y la idea vuelve a la bolsa | el anteproyecto en BORRADOR se eliminó y la idea quedó disponible otra vez | **APROBADO** |
| D-08 | Anteproyecto: un anteproyecto enviado no se puede eliminar | un anteproyecto ya enviado no se puede eliminar | **APROBADO** |
| D-09 | Anteproyecto: un estudiante no ve el anteproyecto de otro | HTTP 200, redirección a 403.jsp | **APROBADO** |
| D-10 | Anteproyecto: el estudiante envía el anteproyecto del flujo B | anteproyecto id=3 enviado por el estudiante de prueba | **APROBADO** |

### Bloque E — Dirección del anteproyecto (E-01 … E-07)

| Caso | Descripción | Evidencia observada | Resultado |
|---|---|---|---|
| E-01 | Director: califica el anteproyecto y se guarda el historial | calificacion_director=4.5 y 1 registro en el historial de calificaciones | **APROBADO** |
| E-02 | Director: elimina su calificación y el historial queda consistente | la calificación y su registro histórico quedaron en NULL / 0 filas | **APROBADO** |
| E-03 | Director: se valida el rango de la calificación (0 a 5) | la calificación fuera del rango 0-5 fue rechazada y no se guardó | **APROBADO** |
| E-04 | Director: no se puede aprobar sin calificar antes | la aprobación se bloqueó (error=nocalifica); el estado sigue en ENVIADO | **APROBADO** |
| E-05 | Director: aprueba el anteproyecto y el trabajo pasa al evaluador | estado=APROBADO_DIRECTOR y evaluador asignado automáticamente (id=4) | **APROBADO** |
| E-06 | Director: puede rechazar el anteproyecto con observaciones | estado=RECHAZADO con la observación del director guardada y estudiante notificado | **APROBADO** |
| E-07 | Anteproyecto: el estudiante ve el rechazo y puede corregirlo | el estudiante ve el estado, las observaciones y puede corregir y reenviar | **APROBADO** |

### Bloque F — Búsqueda y ficha del estudiante (F-01 … F-05)

| Caso | Descripción | Evidencia observada | Resultado |
|---|---|---|---|
| F-01 | Coordinación: búsqueda de estudiante por nombre | la búsqueda por nombre devolvió 4 estudiantes (incluye el código 900001) | **APROBADO** |
| F-02 | Coordinación: búsqueda de estudiante por código | la búsqueda por código devolvió exactamente 1 fila: ["Estudiante E2E Dos Editado", "900002"] | **APROBADO** |
| F-03 | Coordinación: búsqueda de estudiante por correo | la búsqueda por correo devolvió exactamente 1 fila (código 900004) | **APROBADO** |
| F-04 | Coordinación: la búsqueda sin coincidencias informa que no hay resultados | muestra "No se encontraron estudiantes con ese dato" | **APROBADO** |
| F-05 | Coordinación: la ficha muestra los datos del proyecto y del equipo evaluador | la ficha muestra código 900001, anteproyecto, director y evaluador | **APROBADO** |

### Bloque G — Asignación de director y evaluador (G-01 … G-05)

| Caso | Descripción | Evidencia observada | Resultado |
|---|---|---|---|
| G-01 | Coordinación: asigna el evaluador de un anteproyecto aprobado | evaluador asignado (id=9) sobre un anteproyecto aprobado por el director | **APROBADO** |
| G-02 | Coordinación: anteproyecto de apoyo para las pruebas de asignación | anteproyecto id=4 aprobado por el director | **APROBADO** |
| G-03 | Coordinación: agrega/cambia el director de un anteproyecto aprobado | el director fue cambiado a id=8 sobre el anteproyecto ya aprobado | **APROBADO** |
| G-04 | Coordinación: el evaluador solo se asigna tras la aprobación del director | la asignación del evaluador fue rechazada por estar fuera del flujo | **APROBADO** |
| G-05 | Coordinación: se valida que el director asignado tenga rol DIRECTOR | se rechazó asignar como director a un usuario que no tiene ese rol | **APROBADO** |

### Bloque H — Evaluación del anteproyecto (H-01 … H-04)

| Caso | Descripción | Evidencia observada | Resultado |
|---|---|---|---|
| H-01 | Evaluador: califica el anteproyecto | calificacion_evaluador=4.2 con 1 registro en el historial | **APROBADO** |
| H-02 | Evaluador: elimina su calificación | la calificación y el historial del evaluador quedaron en NULL / 0 filas | **APROBADO** |
| H-03 | Evaluador: no se puede aprobar sin calificar antes | la aprobación del evaluador se bloqueó (error=evalnocalifica) | **APROBADO** |
| H-04 | Evaluador: aprueba el anteproyecto y el estudiante es notificado | estado=APROBADO_EVALUADOR y el estudiante recibió la notificación (1 aviso) | **APROBADO** |

### Bloque I — Informes de estado (I-01 … I-04)

| Caso | Descripción | Evidencia observada | Resultado |
|---|---|---|---|
| I-01 | Informes: el informe por estudiante tiene las columnas esperadas | Estudiante · Código · Anteproyecto · Director · Evaluador · Estado · Calif. dir. · Calif. eval. | **APROBADO** |
| I-02 | Informes: el informe por director tiene las columnas esperadas | Director · Total · Pendientes (en revisión) · En evaluación · Aprobados · Rechazados · Entrega final · Revisión final · Sustentación · Finalizados | **APROBADO** |
| I-03 | Informes: el informe por evaluador tiene las columnas esperadas | Evaluador · Total asignados · Pendientes por aprobar · Aprobados · Rechazados · Entrega final · Revisión final · Sustentación · Finalizados | **APROBADO** |
| I-04 | Informes: el informe refleja el estado real del proyecto | el informe muestra el anteproyecto "E2E Anteproyecto 1792678789" con director, evaluador y notas | **APROBADO** |

### Bloque J — Entrega del documento final y sustentación (J-01 … J-17)

| Caso | Descripción | Evidencia observada | Resultado |
|---|---|---|---|
| J-01 | Entrega final: se valida la URL del documento final | se rechazó una URL de documento final que no es http/https | **APROBADO** |
| J-02 | Entrega final: el estudiante entrega el documento final | anteproyecto=ENTREGA_DOCUMENTO_FINAL, entrega=ENTREGADO | **APROBADO** |
| J-03 | Entrega final: el estudiante conserva el acceso a su entrega | el estudiante sigue viendo su entrega y el enlace permanece activo | **APROBADO** |
| J-04 | Entrega final: no se puede entregar el documento dos veces | la segunda entrega del mismo anteproyecto fue rechazada | **APROBADO** |
| J-05 | Entrega final: el revisor marca la entrega como OBSERVADA | entrega=OBSERVADO, revisado_por=10, observaciones guardadas | **APROBADO** |
| J-06 | Entrega final: el estudiante ve la corrección y la reenvía | la corrección quedó ENTREGADA con el nuevo enlace del documento | **APROBADO** |
| J-07 | Entrega final: al aprobar el documento el trabajo pasa a Revisión Final | anteproyecto=REVISIÓN_FINAL, entrega=APROBADO | **APROBADO** |
| J-08 | Corrección: observar desde Revisión Final devuelve el trabajo a corrección | el trabajo volvió a ENTREGA_DOCUMENTO_FINAL y el estudiante ve la corrección | **APROBADO** |
| J-09 | Entrega final: el estudiante reenvía la corrección y el trabajo vuelve a revisión | la corrección quedó ENTREGADA y el anteproyecto en ENTREGA_DOCUMENTO_FINAL | **APROBADO** |
| J-10 | Entrega final: segunda aprobación del documento corregido | el documento quedó aprobado y el trabajo pasó a REVISIÓN_FINAL | **APROBADO** |
| J-11 | Sustentación: la coordinación programa el acto de sustentación | sustentación programada en Auditorio Principal; el estado pasó a SUSTENTACIÓN | **APROBADO** |
| J-12 | Corrección: la revisión se bloquea cuando el documento ya está cerrado | la revisión fue bloqueada en el estado SUSTENTACIÓN (entrega sigue APROBADO) | **APROBADO** |
| J-13 | Corrección: el formulario de revisión se oculta en estados cerrados | el formulario de revisión se oculta y se informa que el documento está cerrado | **APROBADO** |
| J-14 | Sustentación: el director registra el resultado y el trabajo se finaliza | estado=FINALIZADO, resultado de la sustentación=APROBADO | **APROBADO** |
| J-15 | Sustentación: el estudiante consulta el resultado de su sustentación | el estudiante consulta la fecha, el lugar y el resultado de su sustentación | **APROBADO** |
| J-16 | Corrección: la revisión se bloquea en el estado FINALIZADO | la revisión quedó bloqueada en el estado FINALIZADO (entrega sigue APROBADO) | **APROBADO** |
| J-17 | Consulta: el estudiante ve las calificaciones de su anteproyecto | el estudiante consulta las calificaciones del director y del evaluador | **APROBADO** |

### Bloque K — Calendario académico (K-01 … K-05)

| Caso | Descripción | Evidencia observada | Resultado |
|---|---|---|---|
| K-01 | Calendario: se registra un evento | evento creado con id=4 (01/11/2026 al 05/11/2026, tipo Hito) | **APROBADO** |
| K-02 | Calendario: se edita un evento existente | el evento quedó con título "E2E evento editado 1792678789" y tipo ENTREGA | **APROBADO** |
| K-03 | Calendario: se elimina un evento | el evento se eliminó del calendario | **APROBADO** |
| K-04 | Calendario: el estudiante no puede registrar eventos | redirección a 403.jsp: el estudiante no administra el calendario | **APROBADO** |
| K-05 | Calendario: cualquier usuario autenticado puede consultarlo | el estudiante consulta el calendario (Fecha · Hasta · Tipo · Título · Descripción) | **APROBADO** |

### Bloque L — Formatos de grado (L-01 … L-06)

| Caso | Descripción | Evidencia observada | Resultado |
|---|---|---|---|
| L-01 | Formatos: el formato con ruta local produce un enlace relativo válido | genera el enlace `/tguts/formatos/FDC-124-Anteproyecto.pdf` y el PDF responde HTTP 200 | **APROBADO** |
| L-02 | Formatos: se registra un formato con enlace externo | formato creado con id=3 y enlace externo | **APROBADO** |
| L-03 | Formatos: se actualiza el enlace del documento de un formato | la URL del formato quedó actualizada a `https://drive.google.com/e2e/formato-v2.pdf` | **APROBADO** |
| L-04 | Formatos: se elimina un formato | el formato se eliminó del sistema | **APROBADO** |
| L-05 | Formatos: la URL del formato se escapa antes de armourarse en el HTML | la URL con comillas y etiqueta `<script>` se mostró escapada, sin romper el HTML | **APROBADO** |
| L-06 | Formatos: el estudiante consulta los formatos sin poder administrarlos | el estudiante consulta los formatos sin formulario de administración | **APROBADO** |

### Bloque M — Trámites (M-01 … M-04)

| Caso | Descripción | Evidencia observada | Resultado |
|---|---|---|---|
| M-01 | Trámites: el estudiante solicita un trámite | trámite id=1 en estado PENDIENTE y coordinación notificada | **APROBADO** |
| M-02 | Trámites: la coordinación resuelve el trámite | trámite APROBADO, resuelto por id=10 con respuesta registrada | **APROBADO** |
| M-03 | Trámites: un trámite resuelto no se puede resolver otra vez | un trámite ya resuelto no se puede volver a responder | **APROBADO** |
| M-04 | Trámites: el estudiante solo ve sus propias solicitudes | cada estudiante ve solo sus trámites | **APROBADO** |

### Bloque N — Notificaciones (N-01 … N-03)

| Caso | Descripción | Evidencia observada | Resultado |
|---|---|---|---|
| N-01 | Notificaciones: el sistema registra los avisos de cada evento | 38 notificaciones registradas con 16 eventos distintos | **APROBADO** |
| N-02 | Notificaciones: el estudiante consulta su bandeja de avisos | el estudiante ve en su bandeja los avisos del proceso | **APROBADO** |
| N-03 | Notificaciones: la entrega del documento final notifica al director | la entrega del documento final generó 1 notificación al director | **APROBADO** |

### Bloque O — Limpieza final (O-01)

| Caso | Descripción | Evidencia observada | Resultado |
|---|---|---|---|
| O-01 | Limpieza: la base de datos queda como estaba antes de la prueba | usuarios=6 · ideas=3 · anteproyectos=0 · entrega_final=0 · sustentacion=0 · calificaciones=0 · notificaciones=0 · calendario=3 · formatos=2 · tramites=0 | **APROBADO** |

---

## 3. Detalles técnicos de los bugs corregidos

| # | Bug | Síntoma | Corrección | Caso |
|---|---|---|---|---|
| 1 | Eliminación de calificaciones sin datasource | `javax.servlet.jsp.JspException: No DataSource specified for transaction` | Se añadió `dataSource="${ds}"` a los dos bloques `<sql:transaction>` (director y evaluador) | E-02, H-02 |
| 2 | Acceso a la entrega final perdido tras el envío | el estudiante era redirigido a `anteproyectos.jsp` si el estado no era exactamente `OBSERVADO` | Nueva guarda: el estudiante **siempre** ve su entrega si existe; solo ve el formulario de primera entrega en `APROBADO_EVALUADOR` sin entrega previa | J-03 |
| 3 | Asignación de director bloqueada tras la aprobación | `director_id` solo editable en `BORRADOR`/`RECHAZADO`/`ENVIADO`; el `CASE` preservaba el director en estados posteriores | Se eliminó la guarda y el `CASE`: `director_id = NULLIF(?, '')` siempre; el `select` queda siempre habilitado | G-03 |
| 4 | Formatos con rutas locales aparecían como texto | el JSP solo convertía en enlace si la URL empezaba por `http/https` | Rama nueva con `<c:url value="/${f.url}"/>` para rutas relativas seguras; la validación acepta URL `http(s)` o ruta relativa | L-01 |
| 5 | Roles incoherentes en el banco de ideas | el `select` ofrecía `DIRECTOR`/`COORDINACION` y el servidor validaba `DIRECTOR`/`EVALUADOR`; al editar no se actualizaba `docente_id` | Select alineado a `('DIRECTOR','EVALUADOR')`; UPDATE de edición ramificado: administración/coordinación cambian `docente_id`, el docente conserva la autoría | C-03, C-04 |
| 6 | Validación del director solo en cliente | el `<select>` filtraba rol y activo, pero el POST no revalidaba | Consulta de servidor `SELECT 1 FROM usuarios WHERE id=? AND rol='DIRECTOR' AND activo=1` antes de aceptar | D-05 |
| 7 | Eliminación de usuarios sin revisar al revisor de la entrega | el contador de dependencias ignoraba `entrega_final.revisado_por` | Se añadió `+ (SELECT COUNT(*) FROM entrega_final WHERE revisado_por = ?)` con el 8.º parámetro | B-08 |
| 8 | **La corrección del estudiante quedaba bloqueada** | si la entrega se observaba desde `REVISIÓN_FINAL`, el anteproyecto se quedaba en `REVISIÓN_FINAL` y el formulario de corrección exigía `ENTREGA_DOCUMENTO_FINAL` | Al observar (o poner en revisión) desde `REVISIÓN_FINAL`, el anteproyecto **vuelve a `ENTREGA_DOCUMENTO_FINAL`**; la corrección queda siempre habilitada | J-08, J-09 |
| 9 | **El formulario de revisión seguía activo con el documento cerrado** | en `SUSTENTACIÓN`/`FINALIZADO` el revisor podía dejar la entrega en `OBSERVADO` sin que el estudiante pudiera corregir | Guarda por estado en el POST (`solo ENTREGA_DOCUMENTO_FINAL y REVISIÓN_FINAL`) y ocultación del formulario con el aviso "El documento final ya está cerrado…" | J-12, J-13, J-16 |
| 10 | **Salida HTML sin escapar en los formatos** | una URL con comillas o `<script>` rompía el `href` y podía inyectar etiquetas | `href="${fn:escapeXml(fmtUrl)}"`; la rama de ruta relativa rechaza cualquier valor con `:` | L-05 |
| 11 | **Faltaban operaciones de calendario y formatos** | no se podían editar ni eliminar eventos ni formatos | `accion=editar` / `accion=eliminar` en `calendario.jsp` y `formatos.jsp`, con formulario en modo edición, columna de acciones y avisos de éxito | K-02, K-03, L-03, L-04 |
| 12 | **Búsqueda de estudiantes incompleta** | el panel de coordinación no filtraba por nombre, código ni correo | Campo de consulta (`q`) que busca por nombre, código y correo, con aviso "No se encontraron estudiantes con ese dato." | F-01…F-04 |
| 13 | **Asignaciones sin validación de rol ni de estado** | se podía asignar un evaluador antes de la aprobación del director o un director sin rol `DIRECTOR` | Validaciones de servidor: el evaluador solo se asigna tras `APROBADO_DIRECTOR`; el director debe tener rol `DIRECTOR` y estar activo | G-04, G-05 |

---

## 4. Entorno de prueba reproducible (método ejecutado)

| Paso | Comando / acción | Resultado |
|---|---|---|
| 1 | MySQL/MariaDB de XAMPP encendido en `localhost:3306` | Base `db_tgd_uts` creada con `tguts/sql/db_tgd_uts.sql` (6 usuarios, 3 ideas, 2 formatos, 3 eventos) |
| 2 | Compilar y desplegar: `cd tguts && mvn clean package`, copiar `tguts.war` a `C:\xampp\tomcat\webapps\`, reiniciar Tomcat | `http://localhost:8080/tguts/login.jsp` responde HTTP 200 |
| 3 | Ejecutar la suite E2E (script propio, hoy retirado del repositorio) | 99 casos contra el WAR desplegado |
| 4 | Resultado de la ejecución | **99/99 APROBADOS en 66,2 s** — fecha 22/10/2026 09:49:39 |

### Alternativa documentada (Docker, no ejecutada en esta versión)

| Paso | Comando |
|---|---|
| 1 | `docker network create tguts_net` |
| 2 | `docker run -d --name tguts-mysql --network tguts_net -e MYSQL_ROOT_PASSWORD=rootpw -e MYSQL_DATABASE=db_tgd_uts -v "%CD%\tguts\sql\db_tgd_uts.sql:/docker-entrypoint-initdb.d/01.sql:ro" mysql:8.0` |
| 3 | `cd tguts && mvn -B clean package` |
| 4 | `docker run -d --name tguts-tomcat --network tguts_net -p 18080:8080 -e DB_HOST=tguts_mysql -e DB_PORT=3306 -e DB_NAME=db_tgd_uts -e DB_USER=root -e DB_PASSWORD=rootpw -v "%CD%\tguts\target\tguts.war:/usr/local/tomcat/webapps/ROOT.war:ro" tomcat:9.0-jdk17-temurin` |

---

## 5. Aislamiento de los datos de prueba

| Aspecto | Comportamiento verificado |
|---|---|
| Cuentas creadas por la suite | `e2e-<rol>@uts.edu.co` (administración, coordinación, director, evaluador, estudiantes) |
| Limpieza inicial | La suite borra lo que dejó una ejecución anterior (solo filas `e2e-%` / títulos `E2E %`) |
| Limpieza final | Se eliminan las cuentas `e2e-%` y sus ideas, anteproyectos, entregas, sustentaciones, calificaciones, trámites y notificaciones |
| Datos de demostración | **No se tocan**: el caso O-01 comprueba que al terminar la base queda con 6 usuarios, 3 ideas, 2 formatos, 3 eventos y 0 anteproyectos |

---

## 6. Limitaciones y decisiones documentadas

| Tema | Decisión / limitación |
|---|---|
| Subida de archivos | Se retiró de los formularios de anteproyecto y entrega final (se acordó "dejar solo URL y documentar"). La infraestructura legacy (`pgCampos`, `archivo_subido`, `pgGuardar`, `descargar.jsp`) se conserva para compatibilidad con registros antiguos |
| Correo electrónico | No hay envío SMTP real: las notificaciones se registran en la tabla `notificaciones` con el campo `correo_log` |
| Calendario y formatos iniciales | Son **datos de demostración**, no documentos oficiales de la institución; la interfaz muestra avisos y el SQL tiene comentarios explícitos |
| Nombre institucional | "Universitaria Tecnológica de Santander (UTS)", acorde con el OCR de los logos (`img/images.png`, `img/fondologin.jpg`) |
| Ruta de despliegue probada | La evidencia se obtuvo en el entorno local XAMPP (`http://localhost:8080/tguts`); la variante Docker (`http://localhost:18080`) queda documentada y **no ejecutada** |
| Aislamiento de pruebas | La suite crea sus propias cuentas y no reutiliza las cuentas de demostración para no alterar los datos de la demo |

---

## 7. Veredicto

| Aspecto | Resultado |
|---|---|
| Casos ejecutados | **99** |
| Casos aprobados | **99** |
| Casos fallidos | **0** |
| Duración | 66,2 s |
| Evidencia conservada | Salida íntegra de la ejecución del 22/10/2026 (archivo retirado del repositorio junto con la suite) |
| Flujo completo cubierto | Login → ideas → anteproyecto → calificación y aprobación del director → evaluación y aprobación del evaluador → entrega del documento final → observación y corrección → aprobación → sustentación programada → resultado → `FINALIZADO` |
| Integridad de la base | Verificada por el caso O-01 |
| Conclusión | La versión documentada en `README.md`, `GUION.md`, `DOCUMENTACION_TECNICA.md` y este archivo corresponde **al mismo código verificado** |
