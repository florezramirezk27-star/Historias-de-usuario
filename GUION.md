# Guion de demostración — Sistema de Trabajos de Grado UTS

**Versión:** 2.0 (22/10/2026) — coincide con el código desplegado y con las 99/99 pruebas E2E aprobadas (registro en `TEST_RESULTS.md`).
**Aplicación:** `http://localhost:8080/tguts/` — contexto WAR `tguts` desplegado en **Apache Tomcat 8.5.96 (XAMPP)**.
**Base de datos:** **MySQL/MariaDB 10.4.32 (XAMPP)**, base `db_tgd_uts` (`tguts/sql/db_tgd_uts.sql`).
**Compilación:** Maven con **JDK 21**, `maven.compiler.release=17` → `tguts/target/tguts.war`.

> **Importante:** los usuarios, ideas, calendario y formatos iniciales son **datos de demostración**, no información oficial de la Universitaria Tecnológica de Santander (UTS).

---

## 0. Datos de la demo

| Elemento | Valor |
|---|---|
| URL base | `http://localhost:8080/tguts/` |
| Login | `http://localhost:8080/tguts/login.jsp` |
| Administrador | `admin@uts.edu.co` / `admin123` |
| Coordinación | `coord@uts.edu.co` / `coord123` |
| Director | `director@uts.edu.co` / `director123` |
| Evaluador | `evaluador@uts.edu.co` / `evaluador123` |
| Estudiante | `estudiante@uts.edu.co` / `estudiante123` (código `123456`) |
| Estudiante 2 | `estudiante2@uts.edu.co` / `estudiante123` (código `123457`) |
| Estado inicial de la BD | 6 usuarios · 3 ideas · 2 formatos · 3 eventos de calendario · 0 anteproyectos |

---

## Recorrido de la demostración (cinco roles)

Durante la sustentación mostramos el recorrido de un anteproyecto por los cinco roles. La demostración comienza con el registro de usuarios y termina con la consulta de la calificación. En la tabla indicamos qué haremos, el resultado esperado, la explicación de cada paso y los requisitos que cubre.

| N° | Rol | Procedimiento | Resultado esperado | Explicación | Requisitos |
|---|---|---|---|---|---|
| 1 | Administrador | Abrimos el sistema e iniciamos sesión con la cuenta de administrador. | El sistema permite el ingreso y muestra solo las opciones del administrador. | «Primero ingresamos como administrador, que es el encargado de gestionar los usuarios». | RF-01, RF-02, RF-03 |
| 2 | Administrador | Entramos a Usuarios y seleccionamos "Agregar usuario". Registramos un estudiante (con código de matrícula), un director y un evaluador con nombre, correo, contraseña y rol. | Los tres usuarios aparecen en la lista "Usuarios registrados". | «Creamos estas tres cuentas para mostrar cómo participa cada rol en el proceso». | RF-04, RF-05, RF-06 |
| 3 | Director | Cerramos sesión e ingresamos como director. En el banco de ideas publicamos «Sistema de gestión de inventarios». | La idea queda publicada y disponible para los estudiantes. | «Desde este módulo el docente publica las ideas que podrán elegir los estudiantes». | RF-09, RF-10 |
| 4 | Estudiante | Ingresamos como estudiante, buscamos la idea en el banco de ideas y la seleccionamos. | La idea queda asociada al estudiante y se crea su anteproyecto en estado `BORRADOR`. | «El estudiante revisa las ideas disponibles y selecciona la que quiere desarrollar». | RF-10, RF-11, RF-12, RF-13 |
| 5 | Estudiante | Abrimos "Mi anteproyecto" → "Nuevo anteproyecto". Completamos título y director, **registramos el enlace (URL)** del documento y lo enviamos con "Guardar y enviar al director". | El anteproyecto queda `ENVIADO` y muestra el estudiante, el director, el enlace del documento y el estado. El evaluador aparece como "sin asignar" hasta que el director apruebe. | «Aquí el estudiante registra el anteproyecto, adjunta el enlace del documento y consulta quiénes lo revisan y en qué estado está». | RF-14, RF-15, RF-16 |
| 6 | Director | Ingresamos como director, abrimos Anteproyectos y seleccionamos el del estudiante. | Se muestran el estudiante, su código, el proyecto, el enlace del documento y el estado. | «El director abre el anteproyecto y revisa tanto el documento como los datos del estudiante». | RF-17, RF-18 |
| 7 | Director | Registramos la calificación ("Guardar calificación") y seleccionamos "Aprobar para el evaluador". | El estado pasa a `APROBADO_DIRECTOR`; el sistema asigna un evaluador y el anteproyecto aparece en su cuenta. | «Guardamos la calificación y aprobamos el anteproyecto para que lo reciba el evaluador». | RF-19, RF-20, RF-35 |
| 8 | Evaluador | Ingresamos como evaluador y abrimos Anteproyectos. | Aparece el anteproyecto aprobado por el director. | «El anteproyecto ya aparece en la cuenta del evaluador después de la aprobación del director». | RF-21 |
| 9 | Evaluador | Revisamos la información, registramos la calificación y seleccionamos "Aprobar anteproyecto" (sin calificar, el sistema no permite aprobar). | El sistema registra la aprobación, actualiza el estado a `APROBADO_EVALUADOR` y notifica al estudiante y a la coordinación. | «El evaluador revisa el anteproyecto y deja registrada su aprobación». | RF-22, RF-23, RF-24, RF-35 |
| 10 | Coordinación | Ingresamos como coordinación, buscamos al estudiante por nombre o por código y abrimos su ficha. | Se muestran el estudiante, el proyecto, el director, el evaluador y el estado. | «Coordinación busca al estudiante y consulta la información de su proyecto». | RF-27, RF-28 |
| 11 | Coordinación | Abrimos Informes y consultamos por estudiante, por director y por evaluador. | El sistema muestra las tres tablas de estado. | «También podemos consultar los informes de estado por estudiante, director y evaluador». | RF-29, RF-30, RF-31 |
| 12 | Estudiante | Volvemos a ingresar como estudiante y abrimos el anteproyecto en "Mi anteproyecto". | Se muestran las calificaciones del director y del evaluador, el historial y el estado de aprobación. | «Por último, volvemos a la cuenta del estudiante para consultar la nota y el estado de su anteproyecto». | RF-34, RF-35 |

