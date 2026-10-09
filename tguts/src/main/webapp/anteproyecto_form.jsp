<%-- ==========================================================
     anteproyecto_form.jsp - Estudiante: completa y registra la
     URL del documento del anteproyecto (RF-14, RF-16, RF-36)
     Página 100% JSTL, sin scriptlets.
     ========================================================== --%>
<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ include file="common/config.jsp" %>
<%@ include file="common/guard.jsp" %>

<%-- Solo el estudiante dueño del anteproyecto --%>
<c:if test="${rol ne 'ESTUDIANTE'}">
    <c:redirect url="403.jsp"/>
</c:if>
<c:if test="${empty param.id}">
    <c:redirect url="anteproyectos.jsp"/>
</c:if>

<%-- Catálogos para resolver nombres (el mapa de JSTL usa el nombre
     REAL de la columna, no el alias SQL) --%>
<sql:query dataSource="${ds}" var="qUsuarios">
    SELECT id, nombre, codigo FROM usuarios ORDER BY nombre
</sql:query>
<sql:query dataSource="${ds}" var="qIdeas">
    SELECT id, titulo FROM ideas ORDER BY id
</sql:query>

<%-- Cargar el anteproyecto propio (RF-15) --%>
<sql:query dataSource="${ds}" var="qAnt">
    SELECT * FROM anteproyectos
    WHERE id = ? AND estudiante_id = ?
    <sql:param value="${param.id}"/>
    <sql:param value="${yo.id}"/>
</sql:query>

<c:choose>
    <c:when test="${qAnt.rowCount eq 0}">
        <c:redirect url="anteproyectos.jsp"/>
    </c:when>
    <c:when test="${qAnt.rows[0].estado ne 'BORRADOR' && qAnt.rows[0].estado ne 'RECHAZADO'}">
        <%-- Ya fue enviado: solo lectura --%>
        <c:redirect url="anteproyecto_ver.jsp?id=${param.id}"/>
    </c:when>
</c:choose>
<c:set var="ant" value="${qAnt.rows[0]}"/>

<%-- Resolver nombres asociados --%>
<c:set var="buscarId" value="${ant.director_id}"/>
<%@ include file="common/resolver.jsp" %>
<c:set var="dirNombre" value="${empty resNom ? 'Por asignar' : resNom}"/>
<c:set var="buscarId" value="${ant.evaluador_id}"/>
<%@ include file="common/resolver.jsp" %>
<c:set var="evalNombre" value="${empty resNom ? 'Por asignar (lo asigna coordinación)' : resNom}"/>
<c:set var="buscarIdeaId" value="${ant.idea_id}"/>
<%@ include file="common/resolver_idea.jsp" %>
<c:set var="ideaTitulo" value="${empty resIdea ? '—' : resIdea}"/>

<%-- ===== Proceso del formulario (solo si hubo envío) ===== --%>
<c:if test="${pageContext.request.method eq 'POST'}">
    <%@ include file="common/verify_csrf.jsp" %>
    <c:choose>
        <c:when test="${empty param.titulo}">
            <c:set var="error" value="El título del anteproyecto es obligatorio."/>
        </c:when>
        <c:when test="${empty param.director}">
            <c:set var="error" value="Debes seleccionar al director."/>
        </c:when>
        <c:when test="${empty param.documento && empty ant.documento}">
            <c:set var="error" value="Debes indicar la URL del documento del anteproyecto."/>
        </c:when>
        <c:when test="${not empty param.documento && not (fn:startsWith(param.documento, 'http://') || fn:startsWith(param.documento, 'https://'))}">
            <c:set var="error" value="La URL del documento debe comenzar por http:// o https://."/>
        </c:when>
        <c:otherwise>
            <c:choose>
                <%-- Con URL nueva --%>
                <c:when test="${not empty param.documento}">
                    <sql:update dataSource="${ds}">
                        UPDATE anteproyectos
                        SET titulo = ?, director_id = ?, documento = ?, estado = 'ENVIADO'
                        WHERE id = ? AND estudiante_id = ?
                        <sql:param value="${param.titulo}"/>
                        <sql:param value="${param.director}"/>
                        <sql:param value="${param.documento}"/>
                        <sql:param value="${param.id}"/>
                        <sql:param value="${yo.id}"/>
                    </sql:update>
                </c:when>
                <%-- Se conserva el documento/anterior enlace --%>
                <c:otherwise>
                    <sql:update dataSource="${ds}">
                        UPDATE anteproyectos
                        SET titulo = ?, director_id = ?, estado = 'ENVIADO'
                        WHERE id = ? AND estudiante_id = ?
                        <sql:param value="${param.titulo}"/>
                        <sql:param value="${param.director}"/>
                        <sql:param value="${param.id}"/>
                        <sql:param value="${yo.id}"/>
                    </sql:update>
                </c:otherwise>
            </c:choose>

            <%-- Notificación automática al director (RF-37) --%>
            <sql:update dataSource="${ds}">
                INSERT INTO notificaciones (usuario_id, titulo, mensaje, evento, correo_log)
                SELECT director_id,
                       'Anteproyecto enviado',
                       CONCAT('El estudiante envió el anteproyecto: ', titulo, '. Espera tu revisión.'),
                       'ANTEPROYECTO_ENVIADO',
                       CONCAT('Correo a ', (SELECT email FROM usuarios u WHERE u.id = anteproyectos.director_id),
                              ' (SMTP pendiente)')
                FROM anteproyectos
                WHERE id = ?
                <sql:param value="${param.id}"/>
            </sql:update>

            <c:redirect url="anteproyectos.jsp?exito=enviado"/>
        </c:otherwise>
    </c:choose>
