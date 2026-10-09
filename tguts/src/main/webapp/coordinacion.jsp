<%-- ==========================================================
     coordinacion.jsp - Coordinación
       * Buscar estudiante por código o nombre (RF-27)
       * Consultar la información del proyecto/anteproyecto (RF-28)
       * Asignar director y evaluador (RF-26)
     ========================================================== --%>
<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ include file="common/config.jsp" %>
<%@ include file="common/guard.jsp" %>

<c:if test="${rol ne 'ADMIN' && rol ne 'COORDINACION'}">
    <c:redirect url="403.jsp"/>
</c:if>

<%-- ===== Asignar director y evaluador (RF-26, POST) ===== --%>
<c:if test="${pageContext.request.method eq 'POST' && param.accion eq 'asignar'}">
    <%@ include file="common/verify_csrf.jsp" %>

    <%-- Validación de rol en servidor: el director DEBE ser un usuario con rol=DIRECTOR activo --%>
    <c:set var="dirOK" value="true"/>
    <c:if test="${not empty param.director}">
        <sql:query dataSource="${ds}" var="qValDir">
            SELECT 1 FROM usuarios WHERE id = ? AND rol = 'DIRECTOR' AND activo = 1
            <sql:param value="${param.director}"/>
        </sql:query>
        <c:set var="dirOK" value="${qValDir.rowCount gt 0}"/>
    </c:if>
    <%-- Validación de rol en servidor: el evaluador DEBE ser un usuario con rol=EVALUADOR activo --%>
    <c:set var="evalOK" value="true"/>
    <c:if test="${not empty param.evaluador}">
        <sql:query dataSource="${ds}" var="qValEval">
            SELECT 1 FROM usuarios WHERE id = ? AND rol = 'EVALUADOR' AND activo = 1
            <sql:param value="${param.evaluador}"/>
        </sql:query>
        <c:set var="evalOK" value="${qValEval.rowCount gt 0}"/>
    </c:if>

    <c:choose>
        <c:when test="${empty param.anteproyecto_id || empty param.estudiante_id}">
            <c:redirect url="coordinacion.jsp"/>
        </c:when>
        <c:when test="${empty param.director && empty param.evaluador}">
            <c:redirect url="coordinacion.jsp?accion=ficha&id=${param.estudiante_id}&error=sindirector"/>
        </c:when>
        <c:when test="${not empty param.director && not dirOK}">
            <c:redirect url="coordinacion.jsp?accion=ficha&id=${param.estudiante_id}&error=director_invalido"/>
        </c:when>
        <c:when test="${not empty param.evaluador && not evalOK}">
            <c:redirect url="coordinacion.jsp?accion=ficha&id=${param.estudiante_id}&error=evaluador_invalido"/>
        </c:when>
        <c:otherwise>
            <sql:update dataSource="${ds}">
                UPDATE anteproyectos
                SET director_id = NULLIF(?, ''), evaluador_id = NULLIF(?, '')
                WHERE id = ?
                <sql:param value="${param.director}"/>
                <sql:param value="${param.evaluador}"/>
                <sql:param value="${param.anteproyecto_id}"/>
            </sql:update>

            <%-- Notificación al evaluador asignado (RF-37) --%>
            <c:if test="${not empty param.evaluador}">
                <sql:update dataSource="${ds}">
                    INSERT INTO notificaciones (usuario_id, titulo, mensaje, evento, correo_log)
                    SELECT ?, 'Eres el evaluador de este anteproyecto',
                           'Coordinación te asignó como evaluador del anteproyecto pendiente.',
                           'EVALUADOR_ASIGNADO',
                           CONCAT('Correo a ', email, ' (SMTP pendiente)')
                    FROM usuarios WHERE id = ?
                    <sql:param value="${param.evaluador}"/>
                    <sql:param value="${param.evaluador}"/>
                </sql:update>
            </c:if>

            <%-- Notificación al director asignado (RF-37) --%>
            <c:if test="${not empty param.director}">
                <sql:update dataSource="${ds}">
                    INSERT INTO notificaciones (usuario_id, titulo, mensaje, evento, correo_log)
                    SELECT ?, 'Nuevo anteproyecto asignado',
                           'Coordinación te asignó como director de un anteproyecto.',
                           'DIRECTOR_ASIGNADO',
                           CONCAT('Correo a ', email, ' (SMTP pendiente)')
                    FROM usuarios WHERE id = ?
                    <sql:param value="${param.director}"/>
                    <sql:param value="${param.director}"/>
                </sql:update>
            </c:if>

            <c:redirect url="coordinacion.jsp?accion=ficha&id=${param.estudiante_id}&exito=asignado"/>
        </c:otherwise>
    </c:choose>
</c:if>

