# Guion de demostración — Sistema de Trabajos de Grado UTS

**Versión:** 1.0 (19/10/2026)
**Entorno de demo:** Tomcat 9 + MySQL 8 (Docker) — `http://localhost:18080/`
**Credenciales:** ver tabla de usuarios de demostración en `README.md`

> **Importante:** Los usuarios, ideas, calendario y formatos iniciales son **datos de demostración**, no información oficial de la Universitaria Tecnológica de Santander.

---

## 1. Acceso y roles (RF-01, RF-02, RF-03)

| Paso | Acción | Resultado esperado |
|------|--------|--------------------|
| 1.1 | Abrir `http://localhost:18080/` | Muestra `login.jsp` con logo UTS y aviso "Cuentas de demostración (no son usuarios reales)" |
| 1.2 | Ingresar `admin@uts.edu.co` / `admin123` | Redirige a `home.jsp` con panel Administrador (gestión usuarios, informes, etc.) |
| 1.3 | Cerrar sesión → ingresar `coord@uts.edu.co` / `coord123` | Panel Coordinación: panel de coordinación, trámites, informes |
| 1.4 | Cerrar sesión → ingresar `director@uts.edu.co` / `director123` | Panel Director: ideas publicadas, anteproyectos dirigidos, calificaciones |
| 1.5 | Cerrar sesión → ingresar `evaluador@uts.edu.co` / `evaluador123` | Panel Evaluador: anteproyectos aprobados por director |
| 1.6 | Cerrar sesión → ingresar `estudiante@uts.edu.co` / `estudiante123` | Panel Estudiante: bolsa de ideas, mis anteproyectos, entrega final |
| 1.7 | Probar credencial incorrecta | Permanece en `login.jsp` con aviso "Credenciales inválidas" |

---

## 2. Banco de ideas (RF-10, RF-11, RF-12, RF-13)

| Paso | Acción (rol) | Resultado esperado |
|------|--------------|--------------------|
| 2.1 | **Admin**: `ideas.jsp` → "Agregar idea" → Título "Sistema de inventarios", Docente **Evaluador** (María Rodríguez) | Idea creada con `docente_id = 4` (evaluador); estado `PUBLICADA` |
| 2.2 | **Admin**: editar la idea creada → cambiar Docente a **Director** (Carlos Gómez) | `docente_id` actualizado a 3 en BD |
| 2.3 | **Director**: `ideas.jsp` → ve solo sus ideas; puede editar título/descripción, **no** cambia docente | Botón editar presente; al guardar, `docente_id` sigue siendo 3 |
| 2.4 | **Estudiante**: `ideas.jsp` → "Seleccionar" en idea disponible | Crea anteproyecto en `BORRADOR` con ese director; idea pasa a `SELECCIONADA` |
| 2.5 | **Estudiante**: intentar seleccionar otra idea | Bloqueado: "Ya tienes un anteproyecto registrado" |

---

## 3. Anteproyecto: formulario y envío (RF-14, RF-15, RF-16, RF-36)

| Paso | Acción | Resultado esperado |
|------|--------|--------------------|
| 3.1 | **Estudiante**: `anteproyecto_form.jsp?id=X` → intentar enviar con director = Coordinación | Error servidor: "El director seleccionado no es un Director válido o está inactivo"; estado sigue `BORRADOR` |
| 3.2 | **Estudiante**: mismo formulario → director = Carlos Gómez (Director), URL `https://drive.google.com/...` | Estado cambia a `ENVIADO`; notificación al director |
| 3.3 | **Director**: `anteproyecto_ver.jsp?id=X` → califica 4.5 / observación "ok" | `calificacion_director=4.5`; fila en `calificaciones` (rol DIRECTOR) |
| 3.4 | **Director**: "Eliminar calificación" | `calificacion_director=NULL`; historial borrado (transacción con datasource) |
| 3.5 | **Director**: vuelve a calificar 4.0 → "Aprobar" | Estado = `APROBADO_DIRECTOR`; evaluador asignado automáticamente |

