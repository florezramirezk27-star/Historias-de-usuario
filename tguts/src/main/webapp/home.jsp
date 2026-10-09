<%-- ==========================================================
     home.jsp - Panel principal según el rol (RF-03)
     ========================================================== --%>
<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ include file="common/config.jsp" %>
<%@ include file="common/guard.jsp" %>

<%-- Contadores del sistema --%>
<sql:query dataSource="${ds}" var="qAntTotal">
    SELECT COUNT(*) AS n FROM anteproyectos
</sql:query>
<sql:query dataSource="${ds}" var="qAntAprob">
    SELECT COUNT(*) AS n FROM anteproyectos WHERE estado = 'APROBADO_EVALUADOR'
</sql:query>
<sql:query dataSource="${ds}" var="qIdeasPub">
    SELECT COUNT(*) AS n FROM ideas WHERE estado = 'PUBLICADA'
</sql:query>
<sql:query dataSource="${ds}" var="qTramPend">
    SELECT COUNT(*) AS n FROM tramites WHERE estado = 'PENDIENTE'
</sql:query>

<c:if test="${rol eq 'ADMIN'}">
    <sql:query dataSource="${ds}" var="qUsuarios">
        SELECT COUNT(*) AS n FROM usuarios WHERE activo = 1
    </sql:query>
    <sql:query dataSource="${ds}" var="qEstudiantes">
        SELECT COUNT(*) AS n FROM usuarios WHERE rol = 'ESTUDIANTE' AND activo = 1
    </sql:query>
</c:if>

<c:if test="${rol eq 'COORDINACION'}">
    <sql:query dataSource="${ds}" var="qEstudiantes">
        SELECT COUNT(*) AS n FROM usuarios WHERE rol = 'ESTUDIANTE' AND activo = 1
    </sql:query>
    <sql:query dataSource="${ds}" var="qDirPend">
        SELECT COUNT(*) AS n FROM anteproyectos WHERE evaluador_id IS NULL AND estado = 'APROBADO_DIRECTOR'
    </sql:query>
</c:if>

<c:if test="${rol eq 'DIRECTOR'}">
    <sql:query dataSource="${ds}" var="qMisPend">
        SELECT COUNT(*) AS n FROM anteproyectos WHERE director_id = ? AND estado = 'ENVIADO'
        <sql:param value="${yo.id}"/>
    </sql:query>
    <sql:query dataSource="${ds}" var="qMisTotal">
        SELECT COUNT(*) AS n FROM anteproyectos WHERE director_id = ?
        <sql:param value="${yo.id}"/>
    </sql:query>
</c:if>

<c:if test="${rol eq 'EVALUADOR'}">
    <sql:query dataSource="${ds}" var="qMisPend">
        SELECT COUNT(*) AS n FROM anteproyectos WHERE evaluador_id = ? AND estado = 'APROBADO_DIRECTOR'
        <sql:param value="${yo.id}"/>
    </sql:query>
    <sql:query dataSource="${ds}" var="qMisTotal">
        SELECT COUNT(*) AS n FROM anteproyectos WHERE evaluador_id = ?
        <sql:param value="${yo.id}"/>
    </sql:query>
</c:if>

<c:if test="${rol eq 'ESTUDIANTE'}">
    <sql:query dataSource="${ds}" var="qMiAnt">
        SELECT a.*, i.titulo AS idea_titulo
        FROM anteproyectos a LEFT JOIN ideas i ON i.id = a.idea_id
        WHERE a.estudiante_id = ?
        <sql:param value="${yo.id}"/>
    </sql:query>
</c:if>

<%@ include file="common/header.jsp" %>

<h1>Panel · <c:out value="${sessionScope.rolNombre}"/></h1>
<p class="subtitulo">Bienvenido(a) <c:out value="${yo.nombre}"/>. Este es el estado del Sistema de Trabajos de Grado.</p>

