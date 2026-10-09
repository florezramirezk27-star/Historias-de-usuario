<%-- ==========================================================
     entrega_final.jsp - Entrega del documento final
     Flujo: tras APROBADO_EVALUADOR → ENTREGA_DOCUMENTO_FINAL
     Roles:
       - Estudiante: registra la URL del documento final (RF-XX)
       - Director/Coordinación: revisan y aprueban/observan
       - Evaluador: consulta
     Página 100% JSTL, sin scriptlets.
     ========================================================== --%>
<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ include file="common/config.jsp" %>
<%@ include file="common/guard.jsp" %>

<c:if test="${empty param.id}">
    <c:redirect url="anteproyectos.jsp"/>
</c:if>

<%-- Primero: verificar acceso al anteproyecto --%>
<c:choose>
    <c:when test="${rol eq 'ESTUDIANTE'}">
        <sql:query dataSource="${ds}" var="qAntAcceso">
            SELECT * FROM anteproyectos WHERE id = ? AND estudiante_id = ?
            <sql:param value="${param.id}"/>
            <sql:param value="${yo.id}"/>
        </sql:query>
    </c:when>
    <c:when test="${rol eq 'DIRECTOR'}">
        <sql:query dataSource="${ds}" var="qAntAcceso">
            SELECT * FROM anteproyectos WHERE id = ? AND director_id = ?
            <sql:param value="${param.id}"/>
            <sql:param value="${yo.id}"/>
        </sql:query>
    </c:when>
    <c:when test="${rol eq 'EVALUADOR'}">
        <sql:query dataSource="${ds}" var="qAntAcceso">
            SELECT * FROM anteproyectos WHERE id = ? AND evaluador_id = ?
            <sql:param value="${param.id}"/>
            <sql:param value="${yo.id}"/>
        </sql:query>
    </c:when>
    <c:otherwise>
        <sql:query dataSource="${ds}" var="qAntAcceso">
            SELECT * FROM anteproyectos WHERE id = ?
            <sql:param value="${param.id}"/>
        </sql:query>
    </c:otherwise>
</c:choose>

<c:if test="${qAntAcceso.rowCount eq 0}">
    <c:redirect url="anteproyectos.jsp"/>
</c:if>
<c:set var="ant" value="${qAntAcceso.rows[0]}"/>

<%-- Segundo: buscar entrega si existe --%>
<sql:query dataSource="${ds}" var="qEntrega">
    SELECT e.*, a.estado as ant_estado, a.titulo as ant_titulo
    FROM entrega_final e
    JOIN anteproyectos a ON a.id = e.anteproyecto_id
    WHERE e.anteproyecto_id = ?
    <sql:param value="${param.id}"/>
</sql:query>
<c:set var="entrega" value="${qEntrega.rowCount gt 0 ? qEntrega.rows[0] : null}"/>

<%-- Estudiante solo puede acceder si el anteproyecto está en APROBADO_EVALUADOR y no hay entrega --%>
<c:if test="${rol eq 'ESTUDIANTE' && (ant.estado ne 'APROBADO_EVALUADOR' || not empty entrega)}">
    <c:redirect url="anteproyectos.jsp"/>
</c:if>

