# Registro de pruebas

Fecha: 19/10/2026.

| Caso | Resultado | Evidencia |
|---|---|---|
| Construcción del proyecto | Aprobado | `mvn -B -q -f tguts/pom.xml package` terminó con código 0. |
| Pruebas automatizadas Maven | Aprobado | `mvn -B -q -f tguts/pom.xml test` terminó con código 0. El proyecto no define pruebas unitarias. |
| Flujo web con Tomcat y MySQL | Pendiente | Requiere una instancia de Tomcat y una base de datos inicializada; no se ejecutó en este entorno. |

## Casos manuales requeridos antes de entregar

1. Estudiante: crear, editar y eliminar un anteproyecto en `BORRADOR` o `RECHAZADO`; comprobar que no se elimina cuando ya está enviado.
2. Director: guardar, modificar y eliminar su calificación mientras el estado sea `ENVIADO`; aprobar solo con calificación.
3. Evaluador: comprobar que no ve ni puede calificar `ENVIADO`; asignarlo y calificarlo únicamente en `APROBADO_DIRECTOR`.
4. Coordinación: comprobar que el director solo se cambia antes de la aprobación y que el evaluador solo se asigna en `APROBADO_DIRECTOR`.
5. Entrega final: marcar una entrega como `OBSERVADO`, reenviar una corrección como estudiante y verificar que vuelve a `ENTREGADO`.
6. Informes: verificar que los totales por director y evaluador incluyen entrega final, revisión final, sustentación y finalizados.