<%-- ===== Datos ===== --%>
<c:set var="busqueda" value="${empty param.q ? '' : param.q}"/>

<%-- Resultados de búsqueda (RF-27) --%>
<sql:query dataSource="${ds}" var="qResultados">
    SELECT * FROM usuarios
    WHERE rol = 'ESTUDIANTE' AND activo = 1
      AND (nombre LIKE CONCAT('%', ?, '%')
           OR codigo LIKE CONCAT('%', ?, '%')
           OR email LIKE CONCAT('%', ?, '%'))
    ORDER BY nombre
    <sql:param value="${busqueda}"/>
    <sql:param value="${busqueda}"/>
    <sql:param value="${busqueda}"/>
</sql:query>

<%-- Ficha del estudiante (RF-28) --%>
<c:if test="${param.accion eq 'ficha' && not empty param.id}">
    <sql:query dataSource="${ds}" var="qEst">
        SELECT * FROM usuarios WHERE id = ? AND rol = 'ESTUDIANTE'
        <sql:param value="${param.id}"/>
    </sql:query>
    <c:if test="${qEst.rowCount eq 0}">
        <c:redirect url="coordinacion.jsp"/>
    </c:if>

    <%-- Catálogos para resolver nombres (JSTL usa el nombre REAL de la columna) --%>
    <sql:query dataSource="${ds}" var="qUsuarios">
        SELECT id, nombre FROM usuarios ORDER BY nombre
    </sql:query>
    <sql:query dataSource="${ds}" var="qIdeas">
        SELECT id, titulo FROM ideas ORDER BY id
    </sql:query>

    <sql:query dataSource="${ds}" var="qFicha">
        SELECT * FROM anteproyectos WHERE estudiante_id = ?
        <sql:param value="${param.id}"/>
    </sql:query>
    <c:if test="${not empty qFicha.rows}">
        <c:set var="f" value="${qFicha.rows[0]}"/>
        <c:set var="buscarId" value="${f.director_id}"/>
        <%@ include file="common/resolver.jsp" %>
        <c:set var="dirNombre" value="${empty resNom ? 'Por asignar' : resNom}"/>
        <c:set var="buscarId" value="${f.evaluador_id}"/>
        <%@ include file="common/resolver.jsp" %>
        <c:set var="evalNombre" value="${empty resNom ? 'Por asignar' : resNom}"/>
        <c:set var="buscarIdeaId" value="${f.idea_id}"/>
        <%@ include file="common/resolver_idea.jsp" %>
        <c:set var="ideaTitulo" value="${empty resIdea ? '—' : resIdea}"/>
    </c:if>

    <sql:query dataSource="${ds}" var="qDirectores">
        SELECT id, nombre FROM usuarios WHERE rol = 'DIRECTOR' AND activo = 1 ORDER BY nombre
    </sql:query>
    <sql:query dataSource="${ds}" var="qEvaluadores">
        SELECT id, nombre FROM usuarios WHERE rol = 'EVALUADOR' AND activo = 1 ORDER BY nombre
    </sql:query>
</c:if>

<%@ include file="common/header.jsp" %>

<h1><c:choose>
    <c:when test="${param.accion eq 'ficha'}">Ficha del estudiante</c:when>
    <c:otherwise>Buscar estudiante</c:otherwise>
</c:choose></h1>
<p class="subtitulo">Búsqueda por código o nombre y consulta del proyecto (RF-27, RF-28).</p>

<c:if test="${param.exito eq 'asignado'}">
    <div class="aviso aviso-ok">Director y evaluador asignados. Se enviaron las notificaciones (RF-26, RF-37).</div>
</c:if>
<c:if test="${param.error eq 'sindirector'}">
    <div class="aviso aviso-error">Selecciona al menos un director o un evaluador.</div>
</c:if>
<c:if test="${param.error eq 'director_invalido'}">
    <div class="aviso aviso-error">El usuario seleccionado no es un Director válido o está inactivo.</div>
</c:if>
<c:if test="${param.error eq 'evaluador_invalido'}">
    <div class="aviso aviso-error">El usuario seleccionado no es un Evaluador válido o está inactivo.</div>
</c:if>