<%-- Procesar POST crear entrega (estudiante registra URL) --%>
<c:if test="${pageContext.request.method eq 'POST' && param.accion eq 'crear'}">
    <%@ include file="common/verify_csrf.jsp" %>
    <c:choose>
        <c:when test="${empty param.titulo}"><c:set var="error" value="El título es obligatorio."/></c:when>
        <c:when test="${empty param.documento}"><c:set var="error" value="Debes indicar la URL del documento final."/></c:when>
        <c:when test="${not (fn:startsWith(param.documento, 'http://') || fn:startsWith(param.documento, 'https://'))}">
            <c:set var="error" value="La URL del documento final debe comenzar por http:// o https://."/>
        </c:when>
        <c:otherwise>
            <sql:update dataSource="${ds}">
                INSERT INTO entrega_final (anteproyecto_id, titulo, documento, estado)
                VALUES (?, ?, ?, 'ENTREGADO')
                <sql:param value="${param.id}"/>
                <sql:param value="${param.titulo}"/>
                <sql:param value="${param.documento}"/>
            </sql:update>
            <sql:update dataSource="${ds}">
                UPDATE anteproyectos SET estado = 'ENTREGA_DOCUMENTO_FINAL' WHERE id = ?
                <sql:param value="${param.id}"/>
            </sql:update>
            <sql:update dataSource="${ds}">
                INSERT INTO notificaciones (usuario_id, titulo, mensaje, evento, correo_log)
                SELECT director_id, 'Documento final entregado',
                       CONCAT('El estudiante entregó el documento final: ', ?, '.'),
                       'ENTREGA_FINAL', CONCAT('Correo a ', email, ' (SMTP pendiente)')
                FROM anteproyectos a JOIN usuarios u ON u.id = a.director_id
                WHERE a.id = ?
                <sql:param value="${param.titulo}"/>
                <sql:param value="${param.id}"/>
            </sql:update>
            <c:redirect url="entrega_final.jsp?id=${param.id}&exito=entregado"/>
        </c:otherwise>
    </c:choose>
</c:if>

<%-- Procesar POST revisar (director/coordinación) --%>
<c:if test="${pageContext.request.method eq 'POST' && param.accion eq 'revisar'}">
    <%@ include file="common/verify_csrf.jsp" %>
    <c:if test="${rol ne 'ADMIN' && rol ne 'COORDINACION' && rol ne 'DIRECTOR'}">
        <c:redirect url="403.jsp"/>
    </c:if>
    <c:choose>
        <c:when test="${empty param.estado_nuevo || empty param.entrega_id}">
            <c:set var="error" value="Datos incompletos."/>
        </c:when>
        <c:otherwise>
            <sql:update dataSource="${ds}">
                UPDATE entrega_final
                SET estado = ?, observaciones = ?, revisado_por = ?
                WHERE id = ?
                <sql:param value="${param.estado_nuevo}"/>
                <sql:param value="${param.observaciones}"/>
                <sql:param value="${yo.id}"/>
                <sql:param value="${param.entrega_id}"/>
            </sql:update>
            <c:if test="${param.estado_nuevo eq 'APROBADO'}">
                <sql:update dataSource="${ds}">
                    UPDATE anteproyectos SET estado = 'REVISIÓN_FINAL' WHERE id = ?
                    <sql:param value="${param.id}"/>
                </sql:update>
            </c:if>
            <sql:update dataSource="${ds}">
                INSERT INTO notificaciones (usuario_id, titulo, mensaje, evento, correo_log)
                SELECT estudiante_id, 'Revisión del documento final',
                       CONCAT('Tu documento final fue ', LOWER(?), '. Observaciones: ', ?),
                       'REVISION_FINAL', CONCAT('Correo a ', email, ' (SMTP pendiente)')
                FROM anteproyectos a JOIN usuarios u ON u.id = a.estudiante_id
                WHERE a.id = ?
                <sql:param value="${param.estado_nuevo}"/>
                <sql:param value="${param.observaciones}"/>
                <sql:param value="${param.id}"/>
            </sql:update>
            <c:redirect url="entrega_final.jsp?id=${param.id}&exito=revisado"/>
        </c:otherwise>
    </c:choose>
</c:if>

<%@ include file="common/header.jsp" %>

<h1>Entrega del documento final</h1>
<p class="subtitulo">Anteproyecto: <c:out value="${ant.ant_titulo}"/> — Estado: <c:set var="est" value="${ant.ant_estado}"/><span class="estado estado-${est}"><%@ include file="common/estado.jsp" %></span></p>

<c:if test="${param.exito eq 'entregado'}">
    <div class="aviso aviso-ok">Documento final entregado. El director ha sido notificado para su revisión.</div>
</c:if>
<c:if test="${param.exito eq 'revisado'}">
    <div class="aviso aviso-ok">Revisión registrada. El estudiante ha sido notificado.</div>