> Los pasos 1 a 12 son el recorrido mínimo de la sustentación. La continuación (13 a 18) cubre la entrega del documento final y la sustentación, y se muestra si el tiempo lo permite.

| N° | Rol | Procedimiento | Resultado esperado | Explicación | Requisitos |
|---|---|---|---|---|---|
| 13 | Estudiante | Con el anteproyecto `APROBADO_EVALUADOR` abrimos "Entregar documento final", escribimos el título y la URL, y confirmamos. | El anteproyecto pasa a `ENTREGA_DOCUMENTO_FINAL` y la entrega queda `ENTREGADO`. | «El estudiante entrega el documento final mediante un enlace». | RF-36 |
| 14 | Director / Coordinación | Abrimos `entrega_final.jsp` del proyecto → "Revisar documento final" → "Observado (requiere correcciones)" + observaciones → "Guardar revisión". | La entrega queda `OBSERVADO` y el estudiante ve el panel "Corregir y reenviar documento". | «El revisor devuelve el documento con observaciones para que el estudiante lo corrija». | RF-41, RF-37 |
| 15 | Estudiante | Escribimos la nueva URL y seleccionamos "Enviar corrección". | La entrega vuelve a `ENTREGADO` y se notifica al director. | «El estudiante corrige y reenvía el documento». | RF-36, RF-37 |
| 16 | Director / Coordinación | Revisamos la corrección → "Aprobado → pasa a Revisión Final". | La entrega queda `APROBADO` y el anteproyecto pasa a `REVISIÓN_FINAL`. | «Al aprobar la corrección, el trabajo entra en revisión final». | RF-41 |
| 17 | Coordinación | Abrimos `sustentacion.jsp` → "Programar sustentación" con fecha, hora y lugar. | Se registra la sustentación y el anteproyecto pasa a `SUSTENTACIÓN`. | «La coordinación programa la fecha de la sustentación». | RF-42 |
| 18 | Director / Evaluador | Registramos el resultado de la sustentación como `APROBADO`. | El anteproyecto pasa a `FINALIZADO` y el estudiante consulta el resultado. | «Con el resultado aprobado, el proyecto queda finalizado». | RF-43, RF-34 |

---

## 1. Acceso, sesión y roles (RF-01, RF-02, RF-03 · RNF-02, RNF-03)

| Paso | Acción (rol) | Resultado esperado verificado |
|---|---|---|
| 1.1 | Abrir `http://localhost:8080/tguts/` | Muestra `login.jsp` con logo UTS y aviso "Cuentas de demostración (no son usuarios reales)" |
| 1.2 | Ingresar `admin@uts.edu.co` / `admin123` | Redirige a `home.jsp`; panel Administrador |
| 1.3 | Cerrar sesión → ingresar `coord@uts.edu.co` / `coord123` | Panel Coordinación (buscar estudiante, informes, trámites) |
| 1.4 | Cerrar sesión → ingresar `director@uts.edu.co` / `director123` | Panel Director (banco de ideas, anteproyectos dirigidos) |
| 1.5 | Cerrar sesión → ingresar `evaluador@uts.edu.co` / `evaluador123` | Panel Evaluador (anteproyectos aprobados por el director) |
| 1.6 | Cerrar sesión → ingresar `estudiante@uts.edu.co` / `estudiante123` | Panel Estudiante (bolsa de ideas, mi anteproyecto, trámites, entrega final) |
| 1.7 | Ingresar una contraseña incorrecta | Permanece en `login.jsp` con aviso "Credenciales inválidas" |
| 1.8 | Con la sesión cerrada, pedir `http://localhost:8080/tguts/usuarios.jsp` | Redirige a `login.jsp` (guarda de sesión) |
| 1.9 | Revisar el menú lateral de cada rol | Cada rol ve solo sus módulos (RF-03 / RNF-02): ADMIN = usuarios + informes + coordinación + trámites; COORDINACION = buscar estudiante + informes + trámites; DIRECTOR = banco de ideas + anteproyectos; EVALUADOR = solo anteproyectos; ESTUDIANTE = banco de ideas + anteproyectos + trámites |
| 1.10 | Estudiante → `usuarios.jsp` o `coordinacion.jsp` | Redirige a `403.jsp` (control de acceso por rol, RNF-02) |
| 1.11 | Director → `informes.jsp` | Redirige a `403.jsp` |
| 1.12 | Evaluador → `ideas.jsp` | Redirige a `403.jsp` |
| 1.13 | Coordinación → `usuarios.jsp` | Redirige a `403.jsp` |