<c:choose>

    <%-- ================= FICHA DEL ESTUDIANTE ================= --%>
    <c:when test="${param.accion eq 'ficha' && not empty param.id}">
        <div class="panel">
            <h2 style="margin-top:0">Estudiante</h2>
            <p class="dato"><b>Nombre:</b> <c:out value="${qEst.rows[0].nombre}"/></p>
            <p class="dato"><b>Código:</b> <c:out value="${empty qEst.rows[0].codigo ? '—' : qEst.rows[0].codigo}"/></p>
            <p class="dato"><b>Correo:</b> <c:out value="${qEst.rows[0].email}"/></p>
        </div>

        <c:choose>
            <c:when test="${empty qFicha.rows}">
                <div class="aviso aviso-info">Este estudiante aún no tiene anteproyecto registrado.</div>
            </c:when>
            <c:otherwise>
                <c:set var="f" value="${qFicha.rows[0]}"/>
                <div class="panel">
                    <h2 style="margin-top:0">Proyecto / anteproyecto (RF-28)</h2>
                    <p class="dato"><b>Anteproyecto:</b> <c:out value="${f.titulo}"/></p>
                    <p class="dato"><b>Idea:</b> <c:out value="${ideaTitulo}"/></p>
                    <p class="dato"><b>Director:</b> <c:out value="${dirNombre}"/></p>
                    <p class="dato"><b>Evaluador:</b> <c:out value="${evalNombre}"/></p>
                    <p class="dato"><b>Estado:</b>
                        <c:set var="est" value="${f.estado}"/>
                        <span class="estado estado-${est}"><%@ include file="common/estado.jsp" %></span>
                    </p>
                    <c:if test="${not empty f['calificacion_director']}">
                        <p class="dato"><b>Calificación director:</b>
                            <fmt:formatNumber value="${f['calificacion_director']}" maxFractionDigits="1"/> / 5
                        </p>
                    </c:if>
                    <a class="btn btn-gris" href="anteproyecto_ver.jsp?id=${f.id}">Ver detalle completo</a>
                </div>

                <%-- ===== Asignación (RF-26) ===== --%>
                <div class="panel">
                    <h2 style="margin-top:0">Asignar director y evaluador (RF-26)</h2>
                    <form method="post" action="coordinacion.jsp">
                        <input type="hidden" name="csrf_token" value="${csrfToken}">
                        <input type="hidden" name="accion" value="asignar">
                        <input type="hidden" name="anteproyecto_id" value="${f.id}">
                        <input type="hidden" name="estudiante_id" value="${param.id}">

                        <div class="form-fila">
                            <div>
                                <label for="director">Director</label>
                                <select id="director" name="director">
                                    <option value="">-- Sin asignar --</option>
                                    <c:forEach items="${qDirectores.rows}" var="d">
                                        <option value="${d.id}" ${f.director_id eq d.id ? 'selected' : ''}>
                                            <c:out value="${d.nombre}"/>
                                        </option>
                                    </c:forEach>
                                </select>
                            </div>
                            <div>
                                <label for="evaluador">Evaluador</label>
                                <select id="evaluador" name="evaluador">
                                    <option value="">-- Sin asignar --</option>
                                    <c:forEach items="${qEvaluadores.rows}" var="e">
                                        <option value="${e.id}" ${f.evaluador_id eq e.id ? 'selected' : ''}>
                                            <c:out value="${e.nombre}"/>
                                        </option>
                                    </c:forEach>
                                </select>
                            </div>
                        </div>
                        <button class="btn btn-verde" type="submit">Guardar asignación</button>
                        <a class="btn btn-gris" href="coordinacion.jsp">Volver a la búsqueda</a>
                    </form>
                </div>
            </c:otherwise>
        </c:choose>
    </c:when>

    <%-- ================= BÚSQUEDA (RF-27) ================= --%>
    <c:otherwise>
        <div class="panel">
            <h2 style="margin-top:0">Consulta</h2>
            <form method="get" action="coordinacion.jsp">
                <input type="hidden" name="accion" value="buscar">
                <label for="q">Código o nombre del estudiante</label>
                <input type="text" id="q" name="q" value="${fn:escapeXml(busqueda)}"
                       placeholder="Ej.: 123456 o Juan">
                <button class="btn" type="submit">Buscar</button>
            </form>
        </div>

        <div class="panel">
            <h2 style="margin-top:0">Resultados (<c:out value="${qResultados.rowCount}"/>)</h2>
            <table>
                <tr>
                    <th>Nombre</th>
                    <th>Código</th>
                    <th>Correo</th>
                    <th>Acción</th>
                </tr>
                <c:forEach items="${qResultados.rows}" var="e">
                    <tr>
                        <td><c:out value="${e.nombre}"/></td>
                        <td><c:out value="${empty e.codigo ? '—' : e.codigo}"/></td>
                        <td><c:out value="${e.email}"/></td>
                        <td><a class="btn btn-mini" href="coordinacion.jsp?accion=ficha&id=${e.id}">Ver ficha</a></td>
                    </tr>
                </c:forEach>
            </table>
            <c:if test="${empty qResultados.rows}">
                <p>No se encontraron estudiantes con ese dato.</p>
            </c:if>
        </div>
    </c:otherwise>
</c:choose>

<%@ include file="common/footer.jsp" %>
