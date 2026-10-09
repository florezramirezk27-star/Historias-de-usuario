<%-- ==========================================================
     informes.jsp - Coordinación: informes de estado
       * Estado de los proyectos de los estudiantes (RF-29)
       * Estado de los proyectos de los directores   (RF-30)
       * Estado de los proyectos de los evaluadores  (RF-31)
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

<c:set var="tipo" value="${empty param.tipo ? 'estudiantes' : param.tipo}"/>

<c:choose>
    <%-- ===== RF-29: estado de los proyectos de los estudiantes ===== --%>
    <c:when test="${tipo eq 'directores'}">
        <sql:query dataSource="${ds}" var="qInforme">
            SELECT u.id, u.nombre,
                   COUNT(a.id) AS total,
                   IFNULL(SUM(a.estado = 'ENVIADO'), 0) AS pendientes,
                   IFNULL(SUM(a.estado = 'APROBADO_DIRECTOR'), 0) AS en_evaluacion,
                   IFNULL(SUM(a.estado = 'APROBADO_EVALUADOR'), 0) AS aprobados,
                   IFNULL(SUM(a.estado = 'RECHAZADO'), 0) AS rechazados
            FROM usuarios u
            LEFT JOIN anteproyectos a ON a.director_id = u.id
            WHERE u.rol = 'DIRECTOR' AND u.activo = 1
            GROUP BY u.id, u.nombre
            ORDER BY u.nombre
        </sql:query>
    </c:when>

    <%-- ===== RF-31: estado de los proyectos de los evaluadores ===== --%>
    <c:when test="${tipo eq 'evaluadores'}">
        <sql:query dataSource="${ds}" var="qInforme">
            SELECT u.id, u.nombre,
                   COUNT(a.id) AS total,
                   IFNULL(SUM(a.estado = 'APROBADO_DIRECTOR'), 0) AS pendientes,
                   IFNULL(SUM(a.estado = 'APROBADO_EVALUADOR'), 0) AS aprobados,
                   IFNULL(SUM(a.estado = 'RECHAZADO'), 0) AS rechazados
            FROM usuarios u
            LEFT JOIN anteproyectos a ON a.evaluador_id = u.id
            WHERE u.rol = 'EVALUADOR' AND u.activo = 1
            GROUP BY u.id, u.nombre
            ORDER BY u.nombre
        </sql:query>
    </c:when>

    <%-- ===== RF-29 (por defecto): estado de los proyectos de los estudiantes ===== --%>
    <c:otherwise>
        <sql:query dataSource="${ds}" var="qInforme">
            SELECT u.nombre, u.codigo,
                   a.id, a.titulo, a.estado,
                   a.calificacion_director, a.calificacion_evaluador,
                   a.director_id, a.evaluador_id
            FROM usuarios u
            LEFT JOIN anteproyectos a ON a.estudiante_id = u.id
            WHERE u.rol = 'ESTUDIANTE' AND u.activo = 1
            ORDER BY u.nombre
        </sql:query>
        <%-- Catálogo para resolver los nombres de director/evaluador --%>
        <sql:query dataSource="${ds}" var="qUsuarios">
            SELECT id, nombre FROM usuarios ORDER BY nombre
        </sql:query>
    </c:otherwise>
</c:choose>

<%@ include file="common/header.jsp" %>

<h1>Informes de estado</h1>
<p class="subtitulo">Estado de los proyectos por rol (RF-29, RF-30, RF-31).</p>

<div class="panel">
    <a class="btn ${tipo eq 'estudiantes' ? '' : 'btn-gris'}" href="informes.jsp?tipo=estudiantes">Por estudiante (RF-29)</a>
    <a class="btn ${tipo eq 'directores' ? '' : 'btn-gris'}" href="informes.jsp?tipo=directores">Por director (RF-30)</a>
    <a class="btn ${tipo eq 'evaluadores' ? '' : 'btn-gris'}" href="informes.jsp?tipo=evaluadores">Por evaluador (RF-31)</a>
</div>