---

## 2. Administración de usuarios — CRUD (RF-04, RF-05, RF-06, RF-07, RF-08)

| Paso | Acción (Admin) | Resultado esperado verificado |
|---|---|---|
| 2.1 | `usuarios.jsp` → formulario "Agregar usuario" → Nombre "Docente Demo", Correo `docente.demo@uts.edu.co`, Rol `DIRECTOR`, Contraseña `demo12345` | Usuario insertado; la contraseña se guarda con PBKDF2-HMAC-SHA256 (RF-04) |
| 2.2 | Iniciar sesión con la cuenta creada | Entra a `home.jsp`: la cuenta creada ya es utilizable |
| 2.3 | `usuarios.jsp` → acción "Editar" del usuario creado | Abre el formulario en modo edición con los datos cargados (RF-05, RF-07) |
| 2.4 | Cambiar el nombre a "Docente Demo Editado" → "Guardar cambios" | Nombre actualizado en BD |
| 2.5 | Crear un usuario con un correo ya registrado | El sistema lo rechaza con aviso de correo duplicado |
| 2.6 | Crear un usuario con contraseña de menos de 8 caracteres | El sistema lo rechaza (validación de largo mínimo) |
| 2.7 | Crear un usuario con rol `ESTUDIANTE` sin código de matrícula | El sistema lo rechaza y exige el código |
| 2.8 | Eliminar el usuario creado (sin dependencias) | Fila eliminada correctamente (RF-08) |
| 2.9 | Intentar eliminar un usuario **con** anteproyecto/idea/calificaciones/trámites/revisión de entrega final asociados | Bloqueado: "No se puede eliminar: el usuario tiene anteproyectos, ideas, calificaciones, trámites o revisiones de entrega final asociados." |
| 2.10 | Intentar eliminar la propia cuenta con la que se ingresó | Bloqueado: "No puedes eliminar la cuenta con la que estás ingresó." |
| 2.11 | Revisar la tabla "Usuarios registrados" | Columnas: Nombre · Correo · Rol · Código · Acciones |

---

## 3. Banco de ideas — CRUD (RF-09, RF-10, RF-11, RF-12, RF-13, RF-25)

| Paso | Acción (rol) | Resultado esperado verificado |
|---|---|---|
| 3.1 | **Director**: `ideas.jsp` → formulario de publicación → Título "Ideas para UTS", Descripción, Docente = el mismo director | Idea publicada a nombre del director (`docente_id` = su id), estado `PUBLICADA` (RF-09) |
| 3.2 | **Admin**: publicar una idea indicando el Docente | Idea registrada con el docente elegido; el docente solo puede ser `DIRECTOR` o `EVALUADOR` |
| 3.3 | **Admin**: intentar asignar como docente a un usuario que no es Director/Evaluador | El servidor rechaza la operación |
| 3.4 | **Admin**: "Editar" la idea y cambiar el Docente | `docente_id` se actualiza en BD (RF-25) |
| 3.5 | **Admin**: "Cerrar" una idea | La idea queda en `CERRADA` y deja de ofrecerse en la bolsa del estudiante |
| 3.6 | **Admin**: "Eliminar" una idea | La idea se elimina del banco |
| 3.7 | **Estudiante**: `ideas.jsp` → "Seleccionar" en una idea `PUBLICADA` | Se crea el anteproyecto en `BORRADOR` con esa idea y su docente como director; la idea pasa a `SELECCIONADA` (RF-11, RF-13) |
| 3.8 | **Estudiante**: intentar seleccionar una segunda idea | Bloqueado: "Ya tienes un anteproyecto registrado. No puedes seleccionar otra idea." (RF-12) |
| 3.9 | **Estudiante**: intentar seleccionar una idea `CERRADA` | La selección es rechazada |
| 3.10 | **Estudiante**: intentar publicar una idea | Redirige a `403.jsp`: el estudiante no publica ideas |
| 3.11 | Revisar la tabla "Ideas disponibles" | Columnas: Título · Descripción · Docente · Estado · Acciones |

---

## 4. Anteproyecto del estudiante — alta, edición, envío y borrado (RF-14, RF-15, RF-16, RF-36)