</c:if>

<%-- ===== Datos para el formulario ===== --%>
<sql:query dataSource="${ds}" var="qDirectores">
    SELECT id, nombre FROM usuarios
    WHERE rol = 'DIRECTOR' AND activo = 1
    ORDER BY nombre
</sql:query>

<c:set var="vTitulo" value="${not empty param.titulo ? param.titulo : ant.titulo}"/>
<c:set var="dirSel" value="${not empty param.director ? param.director : ant.director_id}"/>

<%@ include file="common/header.jsp" %>

<h1>Mi anteproyecto</h1>
<p class="subtitulo">Completa la información y registra la URL del documento (RF-14, RF-16).</p>

<c:if test="${not empty error}">
    <div class="aviso aviso-error"><c:out value="${error}"/></div>
</c:if>
<c:if test="${ant.estado eq 'RECHAZADO'}">
    <div class="aviso aviso-info">
        Tu anteproyecto fue rechazado. Corrige lo indicado por el director y vuelve a enviarlo.
    </div>
</c:if>

<div class="panel">
    <h2 style="margin-top:0">Información del anteproyecto</h2>

    <p class="dato"><b>Estudiante:</b> <c:out value="${yo.nombre}"/></p>
    <p class="dato"><b>Código:</b> <c:out value="${empty yo.codigo ? '—' : yo.codigo}"/></p>
    <p class="dato"><b>Idea seleccionada:</b> <c:out value="${ideaTitulo}"/></p>
    <p class="dato"><b>Director:</b> <c:out value="${dirNombre}"/></p>
    <p class="dato"><b>Evaluador:</b> <c:out value="${evalNombre}"/></p>

    <form method="post" action="anteproyecto_form.jsp?id=${ant.id}">
        <input type="hidden" name="csrf_token" value="${csrfToken}">
        <label for="titulo">Título del anteproyecto</label>
        <input type="text" id="titulo" name="titulo" required maxlength="200"
               value="${fn:escapeXml(vTitulo)}">

        <label for="director">Director</label>
        <select id="director" name="director" required>
            <c:forEach items="${qDirectores.rows}" var="d">
                <option value="${d.id}" ${dirSel eq d.id ? 'selected' : ''}>
                    <c:out value="${d.nombre}"/>
                </option>
            </c:forEach>
        </select>

        <label for="documento">URL del documento del anteproyecto</label>
        <div class="campo-url">
            <span class="icono-url" aria-hidden="true">
                <svg xmlns="http://www.w3.org/2000/svg" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/></svg>
            </span>
            <input type="url" id="documento" name="documento"
                   placeholder="https://drive.google.com/...">
        </div>

        <c:if test="${not empty ant.documento}">
            <p class="dato" style="margin-top:10px">
                <b>Documento actual:</b>
                <c:choose>
                    <c:when test="${fn:startsWith(ant.documento, 'http')}">
                        <a class="enlace-doc" href="${ant.documento}" target="_blank">Abrir enlace</a>
                    </c:when>
                    <c:when test="${fn:contains(ant.documento, '/')}">
                        <c:url value="${ant.documento}" var="docUrl"/>
                        <a class="enlace-doc" href="${docUrl}" target="_blank">Ver archivo</a>
                    </c:when>
                    <c:otherwise>
                        <c:url value="/uploads/${ant.documento}" var="docUrl"/>
                        <a class="enlace-doc" href="${docUrl}" target="_blank">Ver archivo</a>
                    </c:otherwise>
                </c:choose>
            </p>
        </c:if>

        <button class="btn btn-verde" type="submit">Guardar y enviar al director</button>
        <a class="btn btn-gris" href="anteproyectos.jsp">Volver</a>
    </form>
</div>

<%@ include file="common/footer.jsp" %>