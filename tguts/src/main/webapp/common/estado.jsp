<%-- estado.jsp - Etiqueta legible de un estado.
     Uso: <c:set var="est" value="${fila.estado}"/> y luego este include. --%>
<%@ page pageEncoding="UTF-8" %>
<c:choose>
    <c:when test="${est eq 'BORRADOR'}">Borrador</c:when>
    <c:when test="${est eq 'ENVIADO'}">Enviado / En revisión</c:when>
    <c:when test="${est eq 'APROBADO_DIRECTOR'}">Aprobado por el director</c:when>
    <c:when test="${est eq 'APROBADO_EVALUADOR'}">Aprobado por el evaluador</c:when>
    <c:when test="${est eq 'RECHAZADO'}">Rechazado</c:when>
    <c:when test="${est eq 'REPROBADO'}">Reprobado (definitivo)</c:when>
    <c:when test="${est eq 'ENTREGA_DOCUMENTO_FINAL'}">Entrega documento final</c:when>
    <c:when test="${est eq 'REVISIÓN_FINAL'}">Revisión final</c:when>
    <c:when test="${est eq 'SUSTENTACIÓN'}">Sustentación</c:when>
    <c:when test="${est eq 'FINALIZADO'}">Finalizado</c:when>
    <c:when test="${est eq 'PUBLICADA'}">Publicada</c:when>
    <c:when test="${est eq 'SELECCIONADA'}">Seleccionada</c:when>
    <c:when test="${est eq 'CERRADA'}">Cerrada</c:when>
    <c:when test="${est eq 'PENDIENTE'}">Pendiente</c:when>
    <c:when test="${est eq 'APROBADO'}">Aprobado</c:when>
    <c:when test="${est eq 'ENTREGADO'}">Entregado</c:when>
    <c:when test="${est eq 'EN_REVISION'}">En revisión</c:when>
    <c:when test="${est eq 'OBSERVADO'}">Observado</c:when>
    <c:otherwise><c:out value="${est}"/></c:otherwise>
</c:choose>