| Paso | Acción (Estudiante) | Resultado esperado verificado |
|---|---|---|
| 4.1 | `anteproyecto_form.jsp` → completar Título, Director (Carlos Gómez, rol DIRECTOR activo) y el **enlace (URL)** del documento `https://drive.google.com/...` → "Guardar y enviar al director" | El anteproyecto pasa de `BORRADOR` a `ENVIADO`; se notifica al director (RF-14, RF-16, RF-37) |
| 4.2 | Enviar con una URL de documento que no sea `http(s)` (p. ej. `ftp://...` o un archivo) | El servidor lo rechaza; el estado no cambia |
| 4.3 | Cambiar el Director por un usuario que no sea `DIRECTOR` activo (p. ej. Coordinación) | El servidor lo rechaza: "El director seleccionado no es un Director válido o está inactivo"; el estado sigue `BORRADOR` |
| 4.4 | `anteproyectos.jsp` → "Mi anteproyecto" | Abre `anteproyecto_ver.jsp` con la información general (RF-15) |
| 4.5 | `anteproyecto_form.jsp` → "Eliminar" (borrador) | El borrador se elimina y la idea vuelve a la bolsa de ideas (disponible) |
| 4.6 | Intentar eliminar un anteproyecto ya `ENVIADO` | La operación es rechazada (guarda de estado) |
| 4.7 | Con la sesión del estudiante 2, abrir `anteproyecto_ver.jsp?id=` del anteproyecto del estudiante 1 | Redirige a `403.jsp` (control de propiedad, RNF-03) |
| 4.8 | Revisar el bloque "Documento" del anteproyecto | Solo se acepta y se muestra el **enlace (URL)**; no hay subida de archivos |

---

## 5. Dirección del anteproyecto — calificar, aprobar, rechazar (RF-17, RF-18, RF-19, RF-20, RF-35)

| Paso | Acción (Director) | Resultado esperado verificado |
|---|---|---|
| 5.1 | `anteproyectos.jsp` → anteproyecto asignado | Lista "Anteproyectos asignados a ti como director" (RF-17) |
| 5.2 | `anteproyecto_ver.jsp?id=X` → "1. Calificar (RF-19)" → 4.5 + observación → "Guardar calificación" | `calificacion_director = 4.5`; se inserta una fila en `calificaciones` con rol `DIRECTOR` (RF-35) |
| 5.3 | "Eliminar calificación" | `calificacion_director = NULL` y el historial queda consistente (transacción con `dataSource`) |
| 5.4 | Guardar una calificación fuera del rango 0–5 | El sistema la rechaza y no la guarda |
| 5.5 | "Aprobar para el evaluador (RF-20)" sin haber calificado | Bloqueado: "Primero califica el anteproyecto para poder aprobarlo"; el estado sigue `ENVIADO` |
| 5.6 | Calificar 4.0 → "Aprobar para el evaluador (RF-20)" | Estado = `APROBADO_DIRECTOR`; se asigna automáticamente un evaluador y se notifica a evaluador y estudiante |
| 5.7 | Sobre otro anteproyecto `ENVIADO` → "Rechazar" con observaciones | Estado = `RECHAZADO`; se guarda la observación del director y se notifica al estudiante |
| 5.8 | El estudiante abre su anteproyecto rechazado | Ve el estado, las observaciones del director y puede corregir y reenviar |
| 5.9 | Revisar la tabla "Historial de calificaciones" | Columnas: Quién calificó · Rol · Calificación · Observación · Fecha |

---

## 6. Búsqueda y ficha del estudiante (coordinación) (RF-27, RF-28)

| Paso | Acción (Coordinación) | Resultado esperado verificado |
|---|---|---|
| 6.1 | `coordinacion.jsp` → campo "Consulta" → escribir el **nombre** del estudiante → "Buscar" | Tabla "Resultados" con las coincidencias: Nombre · Código · Correo · Acción |
| 6.2 | Buscar por **código** de matrícula (p. ej. `123456`) | Devuelve exactamente la fila del estudiante con ese código |
| 6.3 | Buscar por **correo** (p. ej. `estudiante@uts.edu.co`) | Devuelve exactamente la fila del estudiante con ese correo |
| 6.4 | Buscar un dato inexistente | Aviso: "No se encontraron estudiantes con ese dato." |
| 6.5 | Clic en "Ver ficha" de una fila | Ficha con los datos del estudiante, del proyecto/anteproyecto, del director y del evaluador (RF-28) |
| 6.6 | Student logueado intenta entrar a `coordinacion.jsp` | Redirige a `403.jsp` |

---

## 7. Asignación de director y evaluador (RF-26, RF-37)

| Paso | Acción (Coordinación) | Resultado esperado verificado |
|---|---|---|
| 7.1 | Ficha del estudiante → "Asignar director y evaluador (RF-26)" → guardar | `director_id` y/o `evaluador_id` actualizados; se envían las notificaciones (RF-37) |
| 7.2 | Sobre un anteproyecto ya `APROBADO_DIRECTOR`, asignar/cambiar el director | Allowed en cualquier estado (decisión documentada del profesor): el director queda cambiado y el evaluador actual se conserva |
| 7.3 | Intentar asignar el evaluador en un anteproyecto que **no** está aprobado por el director | Rechazado: "El evaluador solo puede asignarse cuando el anteproyecto esté aprobado por el director." |
| 7.4 | Intentar asignar como director a un usuario sin rol `DIRECTOR` | Rechazado por validación de servidor |

