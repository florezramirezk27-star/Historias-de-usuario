<%-- ==========================================================
     anteproyecto_form.jsp - Estudiante: completa y registra el
     documento del anteproyecto mediante URL (enlace) (RF-14, RF-16, RF-36).
     common/config.jsp expone los campos del formulario en el Map "campos".
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

    <%-- Documento: solo por URL (enlace). Si no se escribe una nueva, se
         conserva la registrada. --%>
    <c:set var="docFinal" value="${not empty campos.documento ? campos.documento : ant.documento}"/>

    <%-- Validación de rol en servidor: el director elegido debe existir, tener
         rol DIRECTOR y estar activo (no confiar solo en el <select>). --%>
    <c:set var="dirOK" value="false"/>
    <c:if test="${not empty campos.director}">
        <sql:query dataSource="${ds}" var="qValDir">
            SELECT 1 FROM usuarios WHERE id = ? AND rol = 'DIRECTOR' AND activo = 1
            <sql:param value="${campos.director}"/>
        </sql:query>
        <c:set var="dirOK" value="${qValDir.rowCount gt 0}"/>
    </c:if>

    <c:choose>
        <c:when test="${empty campos.titulo}">
            <c:set var="error" value="El título del anteproyecto es obligatorio."/>
        </c:when>
        <c:when test="${empty campos.director}">
            <c:set var="error" value="Debes seleccionar al director."/>
        </c:when>
        <c:when test="${not dirOK}">
            <c:set var="error" value="El director seleccionado no es un Director válido o está inactivo."/>
        </c:when>
        <c:when test="${empty docFinal}">
            <c:set var="error" value="Debes indicar la URL (enlace) del documento del anteproyecto."/>
        </c:when>
        <c:when test="${not empty campos.documento
                        && not (fn:startsWith(campos.documento, 'http://') || fn:startsWith(campos.documento, 'https://'))}">
            <c:set var="error" value="La URL del documento debe comenzar por http:// o https://."/>
        </c:when>
        <c:otherwise>
            <%-- Transacción: el cambio de estado y la notificación van juntos.
                 La guarda de estado evita reenviar un anteproyecto ya enviado. --%>
            <sql:transaction dataSource="${ds}">
                <sql:update var="filasAnt">
                    UPDATE anteproyectos
                    SET titulo = ?, director_id = ?, documento = ?, estado = 'ENVIADO'
                    WHERE id = ? AND estudiante_id = ? AND estado IN ('BORRADOR','RECHAZADO')
                    <sql:param value="${campos.titulo}"/>
                    <sql:param value="${campos.director}"/>
                    <sql:param value="${docFinal}"/>
                    <sql:param value="${ant.id}"/>
                    <sql:param value="${yo.id}"/>
                </sql:update>

                <c:if test="${filasAnt gt 0}">
                    <%-- Notificación automática al director (RF-37) --%>
                    <sql:update>
                        INSERT INTO notificaciones (usuario_id, titulo, mensaje, evento, correo_log)
                        SELECT director_id,
                               'Anteproyecto enviado',
                               CONCAT('El estudiante envió el anteproyecto: ', titulo, '. Espera tu revisión.'),
                               'ANTEPROYECTO_ENVIADO',
                               CONCAT('Correo a ', (SELECT email FROM usuarios u WHERE u.id = anteproyectos.director_id),
                                      ' (SMTP pendiente)')
                        FROM anteproyectos
                        WHERE id = ?
                        <sql:param value="${ant.id}"/>
                    </sql:update>
                </c:if>
            </sql:transaction>

            <c:choose>
                <c:when test="${filasAnt gt 0}">
                    <c:redirect url="anteproyectos.jsp?exito=enviado"/>
                </c:when>
                <c:otherwise>
                    <c:set var="error" value="El anteproyecto ya no está en un estado editable."/>
                </c:otherwise>
            </c:choose>
        </c:otherwise>
    </c:choose>
</c:if>

<%-- ===== Datos para el formulario ===== --%>
<sql:query dataSource="${ds}" var="qDirectores">
    SELECT id, nombre FROM usuarios
    WHERE rol = 'DIRECTOR' AND activo = 1
    ORDER BY nombre
</sql:query>

<c:set var="vTitulo" value="${not empty campos.titulo ? campos.titulo : ant.titulo}"/>
<c:set var="dirSel" value="${not empty campos.director ? campos.director : ant.director_id}"/>

<%@ include file="common/header.jsp" %>

<h1>Mi anteproyecto</h1>
<p class="subtitulo">Completa la información y adjunta el enlace (URL) del documento (RF-14, RF-16).</p>

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

        <label for="documento">URL del documento (enlace a Drive, OneDrive, etc.)</label>
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
                    <c:when test="${fn:startsWith(ant.documento, 'http://') || fn:startsWith(ant.documento, 'https://')}">
                        <a class="enlace-doc" href="${fn:escapeXml(ant.documento)}" target="_blank" rel="noopener">Abrir enlace</a>
                    </c:when>
                    <c:otherwise>
                        <c:url value="/descargar.jsp" var="docUrl">
                            <c:param name="f" value="${ant.documento}"/>
                        </c:url>
                        <a class="enlace-doc" href="${docUrl}" target="_blank" rel="noopener">Ver archivo</a>
                    </c:otherwise>
                </c:choose>
            </p>
        </c:if>

        <button class="btn btn-verde" type="submit">Guardar y enviar al director</button>
        <a class="btn btn-gris" href="anteproyectos.jsp">Volver</a>
    </form>
</div>

<%@ include file="common/footer.jsp" %>
