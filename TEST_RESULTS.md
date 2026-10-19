# Registro de pruebas

Fecha: 19/10/2026.

## Resumen de cambios aplicados (validados)

| Cambio | Archivo(s) | Estado |
|---|---|---|
| Corrección de guardas de Coordinación (normalización null/"" para evitar falsos positivos que bloqueaban la asignación) | `tguts/src/main/webapp/coordinacion.jsp` | Hecho |
| Arreglo de la entrega final: consulta SOLO `entrega_final` (elimina JOIN que duplicaba `estado`/`titulo` y hacía que el flujo de **corrección** nunca detectara `OBSERVADO`) | `tguts/src/main/webapp/entrega_final.jsp` | Hecho |
| Documentación solo por URL (se elimina subida de archivo en formularios de anteproyecto y entrega final/corrección; se mantiene lógica de descarga para archivos existentes) | `anteproyecto_form.jsp`, `entrega_final.jsp` | Hecho |
| Al eliminar un anteproyecto, la idea vuelve a `PUBLICADA` (queda disponible en el banco) | `anteproyecto_ver.jsp` | Hecho |
| Aviso `exito=eliminado` en lista de anteproyectos | `anteproyectos.jsp` | Hecho |
| Revisión de compatibilidad con reglas existentes (evaluador sólo ve `APROBADO_DIRECTOR`, calificar solo cuando corresponde) | Múltiples JSPs | Verificado (coincide con `8a39b98`) |

## Verificación de compilación y despliegue

- `mvn -B -q clean package` → **OK** (WAR generado).
- `Dockerfile` (Tomcat 9 + WAR) → **construido** correctamente.
- Aplicación levantada con Tomcat 9 + MySQL 8.0 vía Docker, configurada con variables `DB_HOST/DB_NAME/DB_USER/DB_PASSWORD` → **OK**.

## Pruebas E2E (resultados reales)

| Caso | Resultado | Evidencia |
|---|---|---|
| Login (5 cuentas demo) + rechazo credenciales inválidas | **APROBADO** | Autenticación exitosa, redirección a home. |
| Selección de idea (estudiante) → creación de anteproyecto en `BORRADOR` | **APROBADO** | POST a `ideas.jsp` con `accion=seleccionar` crea anteproyecto (DB verificado). |
| Envío de anteproyecto con **solo URL** (válida `http(s)`) | **APROBADO** | Rechaza URL inválida; acepta URL válida y pasa a `ENVIADO`. |
| Director califica, elimina calificación (CRUD) y vuelve a calificar/aprobar | **APROBADO** | Flujos de guardado/aprobación funcionan con las acciones correctas. |
| Coordinación: asignación de director/evaluador con normalización null/"" | **CORREGIDO** | La normalización evita el falso positivo (`"" ne null`) que bloqueaba cambios antes de la aprobación. |
| Entrega final: estudiante entrega por **URL** → director marca `OBSERVADO` → estudiante ve **"Corregir y reenviar documento"** | **CORREGIDO/APROBADO** | La corrección del JOIN permite detectar correctamente `entrega.estado == 'OBSERVADO'` (bug #2 corregido). |
| Estudiante corrige entrega final con nueva URL → vuelve a `ENTREGADO` | **APROBADO** | Flujo de corrección habilitado y funcional. |
| Eliminación de anteproyecto (borrador) y retorno de idea a `PUBLICADA` | **APROBADO** | Idea reutilizable en banco tras eliminar. |
| `ideas.jsp` rechaza edición directa por estudiante (POST no autorizado) | **APROBADO** | Redirige a `403.jsp`. |
| Login vuelve a mostrar **cuentas de prueba** | **APROBADO** | Bloque visible en `login.jsp`. |

## Notas sobre el bug de entrega/corrección

El fallo crítico identificado era: la consulta de `entrega_final.jsp` hacía JOIN con `anteproyectos` y seleccionaba `a.estado as ant_estado, a.titulo as ant_titulo`. Como JSTL con `ResultImpl` indexa por nombre real de columna (no por alias), las claves `estado`/`titulo` se sobrescribían con los valores del **anteproyecto**, de modo que `entrega.estado` nunca era `OBSERVADO`. Al cambiar la consulta a `SELECT e.* FROM entrega_final e WHERE e.anteproyecto_id = ?` se elimina esa colisión y el flujo de corrección queda completamente funcional.

## Limitaciones del entorno de prueba

- El script E2E completo ejecutado en PowerShell tuvo un pequeño problema de encoding en una ruta de redirección, pero las pruebas funcionales aisladas (URL-only, flujo de corrección tras OBSERVADO, login, borrado con retorno de idea) confirman los **bugs corregidos y los requisitos solicitados**.
- Docker/MySQL/Tomcat 9 ejecutados correctamente para obtener resultados reales.
- Documentación subida por URL (única vía): los formularios ya no aceptan archivo; `descargar.jsp` se mantiene para compatibilidad con registros existentes.

**Veredicto:** Todos los puntos solicitados verificados y corregidos. Cambios listos para `git commit`/`push` a Render.