---

## 4. Evaluador (RF-17, RF-18)

| Paso | Acción | Resultado esperado |
|------|--------|--------------------|
| 4.1 | **Evaluador**: `anteproyecto_ver.jsp?id=X` → califica 3.5 → "Eliminar calificación" | Calificación eliminada (transacción con datasource) |
| 4.2 | **Evaluador**: califica 4.0 → "Evaluar (aprobar)" | Estado = `APROBADO_EVALUADOR` |

---

## 5. Coordinación: asignar director en cualquier estado (RF-23, diapositiva)

| Paso | Acción | Resultado esperado |
|------|--------|--------------------|
| 5.1 | **Admin**: crea usuario "Director Dos" (rol DIRECTOR) | Usuario creado, activo |
| 5.2 | **Coordinación**: `coordinacion.jsp?accion=ficha&id=estudiante` → cambiar director a "Director Dos" (anteproyecto en `APROBADO_EVALUADOR`) | `director_id` actualizado al nuevo director; sin bloqueo por estado |
| 5.3 | Verificar en BD | `SELECT director_id FROM anteproyectos WHERE id=X` devuelve el nuevo id |

> **Decisión documentada:** Según la diapositiva del profesor (Rol Coordinación: "Agregar un director a un anteproyecto aprobado"), la coordinación puede asignar/cambiar director en **todos los estados**, incluido `APROBADO_EVALUADOR`.

---

## 6. Entrega final (RF-19, RF-20, RF-21, RF-22)

| Paso | Acción | Resultado esperado |
|------|--------|--------------------|
| 6.1 | **Estudiante**: `anteproyecto_ver.jsp` (estado `APROBADO_EVALUADOR`) → clic "Entregar documento final" | Formulario con título y URL; al enviar → estado `ENTREGA_DOCUMENTO_FINAL` |
| 6.2 | **Estudiante**: `anteproyecto_ver.jsp` → enlace "Consultar / corregir mi entrega final" visible | Enlace presente y funcional |
| 6.3 | **Estudiante**: `entrega_final.jsp?id=X` → ve "Documento entregado" (sin redirección a `anteproyectos.jsp`) | Página carga HTTP 200; muestra título, fecha, estado `ENTREGADO`, enlace al documento |
| 6.4 | **Coordinación (coord2)**: `entrega_final.jsp?id=X` → "Observado (requiere correcciones)" + observaciones | `entrega_final.estado = OBSERVADO`; `revisado_por = coord2_id` |
| 6.5 | **Estudiante**: `entrega_final.jsp?id=X` → ve panel "Corregir y reenviar documento" | Formulario de corrección visible |
| 6.6 | **Estudiante**: envía corrección con nueva URL | `entrega_final.estado = ENTREGADO`; notificación al director |
| 6.7 | **Director/Coordinación**: revisa corrección → "Aprobado → pasa a Revisión Final" | `entrega_final.estado = APROBADO`; anteproyecto → `REVISIÓN_FINAL` |

---

## 7. Formatos de grado (RF-33)

| Paso | Acción | Resultado esperado |
|------|--------|--------------------|
| 7.1 | **Admin/Coord**: `formatos.jsp` → tabla muestra "FDC-124 · Formato de anteproyecto (idea)" | Columna "Archivo": enlace "Abrir formato" con `href="/formatos/FDC-124-Anteproyecto.pdf"` |
| 7.2 | Clic en "Abrir formato" | PDF se abre/descarga (HTTP 200) |
| 7.3 | **Admin**: "Actualizar documento" → ingresar ruta relativa `formatos/nuevo.pdf` | Guardado; enlace sigue funcionando |
| 7.4 | Aviso en página | "Los documentos aquí registrados son **datos de demostración** (plantillas base), no formatos institucionales oficiales." |

---

## 8. Calendario académico (RF-32)

| Paso | Acción | Resultado esperado |
|------|--------|--------------------|
| 8.1 | Cualquier rol: `calendario.jsp` | Lista eventos; aviso "Las fechas iniciales son **datos de demostración**, no el calendario académico oficial." |
| 8.2 | **Admin/Coord**: agregar evento | Evento insertado y visible |