---

## 8. Evaluación del anteproyecto (evaluador) (RF-21, RF-22, RF-23, RF-24, RF-35)

| Paso | Acción (Evaluador) | Resultado esperado verificado |
|---|---|---|
| 8.1 | `anteproyectos.jsp` | Lista "Anteproyectos aprobados por el director para tu evaluación" (RF-21) |
| 8.2 | `anteproyecto_ver.jsp?id=X` → "Evaluación del anteproyecto (RF-22)" → 4.2 + observación → "Guardar calificación" | `calificacion_evaluador = 4.2`; 1 registro en el historial de calificaciones (RF-35) |
| 8.3 | "Eliminar calificación" | La calificación y su registro histórico quedan en `NULL` / 0 filas |
| 8.4 | "Aprobar anteproyecto (RF-23)" sin haber calificado | Bloqueado: "Primero califica el anteproyecto para poder aprobarlo como evaluador" |
| 8.5 | Calificar 4.0 → "Aprobar anteproyecto (RF-23)" | Estado = `APROBADO_EVALUADOR`; el estudiante y la coordinación reciben notificación (RF-24, RF-37) |

---

## 9. Entrega del documento final y revisión (RF-25, RF-36, RF-41)

| Paso | Acción (rol) | Resultado esperado verificado |
|---|---|---|
| 9.1 | **Estudiante** con estado `APROBADO_EVALUADOR` → `anteproyectos.jsp` → "Entregar documento final" | Abre `entrega_final.jsp` con el formulario de entrega |
| 9.2 | Enviar una URL de documento que no sea `http(s)` | El servidor lo rechaza |
| 9.3 | Título + URL válida → "Entregar documento final" | Anteproyecto = `ENTREGA_DOCUMENTO_FINAL`; entrega = `ENTREGADO` (RF-36) |
| 9.4 | Intentar entregar el documento por segunda vez | La segunda entrega es rechazada (1 entrega por anteproyecto) |
| 9.5 | **Estudiante** vuelve a abrir `entrega_final.jsp?id=X` | Ve "Documento entregado" con título, fecha, estado y enlace; **no** es redirigido a `anteproyectos.jsp` |
| 9.6 | **Director/Coordinación** → `entrega_final.jsp?id=X` → "Revisar documento final" → "Observado (requiere correcciones)" + observaciones → "Guardar revisión" | `entrega_final.estado = OBSERVADO`, `revisado_por` = id del revisor, observaciones guardadas (RF-41) |
| 9.7 | **Estudiante** → `entrega_final.jsp?id=X` | Ve el panel "Corregir y reenviar documento" con el formulario de corrección |
| 9.8 | **Estudiante** envía la corrección con la nueva URL → "Enviar corrección" | `entrega_final.estado = ENTREGADO`; el director es notificado |
| 9.9 | **Director/Coordinación** revisa la corrección → "Aprobado → pasa a Revisión Final" | `entrega_final.estado = APROBADO`; el anteproyecto pasa a `REVISIÓN_FINAL` |
| 9.10 | Con el anteproyecto en `REVISIÓN_FINAL`, marcar la entrega como `OBSERVADO` | El trabajo **regresa a `ENTREGA_DOCUMENTO_FINAL`** y el estudiante vuelve a ver el formulario de corrección |
| 9.11 | El estudiante reenvía la corrección | La entrega queda `ENTREGADO` y el anteproyecto en `ENTREGA_DOCUMENTO_FINAL` para la nueva revisión |
| 9.12 | Aprobar de nuevo la entrega corregida | Entrega `APROBADO` y anteproyecto `REVISIÓN_FINAL` |
| 9.13 | Con el anteproyecto en `SUSTENTACIÓN` o `FINALIZADO`, intentar revisar la entrega | La revisión queda **bloqueada** (documento cerrado) y el formulario de revisión se oculta con el aviso "El documento final ya está cerrado…" |

---

## 10. Sustentación y cierre del proyecto (RF-34, RF-42, RF-43)

| Paso | Acción (rol) | Resultado esperado verificado |
|---|---|---|
| 10.1 | **Coordinación** → `sustentacion.jsp` → "Programar sustentación" → fecha, hora, lugar | Registro creado en `sustentacion`; el estado del anteproyecto pasa a `SUSTENTACIÓN` (RF-42) |
| 10.2 | **Director/Evaluador** → "Registrar resultado" → `APROBADO` + observaciones | `sustentacion.resultado = APROBADO`; el estado del anteproyecto pasa a `FINALIZADO` (RF-43) |
| 10.3 | **Director/Evaluador** → "Registrar resultado" → `RECHAZADO` | El resultado queda `RECHAZADO` y el anteproyecto permanece en `SUSTENTACIÓN` (no vuelve a `REVISIÓN_FINAL`) |
| 10.4 | **Estudiante** → "Ver sustentación" | Consulta fecha, hora, lugar y resultado de su sustentación (RF-34) |
| 10.5 | Con el anteproyecto en `FINALIZADO`, intentar revisar la entrega final | La revisión queda bloqueada |

---