</c:if>
<c:if test="${not empty error}">
    <div class="aviso aviso-error"><c:out value="${error}"/></div>
</c:if>

<c:choose>
    <c:when test="${empty entrega}">
        <c:if test="${rol eq 'ESTUDIANTE'}">
            <div class="panel">
                <h2 style="margin-top:0">Entregar documento final</h2>
                <form method="post" action="entrega_final.jsp?id=${param.id}">
                    <input type="hidden" name="csrf_token" value="${csrfToken}">
                    <input type="hidden" name="accion" value="crear">
                    <label for="titulo">Título del trabajo de grado</label>
                    <input type="text" id="titulo" name="titulo" required maxlength="200"
                           value="${fn:escapeXml(ant.ant_titulo)}">
                    <label for="documento">URL del documento final</label>
                    <div class="campo-url">
                        <span class="icono-url" aria-hidden="true">
                            <svg xmlns="http://www.w3.org/2000/svg" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/></svg>
                        </span>
                        <input type="url" id="documento" name="documento" required
                               placeholder="https://drive.google.com/...">
                    </div>
                    <button class="btn btn-verde" type="submit">Entregar documento final</button>
                    <a class="btn btn-gris" href="anteproyectos.jsp">Volver</a>
                </form>
            </div>
        </c:if>
        <c:if test="${rol ne 'ESTUDIANTE'}">
            <div class="aviso aviso-info">Este anteproyecto aún no tiene documento final entregado.</div>
        </c:if>
    </c:when>

    <c:otherwise>
        <div class="panel">
            <h2 style="margin-top:0">Documento entregado</h2>
            <p class="dato"><b>Título:</b> <c:out value="${entrega.titulo}"/></p>
            <p class="dato"><b>Fecha de entrega:</b> <fmt:formatDate value="${entrega.fecha_entrega}" pattern="dd/MM/yyyy HH:mm"/></p>
            <p class="dato"><b>Estado:</b>
                <c:set var="est" value="${entrega.estado}"/>
                <span class="estado estado-${entrega.estado}"><c:out value="${est}"/></span>
            </p>
            <p class="dato"><b>Documento:</b>
                <a class="enlace-doc" href="${entrega.documento}" target="_blank">Abrir documento</a>
            </p>
            <c:if test="${not empty entrega.observaciones}">
                <p class="dato"><b>Observaciones:</b> <c:out value="${entrega.observaciones}"/></p>
            </c:if>
        </div>

        <c:if test="${rol eq 'ADMIN' || rol eq 'COORDINACION' || rol eq 'DIRECTOR'}">
            <div class="panel">
                <h2 style="margin-top:0">Revisar documento final</h2>
                <form method="post" action="entrega_final.jsp?id=${param.id}">
                    <input type="hidden" name="csrf_token" value="${csrfToken}">
                    <input type="hidden" name="accion" value="revisar">
                    <input type="hidden" name="entrega_id" value="${entrega.id}">
                    <label for="estado_nuevo">Nuevo estado</label>
                    <select id="estado_nuevo" name="estado_nuevo" required>
                        <option value="EN_REVISION" ${entrega.estado eq 'EN_REVISION' ? 'selected' : ''}>En revisión</option>
                        <option value="OBSERVADO" ${entrega.estado eq 'OBSERVADO' ? 'selected' : ''}>Observado (requiere correcciones)</option>
                        <option value="APROBADO" ${entrega.estado eq 'APROBADO' ? 'selected' : ''}>Aprobado → pasa a Revisión Final</option>
                    </select>
                    <label for="observaciones">Observaciones</label>
                    <textarea id="observaciones" name="observaciones" rows="4"
                              placeholder="Comentarios para el estudiante...">${fn:escapeXml(entrega.observaciones)}</textarea>
                    <button class="btn btn-verde" type="submit">Guardar revisión</button>
                </form>
            </div>
        </c:if>
    </c:otherwise>
</c:choose>

<%@ include file="common/footer.jsp" %>