<div class="panel">
    <c:choose>

        <%-- ---------- Tabla por director ---------- --%>
        <c:when test="${tipo eq 'directores'}">
            <h2 style="margin-top:0">Proyectos de los directores</h2>
            <table>
                <tr>
                    <th>Director</th>
                    <th>Total</th>
                    <th>Pendientes (en revisión)</th>
                    <th>En evaluación</th>
                    <th>Aprobados</th>
                    <th>Rechazados</th>
                </tr>
                <c:forEach items="${qInforme.rows}" var="r">
                    <tr>
                        <td><c:out value="${r.nombre}"/></td>
                        <td><c:out value="${r.total}"/></td>
                        <td><c:out value="${r.pendientes}"/></td>
                        <td><c:out value="${r.en_evaluacion}"/></td>
                        <td><c:out value="${r.aprobados}"/></td>
                        <td><c:out value="${r.rechazados}"/></td>
                    </tr>
                </c:forEach>
            </table>
        </c:when>

        <%-- ---------- Tabla por evaluador ---------- --%>
        <c:when test="${tipo eq 'evaluadores'}">
            <h2 style="margin-top:0">Proyectos de los evaluadores</h2>
            <table>
                <tr>
                    <th>Evaluador</th>
                    <th>Total asignados</th>
                    <th>Pendientes por aprobar</th>
                    <th>Aprobados</th>
                    <th>Rechazados</th>
                </tr>
                <c:forEach items="${qInforme.rows}" var="r">
                    <tr>
                        <td><c:out value="${r.nombre}"/></td>
                        <td><c:out value="${r.total}"/></td>
                        <td><c:out value="${r.pendientes}"/></td>
                        <td><c:out value="${r.aprobados}"/></td>
                        <td><c:out value="${r.rechazados}"/></td>
                    </tr>
                </c:forEach>
            </table>
        </c:when>

        <%-- ---------- Tabla por estudiante ---------- --%>
        <c:otherwise>
            <h2 style="margin-top:0">Proyectos de los estudiantes</h2>
            <table>
                <tr>
                    <th>Estudiante</th>
                    <th>Código</th>
                    <th>Anteproyecto</th>
                    <th>Director</th>
                    <th>Evaluador</th>
                    <th>Estado</th>
                    <th>Calif. dir.</th>
                    <th>Calif. eval.</th>
                </tr>
                <c:forEach items="${qInforme.rows}" var="r">
                    <c:set var="dirNombre" value="—"/>
                    <c:if test="${not empty r.director_id}">
                        <c:set var="buscarId" value="${r.director_id}"/>
                        <%@ include file="common/resolver.jsp" %>
                        <c:set var="dirNombre" value="${empty resNom ? '—' : resNom}"/>
                    </c:if>
                    <c:set var="evalNombre" value="—"/>
                    <c:if test="${not empty r.evaluador_id}">
                        <c:set var="buscarId" value="${r.evaluador_id}"/>
                        <%@ include file="common/resolver.jsp" %>
                        <c:set var="evalNombre" value="${empty resNom ? '—' : resNom}"/>
                    </c:if>
                    <tr>
                        <td><c:out value="${r.nombre}"/></td>
                        <td><c:out value="${empty r.codigo ? '—' : r.codigo}"/></td>
                        <td>
                            <c:choose>
                                <c:when test="${empty r.id}"><i>Sin anteproyecto</i></c:when>
                                <c:otherwise><c:out value="${r.titulo}"/></c:otherwise>
                            </c:choose>
                        </td>
                        <td><c:out value="${dirNombre}"/></td>
                        <td><c:out value="${evalNombre}"/></td>
                        <td>
                            <c:choose>
                                <c:when test="${empty r.id}">—</c:when>
                                <c:otherwise>
                                    <c:set var="est" value="${r.estado}"/>
                                    <span class="estado estado-${est}"><%@ include file="common/estado.jsp" %></span>
                                </c:otherwise>
                            </c:choose>
                        </td>
                        <td>
                            <c:choose>
                                <c:when test="${empty r.calificacion_director}">—</c:when>
                                <c:otherwise><fmt:formatNumber value="${r.calificacion_director}" maxFractionDigits="1"/></c:otherwise>
                            </c:choose>
                        </td>
                        <td>
                            <c:choose>
                                <c:when test="${empty r.calificacion_evaluador}">—</c:when>
                                <c:otherwise><fmt:formatNumber value="${r.calificacion_evaluador}" maxFractionDigits="1"/></c:otherwise>
                            </c:choose>
                        </td>
                    </tr>
                </c:forEach>
            </table>
        </c:otherwise>
    </c:choose>

    <c:if test="${empty qInforme.rows}">
        <p>No hay datos para mostrar.</p>
    </c:if>
</div>

<%@ include file="common/footer.jsp" %>