## 11. Calendario académico — CRUD (RF-32)

| Paso | Acción (rol) | Resultado esperado verificado |
|---|---|---|
| 11.1 | Cualquier rol autenticado → `calendario.jsp` | Lista los eventos con el aviso de que las fechas iniciales son datos de demostración (consulta sin restricción de rol) |
| 11.2 | **Admin/Coordinación** → registrar evento (título, descripción, fecha, hasta, tipo) | Evento insertado y visible en la tabla |
| 11.3 | **Admin/Coordinación** → "Editar" un evento | Abre el formulario con los datos cargados; al guardar, título y tipo quedan actualizados |
| 11.4 | **Admin/Coordinación** → "Eliminar" un evento | El evento se elimina del calendario |
| 11.5 | **Estudiante** → intentar registrar un evento | Redirige a `403.jsp`: el estudiante no administra el calendario |
| 11.6 | Revisar la tabla "Eventos" | Columnas: Fecha · Hasta · Tipo · Título · Descripción · Acciones |

---

## 12. Formatos de grado — CRUD (RF-33)

| Paso | Acción (rol) | Resultado esperado verificado |
|---|---|---|
| 12.1 | Cualquier rol → `formatos.jsp` | Lista "Formatos disponibles" con el aviso de que son plantillas base de demostración |
| 12.2 | Observar el formato "FDC-124 · Formato de anteproyecto (idea)" | Columna "Archivo": enlace generado con `c:url` → `http://localhost:8080/tguts/formatos/FDC-124-Anteproyecto.pdf`; el PDF responde HTTP 200 |
| 12.3 | **Admin/Coordinación** → "Agregar formato con enlace al documento" (nombre, descripción, URL externa) | Formato registrado y visible |
| 12.4 | **Admin/Coordinación** → "Actualizar documento" de un formato | La URL del formato queda actualizada y el enlace sigue funcionando |
| 12.5 | **Admin/Coordinación** → "Eliminar formato" | El formato se elimina del sistema |
| 12.6 | Registrar una URL con comillas y una etiqueta `<script>` | La URL se muestra **escapada** (`fn:escapeXml`) y el HTML no se rompe |
| 12.7 | **Estudiante** → `formatos.jsp` | Consulta los formatos pero **sin** formulario de administración |
| 12.8 | Revisar la tabla "Formatos disponibles" | Columnas: Formato · Descripción · Archivo · Actualizar documento (Guardar / Eliminar formato) |

---

## 13. Informes de estado (RF-29, RF-30, RF-31)

| Paso | Acción (Admin/Coordinación) | Resultado esperado verificado |
|---|---|---|
| 13.1 | `informes.jsp` → botón "Por estudiante (RF-29)" | Tabla con columnas: **Estudiante · Código · Anteproyecto · Director · Evaluador · Estado · Calif. dir. · Calif. eval.** |
| 13.2 | `informes.jsp?tipo=directores` → botón "Por director (RF-30)" | Tabla con columnas: **Director · Total · Pendientes (en revisión) · En evaluación · Aprobados · Rechazados · Entrega final · Revisión final · Sustentación · Finalizados** |
| 13.3 | `informes.jsp?tipo=evaluadores` → botón "Por evaluador (RF-31)" | Tabla con columnas: **Evaluador · Total asignados · Pendientes por aprobar · Aprobados · Rechazados · Entrega final · Revisión final · Sustentación · Finalizados** |
| 13.4 | Contrastar el informe con el estado real del proyecto | Las filas reflejan el director, el evaluador y las notas del anteproyecto mostrado |
| 13.5 | **Director** → `informes.jsp` | Redirige a `403.jsp` (los informes son de administración/coordinación) |

---

## 14. Trámites — retiro, prórroga y beneficios (RF-38, RF-39, RF-40)

| Paso | Acción (rol) | Resultado esperado verificado |
|---|---|---|
| 14.1 | **Estudiante** → `tramites.jsp` → "Nueva solicitud" → tipo, detalle → "Enviar solicitud" | Trámite insertado en estado `PENDIENTE`; la coordinación es notificada (RF-37) |
| 14.2 | **Coordinación** → "Responder" el trámite (respuesta) | Trámite `APROBADO` o `RECHAZADO` con `resuelto_por` y `respuesta` guardados |
| 14.3 | Intentar responder un trámite ya resuelto | La operación es rechazada |
| 14.4 | Cada estudiante revisa la lista "Mis trámites" | Solo ve sus propias solicitudes (control de propiedad, RNF-03) |
| 14.5 | Revisar la tabla de trámites | Columnas: Estudiante · Tipo · Detalle · Estado · Respuesta · Fecha · Acción (columna "Acción" solo para administración/coordinación) |

---

## 15. Notificaciones del proceso (RF-37)

| Paso | Acción | Resultado esperado verificado |
|---|---|---|
| 15.1 | Revisar `notificaciones.jsp` como destinatario de los eventos | Cada evento del proceso genera una fila en `notificaciones` (envío, calificación, aprobación, entrega, revisión, corrección, trámite, asignación) |
| 15.2 | Consultar la bandeja del estudiante | El estudiante ve los avisos de su proceso (título, mensaje, fecha, estado de lectura) |
| 15.3 | Observar el menú lateral | El contador de notificaciones no leídas se actualiza |
| 15.4 | Revisar la tabla de la bandeja | Columnas: Fecha · Título · Mensaje · Estado |