---

## 9. Informes y trámites (RF-29, RF-30, RF-31, RF-25, RF-26, RF-27)

| Paso | Acción (Coord) | Resultado esperado |
|------|----------------|--------------------|
| 9.1 | `informes.jsp?tipo=estudiantes` | Tabla: estudiante, idea, director, evaluador, estado, fechas |
| 9.2 | `informes.jsp?tipo=directores` | Tabla: director, n.º proyectos, estados |
| 9.3 | `informes.jsp?tipo=evaluadores` | Tabla: evaluador, n.º proyectos, estados |
| 9.4 | `tramites.jsp` → crear retiro / prórroga / beneficio | Inserta en BD; coord puede aprobar/rechazar |

---

## 10. Administración de usuarios (RF-04, RF-05, RF-06, RF-07, RF-08, RF-09)

| Paso | Acción (Admin) | Resultado esperado |
|------|----------------|--------------------|
| 10.1 | `usuarios.jsp` → crear usuario rol DIRECTOR | Usuario insertado; hash PBKDF2 |
| 10.2 | Intentar eliminar usuario que **revisó una entrega final** | Bloqueado: "No se puede eliminar: el usuario tiene ... revisiones de entrega final asociados" |
| 10.3 | Eliminar usuario sin dependencias | Eliminado correctamente |

---

## 11. Sustentación (RF-24)

| Paso | Acción (Coord) | Resultado esperado |
|------|----------------|--------------------|
| 11.1 | `sustentacion.jsp` (anteproyecto en `REVISIÓN_FINAL`) → programar fecha/lugar | Registro creado; estado anteproyecto → `SUSTENTACIÓN` |
| 11.2 | Registrar resultado (APROBADO/RECHAZADO + acta URL) | Estado → `FINALIZADO` o vuelve a `REVISIÓN_FINAL` |

---

## 12. Notificaciones (RF-37)

| Paso | Acción | Resultado esperado |
|------|--------|--------------------|
| 12.1 | Cualquier evento (envío, calificación, aprobación, entrega, revisión, trámite) | Fila en `notificaciones` con `evento`, `titulo`, `mensaje`, `correo_log` |

---

## Notas para el documento Word externo

| Sección Word | Qué actualizar | Fuente en repo |
|--------------|----------------|----------------|
| Portada / Título | "Universitaria Tecnológica de Santander (UTS)" | `README.md`, `login.jsp`, `footer.jsp` |
| Requisitos | JDK 17 (no 8) | `README.md`, `pom.xml` |
| Documentos | "Se registran por **URL (enlace)**, no se suben archivos" | `README.md`, `TEST_RESULTS.md` |
| Calendario / Formatos | Marcar como **datos de demostración** | `README.md`, `formatos.jsp`, `calendario.jsp`, `db_tgd_uts.sql` |
| Pruebas | Reemplazar por tabla de `TEST_RESULTS.md` (19/19 APROBADOS) | `TEST_RESULTS.md` |
| Guion | Usar esta tabla (GUION.md) | `GUION.md` |
| Diagramas / Flujo | `BORRADOR → ENVIADO → APROBADO_DIRECTOR → APROBADO_EVALUADOR → ENTREGA_DOCUMENTO_FINAL → REVISIÓN_FINAL → SUSTENTACIÓN → FINALIZADO` | `README.md` |

---

## Checklist de verificación antes de la demo

- [ ] Docker corriendo: `tguts-mysql` y `tguts-tomcat` saludables
- [ ] `http://localhost:18080/` carga `login.jsp`
- [ ] Base de datos inicializada con `db_tgd_uts.sql` (6 usuarios, 2 formatos, 3 eventos)
- [ ] WAR actualizado (`mvn clean package` posterior a últimos cambios)
- [ ] Script E2E pasa: `python pruebas/e2e_tguts.py` → 19/19 APROBADOS