<%-- ================= TARJETAS SEGÚN ROL ================= --%>
<div class="tarjetas">
    <c:choose>
        <c:when test="${rol eq 'ADMIN'}">
            <div class="tarjeta"><div class="numero"><c:out value="${qUsuarios.rows[0].n}"/></div><div class="etiqueta">Usuarios activos</div></div>
            <div class="tarjeta"><div class="numero"><c:out value="${qEstudiantes.rows[0].n}"/></div><div class="etiqueta">Estudiantes</div></div>
            <div class="tarjeta"><div class="numero"><c:out value="${qAntTotal.rows[0].n}"/></div><div class="etiqueta">Anteproyectos</div></div>
            <div class="tarjeta"><div class="numero"><c:out value="${qTramPend.rows[0].n}"/></div><div class="etiqueta">Trámites pendientes</div></div>
        </c:when>

        <c:when test="${rol eq 'COORDINACION'}">
            <div class="tarjeta"><div class="numero"><c:out value="${qEstudiantes.rows[0].n}"/></div><div class="etiqueta">Estudiantes</div></div>
            <div class="tarjeta"><div class="numero"><c:out value="${qAntTotal.rows[0].n}"/></div><div class="etiqueta">Anteproyectos</div></div>
            <div class="tarjeta"><div class="numero"><c:out value="${qDirPend.rows[0].n}"/></div><div class="etiqueta">Sin evaluador asignado</div></div>
            <div class="tarjeta"><div class="numero"><c:out value="${qTramPend.rows[0].n}"/></div><div class="etiqueta">Trámites pendientes</div></div>
        </c:when>

        <c:when test="${rol eq 'DIRECTOR'}">
            <div class="tarjeta"><div class="numero"><c:out value="${qMisPend.rows[0].n}"/></div><div class="etiqueta">Pendientes por calificar</div></div>
            <div class="tarjeta"><div class="numero"><c:out value="${qMisTotal.rows[0].n}"/></div><div class="etiqueta">Mis anteproyectos</div></div>
            <div class="tarjeta"><div class="numero"><c:out value="${qIdeasPub.rows[0].n}"/></div><div class="etiqueta">Ideas publicadas</div></div>
        </c:when>

        <c:when test="${rol eq 'EVALUADOR'}">
            <div class="tarjeta"><div class="numero"><c:out value="${qMisPend.rows[0].n}"/></div><div class="etiqueta">Pendientes por aprobar</div></div>
            <div class="tarjeta"><div class="numero"><c:out value="${qMisTotal.rows[0].n}"/></div><div class="etiqueta">Mis anteproyectos</div></div>
            <div class="tarjeta"><div class="numero"><c:out value="${qAntAprob.rows[0].n}"/></div><div class="etiqueta">Aprobados (sistema)</div></div>
        </c:when>

        <c:when test="${rol eq 'ESTUDIANTE'}">
            <div class="tarjeta">
                <div class="numero">
                    <c:choose>
                        <c:when test="${empty qMiAnt.rows}">—</c:when>
                        <c:otherwise>
                            <c:set var="est" value="${qMiAnt.rows[0].estado}"/>
                            <span class="estado estado-${est}"><%@ include file="common/estado.jsp" %></span>
                        </c:otherwise>
                    </c:choose>
                </div>
                <div class="etiqueta">Estado de mi anteproyecto</div>
            </div>
            <div class="tarjeta"><div class="numero"><c:out value="${qIdeasPub.rows[0].n}"/></div><div class="etiqueta">Ideas disponibles</div></div>
            <div class="tarjeta"><div class="numero"><c:out value="${qNoLeidas.rows[0].n}"/></div><div class="etiqueta">Notificaciones sin leer</div></div>
            <div class="tarjeta"><div class="numero"><c:out value="${qTramPend.rows[0].n}"/></div><div class="etiqueta">Trámites del sistema</div></div>
        </c:when>
    </c:choose>
</div>

<%-- ================= ACCESOS RÁPIDOS ================= --%>
<div class="panel">
    <h2 style="margin-top:0">Accesos rápidos</h2>
    <c:choose>
        <c:when test="${rol eq 'ADMIN'}">
            <a class="btn" href="usuarios.jsp">Crear usuario</a>
            <a class="btn btn-gris" href="ideas.jsp">Banco de ideas</a>
            <a class="btn btn-gris" href="coordinacion.jsp">Buscar estudiante</a>
        </c:when>
        <c:when test="${rol eq 'COORDINACION'}">
            <a class="btn" href="coordinacion.jsp">Buscar estudiante</a>
            <a class="btn btn-gris" href="informes.jsp">Ver informes</a>
            <a class="btn btn-gris" href="tramites.jsp">Resolver trámites</a>
        </c:when>
        <c:when test="${rol eq 'DIRECTOR'}">
            <a class="btn" href="anteproyectos.jsp">Ver mis anteproyectos</a>
            <a class="btn btn-gris" href="ideas.jsp">Publicar idea</a>
        </c:when>
        <c:when test="${rol eq 'EVALUADOR'}">
            <a class="btn" href="anteproyectos.jsp">Ver anteproyectos aprobados</a>
        </c:when>
        <c:when test="${rol eq 'ESTUDIANTE'}">
            <a class="btn" href="ideas.jsp">Banco de ideas</a>
            <a class="btn btn-gris" href="anteproyectos.jsp">Mi anteproyecto</a>
            <a class="btn btn-gris" href="tramites.jsp">Solicitar trámite</a>
        </c:when>
    </c:choose>
</div>

<%@ include file="common/footer.jsp" %>