---

## 16. Tabla resumen de requisitos y pantallas

| Requisito | Descripción | Pantalla(s) |
|---|---|---|
| RF-01 | Autenticación de usuarios | `login.jsp` / `logout.jsp` |
| RF-02 | Validación de credenciales y sesión | `login.jsp`, `common/guard.jsp` |
| RF-03 | Panel inicial y menú según rol | `home.jsp`, `common/menu.jsp` |
| RF-04 | Crear usuarios | `usuarios.jsp` |
| RF-05 | Consultar/editar un usuario | `usuarios.jsp` |
| RF-06 | Listar usuarios registrados | `usuarios.jsp` |
| RF-07 | Editar usuarios | `usuarios.jsp` |
| RF-08 | Eliminar usuarios con control de dependencias | `usuarios.jsp` |
| RF-09 | Publicar idea de trabajo de grado | `ideas.jsp` |
| RF-10 | Consultar el banco de ideas | `ideas.jsp` |
| RF-11 | Seleccionar idea | `ideas.jsp` |
| RF-12 | Restricción de un solo anteproyecto por estudiante | `ideas.jsp` |
| RF-13 | Creación del anteproyecto al seleccionar la idea | `ideas.jsp` |
| RF-14 | Registrar y editar la información del anteproyecto | `anteproyecto_form.jsp` |
| RF-15 | Consultar el anteproyecto propio | `anteproyecto_ver.jsp` |
| RF-16 | Enviar el anteproyecto al director | `anteproyecto_form.jsp` |
| RF-17 | Ver anteproyectos asignados como director | `anteproyectos.jsp` |
| RF-18 | Consultar el detalle del anteproyecto | `anteproyecto_ver.jsp` |
| RF-19 | Calificar el anteproyecto (director) | `anteproyecto_ver.jsp` |
| RF-20 | Aprobar/rechazar el anteproyecto (director) | `anteproyecto_ver.jsp` |
| RF-21 | Ver anteproyectos aprobados (evaluador) | `anteproyectos.jsp` |
| RF-22 | Calificar el anteproyecto (evaluador) | `anteproyecto_ver.jsp` |
| RF-23 | Aprobar/rechazar el anteproyecto (evaluador) | `anteproyecto_ver.jsp` |
| RF-24 | Notificar la evaluación a estudiante y coordinación | `anteproyecto_ver.jsp` |
| RF-25 | Gestión (CRUD) de ideas por administración/coordinación | `ideas.jsp` |
| RF-26 | Asignar director y evaluador | `coordinacion.jsp` |
| RF-27 | Buscar estudiantes por nombre, código o correo | `coordinacion.jsp` |
| RF-28 | Ficha del estudiante/proyecto | `coordinacion.jsp` |
| RF-29 | Informe por estudiante | `informes.jsp` |
| RF-30 | Informe por director | `informes.jsp` |
| RF-31 | Informe por evaluador | `informes.jsp` |
| RF-32 | Calendario académico (consulta y CRUD) | `calendario.jsp` |
| RF-33 | Formatos de grado (consulta y CRUD) | `formatos.jsp` |
| RF-34 | Consulta del estado y de la sustentación por el estudiante | `anteproyecto_ver.jsp`, `sustentacion.jsp` |
| RF-35 | Historial de calificaciones | `anteproyecto_ver.jsp` |
| RF-36 | Entrega del documento final por URL | `entrega_final.jsp` |
| RF-37 | Notificaciones del proceso | `notificaciones.jsp` |
| RF-38 | Solicitud de retiro del proyecto | `tramites.jsp` |
| RF-39 | Solicitud de prórroga | `tramites.jsp` |
| RF-40 | Solicitud de beneficio | `tramites.jsp` |
| RF-41 | Revisión del documento final (observar / poner en revisión / aprobar) | `entrega_final.jsp` |
| RF-42 | Programar la sustentación | `sustentacion.jsp` |
| RF-43 | Registrar el resultado de la sustentación | `sustentacion.jsp` |
| RNF-02 | Control de acceso por rol (menú y guardas de página) | `common/menu.jsp`, `403.jsp` |
| RNF-03 | Control de propiedad (cada rol solo ve sus datos) | `anteproyecto_ver.jsp`, `403.jsp` |

---

## 17. Casos de error y validaciones que conviene mostrar en la demo

