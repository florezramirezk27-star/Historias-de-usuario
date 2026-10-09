<%-- ==========================================================
     notificaciones.jsp - Notificaciones y correos (RF-37)
     El sistema genera una notificación por cada evento relevante
     del proceso; el envío real de correos queda como pendiente
     (SMTP no configurado) y se muestra en cada registro.
     ========================================================== --%>
<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ include file="common/config.jsp" %>
<%@ include file="common/guard.jsp" %>

<%-- ===== Marcar todas como leídas (POST) ===== --%>
<c:if test="${pageContext.request.method eq 'POST' && param.accion eq 'marcar'}">
    <sql:update dataSource="${ds}">
        UPDATE notificaciones SET leido = 1 WHERE usuario_id = ? AND leido = 0
        <sql:param value="${yo.id}"/>
    </sql:update>
    <c:redirect url="notificaciones.jsp?exito=leido"/>
</c:if>

<%-- ===== Notificaciones del usuario =====
     NOTA: 'leido' es TINYINT(1) y MySQL puede entregarlo como Boolean o
     como entero según la configuración; para evitar cualquier error de
     conversión en EL se resuelve como TEXTO con un alias calculado. --%>
<sql:query dataSource="${ds}" var="qNotif">
    SELECT *, IF(leido = 1, 'SI', 'NO') AS leido_txt
    FROM notificaciones
    WHERE usuario_id = ?
    ORDER BY creado_en DESC, id DESC
    LIMIT 100
    <sql:param value="${yo.id}"/>
</sql:query>

<%@ include file="common/header.jsp" %>

<h1>Notificaciones</h1>
<p class="subtitulo">Eventos automáticos del proceso: anteproyectos, calificaciones, trámites y asignaciones (RF-37).</p>

<div class="aviso aviso-info">
    <b>Nota sobre los correos (RF-37):</b> el sistema registra y muestra cada notificación en esta pantalla.
    El envío de correos electrónicos reales está <b>pendiente</b> hasta configurar un servidor SMTP;
    cada registro indica el correo que se enviaría.
</div>

<c:if test="${param.exito eq 'leido'}">
    <div class="aviso aviso-ok">Notificaciones marcadas como leídas.</div>
</c:if>

<div class="panel">
    <form method="post" action="notificaciones.jsp">
        <input type="hidden" name="accion" value="marcar">
        <button class="btn btn-gris" type="submit">Marcar todas como leídas</button>
    </form>

    <table>
        <tr>
            <th>Fecha</th>
            <th>Título</th>
            <th>Mensaje</th>
            <th>Estado</th>
        </tr>
        <c:forEach items="${qNotif.rows}" var="n">
            <tr>
                <td><fmt:formatDate value="${n['creado_en']}" pattern="dd/MM/yyyy HH:mm"/></td>
                <td>
                    <b><c:out value="${n.titulo}"/></b>
                    <br><small>Evento: <c:out value="${n.evento}"/></small>
                </td>
                <td>
                    <c:out value="${n.mensaje}"/>
                    <br><small style="color:#6b7a8c"><c:out value="${n.correo_log}"/></small>
                </td>
                <td>
                    <c:choose>
                        <c:when test="${n.leido_txt eq 'SI'}">Leído</c:when>
                        <c:otherwise><span class="estado estado-ENVIADO">Nuevo</span></c:otherwise>
                    </c:choose>
                </td>
            </tr>
        </c:forEach>
    </table>
    <c:if test="${empty qNotif.rows}">
        <p>No tienes notificaciones por ahora.</p>
    </c:if>
</div>

<%@ include file="common/footer.jsp" %>
