<%-- ==========================================================
     anteproyectos.jsp - Listado de anteproyectos según el rol
       * Estudiante: su anteproyecto (RF-14, RF-15)
       * Director: anteproyectos asignados (RF-17, RF-18)
       * Evaluador: anteproyectos aprobados por el director (RF-21)
       * Coordinación/administrador: todos (RF-28)
     NOTA: JSTL sql:query entrega las columnas con su NOMBRE REAL
     (getColumnName), por eso los nombres asociados se resuelven
     mediante common/resolver.jsp en lugar de alias SQL.
     ========================================================== --%>
<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ include file="common/config.jsp" %>
<%@ include file="common/guard.jsp" %>

<%-- Catálogos para resolver nombres (clave = id real) --%>
<sql:query dataSource="${ds}" var="qUsuarios">
    SELECT id, nombre, codigo FROM usuarios ORDER BY nombre
</sql:query>
<sql:query dataSource="${ds}" var="qIdeas">
    SELECT id, titulo FROM ideas ORDER BY id
</sql:query>

<c:choose>
    <c:when test="${rol eq 'ESTUDIANTE'}">
        <sql:query dataSource="${ds}" var="qLista">
            SELECT * FROM anteproyectos WHERE estudiante_id = ? ORDER BY id DESC
            <sql:param value="${yo.id}"/>
        </sql:query>
    </c:when>
    <c:when test="${rol eq 'DIRECTOR'}">
        <sql:query dataSource="${ds}" var="qLista">
            SELECT * FROM anteproyectos WHERE director_id = ? ORDER BY id DESC
            <sql:param value="${yo.id}"/>
        </sql:query>
    </c:when>
    <c:when test="${rol eq 'EVALUADOR'}">
        <sql:query dataSource="${ds}" var="qLista">
            SELECT * FROM anteproyectos WHERE evaluador_id = ? ORDER BY id DESC
            <sql:param value="${yo.id}"/>
        </sql:query>
    </c:when>
    <c:otherwise>
        <sql:query dataSource="${ds}" var="qLista">
            SELECT * FROM anteproyectos ORDER BY id DESC
        </sql:query>
    </c:otherwise>
</c:choose>

<%@ include file="common/header.jsp" %>

<h1>Anteproyectos</h1>
<p class="subtitulo">
    <c:choose>
        <c:when test="${rol eq 'ESTUDIANTE'}">Tu anteproyecto: selección de la idea, documento y calificación.</c:when>
        <c:when test="${rol eq 'DIRECTOR'}">Anteproyectos asignados a ti como director (RF-17, RF-18).</c:when>
        <c:when test="${rol eq 'EVALUADOR'}">Anteproyectos aprobados por el director para tu evaluación (RF-21).</c:when>
        <c:otherwise>Consulta general de anteproyectos (RF-28).</c:otherwise>
    </c:choose>
</p>

<c:if test="${param.exito eq 'seleccionada'}">
    <div class="aviso aviso-ok">Idea seleccionada. Ahora completa la información y sube el documento de tu anteproyecto.</div>
</c:if>
<c:if test="${param.exito eq 'enviado'}">
    <div class="aviso aviso-ok">Anteproyecto enviado. El director recibió una notificación para su revisión.</div>
</c:if>

<c:choose>
    <%-- Sin registros --%>
    <c:when test="${empty qLista.rows}">
        <div class="panel">
            <c:choose>
                <c:when test="${rol eq 'ESTUDIANTE'}">
                    <p>Aún no tienes un anteproyecto. Para crearlo primero debes elegir una idea del banco.</p>
                    <a class="btn" href="ideas.jsp">Ir al banco de ideas</a>
                </c:when>
                <c:otherwise>
                    <p>No hay anteproyectos asignados por ahora.</p>
                </c:otherwise>
            </c:choose>
        </div>
    </c:when>

    <c:otherwise>
        <div class="panel">
            <table>
                <tr>
                    <th>Estudiante</th>
                    <th>Código</th>
                    <th>Anteproyecto</th>
                    <th>Idea</th>
                    <th>Director</th>
                    <th>Evaluador</th>
                    <th>Estado</th>
                    <th>Acciones</th>
                </tr>
                <c:forEach items="${qLista.rows}" var="a">
                    <c:set var="buscarId" value="${a.estudiante_id}"/>
                    <%@ include file="common/resolver.jsp" %>
                    <c:set var="estNombre" value="${resNom}"/>
                    <c:set var="estCodigo" value="${resCod}"/>
                    <c:set var="buscarId" value="${a.director_id}"/>
                    <%@ include file="common/resolver.jsp" %>
                    <c:set var="dirNombre" value="${empty resNom ? 'Por asignar' : resNom}"/>
                    <c:set var="buscarId" value="${a.evaluador_id}"/>
                    <%@ include file="common/resolver.jsp" %>
                    <c:set var="evalNombre" value="${empty resNom ? 'Por asignar' : resNom}"/>
                    <c:set var="buscarIdeaId" value="${a.idea_id}"/>
                    <%@ include file="common/resolver_idea.jsp" %>
                    <c:set var="ideaTitulo" value="${empty resIdea ? '—' : resIdea}"/>
                    <tr>
                        <td><c:out value="${estNombre}"/></td>
                        <td><c:out value="${empty estCodigo ? '—' : estCodigo}"/></td>
                        <td><c:out value="${a.titulo}"/></td>
                        <td><c:out value="${ideaTitulo}"/></td>
                        <td><c:out value="${dirNombre}"/></td>
                        <td><c:out value="${evalNombre}"/></td>
                        <td>
                            <c:set var="est" value="${a.estado}"/>
                            <span class="estado estado-${est}"><%@ include file="common/estado.jsp" %></span>
                        </td>
                        <td>
                            <a class="btn btn-mini btn-gris" href="anteproyecto_ver.jsp?id=${a.id}">Ver detalle</a>
                            <%-- Acción del evaluador: calificar/aprobar (RF-22, RF-23) --%>
                            <c:if test="${rol eq 'EVALUADOR' && (a.estado eq 'APROBADO_DIRECTOR' || a.estado eq 'ENVIADO')}">
                                <a class="btn btn-mini" href="anteproyecto_ver.jsp?id=${a.id}">Calificar</a>
                            </c:if>
                            <c:if test="${rol eq 'ESTUDIANTE' && (a.estado eq 'BORRADOR' || a.estado eq 'RECHAZADO')}">
                                <a class="btn btn-mini" href="anteproyecto_form.jsp?id=${a.id}">
                                    <c:choose>
                                        <c:when test="${a.estado eq 'RECHAZADO'}">Corregir y reenviar</c:when>
                                        <c:otherwise>Completar y subir documento</c:otherwise>
                                    </c:choose>
                                </a>
                            </c:if>
                        </td>
                    </tr>
                </c:forEach>
            </table>
        </div>
    </c:otherwise>
</c:choose>

<%@ include file="common/footer.jsp" %>