| Caso | Disparo en la interfaz | Mensaje / resultado verificado |
|---|---|---|
| Credenciales inválidas | Login con contraseña incorrecta | "Credenciales inválidas" y se permanece en `login.jsp` |
| Sin sesión | URL de módulo protegido sin iniciar sesión | Redirección a `login.jsp` |
| Token CSRF ausente o inválido | POST manipulado desde el navegador | Redirección a `403.jsp?error=csrf` y ningún registro creado |
| Acceso por rol | Módulo fuera del rol | Redirección a `403.jsp` |
| Acceso por propiedad | Ficha de otro estudiante | Redirección a `403.jsp` |
| Correo duplicado | Alta de usuario con correo existente | Aviso de correo duplicado |
| Contraseña corta | Alta de usuario con < 8 caracteres | Rechazada |
| Estudiante sin código | Alta de usuario rol ESTUDIANTE sin código | Rechazada |
| Dependencias de usuario | Borrado de usuario con datos asociados | "No se puede eliminar: el usuario tiene anteproyectos, ideas, calificaciones, trámites o revisiones de entrega final asociados." |
| Borrado de la propia cuenta | Admin borra su cuenta | "No puedes eliminar la cuenta con la que estás ingresó." |
| Idea ya cerrada | Estudiante selecciona idea `CERRADA` | Rechazada |
| Segunda idea | Estudiante con anteproyecto selecciona otra idea | "Ya tienes un anteproyecto registrado. No puedes seleccionar otra idea." |
| Director inválido | Anteproyecto enviado con director de rol no `DIRECTOR` | "El director seleccionado no es un Director válido o está inactivo" |
| Documento no válido | URL de documento que no es `http(s)` | Rechazada |
| Aprobar sin calificar (director) | Botón "Aprobar para el evaluador" sin calificación | "Primero califica el anteproyecto para poder aprobarlo" |
| Aprobar sin calificar (evaluador) | Botón "Aprobar anteproyecto" sin calificación | "Primero califica el anteproyecto para poder aprobarlo como evaluador" |
| Evaluador sin aprobación previa | Coordinación asigna evaluador antes de la aprobación del director | "El evaluador solo puede asignarse cuando el anteproyecto esté aprobado por el director." |
| Búsqueda sin resultados | Búsqueda en coordinación sin coincidencias | "No se encontraron estudiantes con ese dato." |
| Entrega duplicada | Segundo envío del documento final | Rechazado |
| Documento final cerrado | Revisión con el trabajo en `SUSTENTACIÓN`/`FINALIZADO` | Revisión bloqueada y formulario oculto: "El documento final ya está cerrado…" |
| Trámite ya resuelto | Responder un trámite resuelto | Rechazado |
| HTML en la URL de un formato | URL con comillas y `<script>` | Se muestra escapada; el HTML no se rompe |

---

## 18. Checklist antes de la demostración

| # | Verificación | Cómo comprobarla |
|---|---|---|
| 1 | MySQL/MariaDB de XAMPP encendido en el puerto 3306 | `netstat -ano | findstr 3306` |
| 2 | Tomcat de XAMPP arrancado | `http://localhost:8080/tguts/login.jsp` responde HTTP 200 |
| 3 | Base `db_tgd_uts` cargada | `C:\xampp\mysql\bin\mysql.exe -uroot -N -B -e "SELECT COUNT(*) FROM db_tgd_uts.usuarios"` → 6 |
| 4 | WAR actualizado con los últimos cambios | `cd tguts && mvn clean package` y copiar `tguts.war` a `C:\xampp\tomcat\webapps\` |
| 5 | Las 5 cuentas de rol abren su panel | Repetir el bloque 1 del guion |

---

## 19. Alternativa opcional con Docker (no ejecutada en esta versión)

| Paso | Comando | Nota |
|---|---|---|
| 19.1 | `docker network create tguts_net` | Requiere el **Docker Desktop encendido** |
| 19.2 | `docker run -d --name tguts-mysql --network tguts_net -e MYSQL_ROOT_PASSWORD=rootpw -e MYSQL_DATABASE=db_tgd_uts -v "%CD%\tguts\sql\db_tgd_uts.sql:/docker-entrypoint-initdb.d/01.sql:ro" mysql:8.0` | MySQL 8 con el esquema inicial |
| 19.3 | `cd tguts && mvn -B clean package` | Genera `tguts/target/tguts.war` |
| 19.4 | `docker run -d --name tguts-tomcat --network tguts_net -p 18080:8080 -e DB_HOST=tguts_mysql -e DB_PORT=3306 -e DB_NAME=db_tgd_uts -e DB_USER=root -e DB_PASSWORD=rootpw -v "%CD%\tguts\target\tguts.war:/usr/local/tomcat/webapps/ROOT.war:ro" tomcat:9.0-jdk17-temurin` | Publica la app en `http://localhost:18080/` |

> **Estado de esta vía:** es una **alternativa documentada, no ejecutada**. La verificación de esta versión se realizó con el entorno local XAMPP (Tomcat 8.5.96 + MariaDB 10.4.32) en `http://localhost:8080/tguts`.

---

## 20. Correspondencia con el documento Word

| Sección del Word | Qué se toma de este archivo |
|---|---|
| Alcance / entorno | Secciones 0 y 19 |
| Requisitos funcionales | Sección 16 (tabla RF-01…RF-43) |
| Guion de demostración | "Recorrido de la demostración" (pasos 1 a 18) + secciones 1 a 15 (todas en tablas) |
| Casos de error y validaciones | Sección 17 |
| Verificación / checklist | Sección 18 |
| Pruebas | `TEST_RESULTS.md` (registro histórico) |
