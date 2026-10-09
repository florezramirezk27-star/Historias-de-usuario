<%-- ==========================================================
     calendario.jsp - Calendario académico (RF-32)
     Lo consultan: Coordinación, Estudiante, Director y Evaluador
     ========================================================== --%>
<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ include file="common/config.jsp" %>
<%@ include file="common/guard.jsp" %>

<%-- ===== Registrar evento (solo administración/coordinación, POST) ===== --%>
<c:if test="${pageContext.request.method eq 'POST' && param.accion eq 'crear'}">
    <%@ include file="common/verify_csrf.jsp" %>
    <c:if test="${rol ne 'ADMIN' && rol ne 'COORDINACION'}">
        <c:redirect url="403.jsp"/>
    </c:if>
    <c:choose>
        <c:when test="${empty param.titulo || empty param.fecha_inicio}">
            <c:set var="error" value="El título y la fecha de inicio son obligatorios."/>
        </c:when>
        <c:otherwise>
            <c:choose>
                <c:when test="${not empty param.fecha_fin}">
                    <sql:update dataSource="${ds}">
                        INSERT INTO calendario (titulo, descripcion, fecha_inicio, fecha_fin, tipo)
                        VALUES (?, ?, ?, ?, ?)
                        <sql:param value="${param.titulo}"/>
                        <sql:param value="${param.descripcion}"/>
                        <sql:param value="${param.fecha_inicio}"/>
                        <sql:param value="${param.fecha_fin}"/>
                        <sql:param value="${param.tipo}"/>
                    </sql:update>
                </c:when>
                <c:otherwise>
                    <sql:update dataSource="${ds}">
                        INSERT INTO calendario (titulo, descripcion, fecha_inicio, tipo)
                        VALUES (?, ?, ?, ?)
                        <sql:param value="${param.titulo}"/>
                        <sql:param value="${param.descripcion}"/>
                        <sql:param value="${param.fecha_inicio}"/>
                        <sql:param value="${param.tipo}"/>
                    </sql:update>
                </c:otherwise>
            </c:choose>
            <c:redirect url="calendario.jsp?exito=creado"/>
        </c:otherwise>
    </c:choose>
</c:if>

<%-- ===== Eventos ordenados por fecha ===== --%>
<sql:query dataSource="${ds}" var="qEventos">
    SELECT * FROM calendario
    ORDER BY fecha_inicio
</sql:query>

<%@ include file="common/header.jsp" %>

<h1>Calendario académico</h1>
<p class="subtitulo">Fechas importantes del proceso de trabajos de grado (RF-32).</p>

<c:if test="${param.exito eq 'creado'}">
    <div class="aviso aviso-ok">Evento agregado al calendario.</div>
</c:if>
<c:if test="${not empty error}">
    <div class="aviso aviso-error"><c:out value="${error}"/></div>
</c:if>

<c:if test="${rol eq 'ADMIN' || rol eq 'COORDINACION'}">
    <div class="panel">
        <h2 style="margin-top:0">Agregar evento</h2>
        <form method="post" action="calendario.jsp">
            <input type="hidden" name="csrf_token" value="${csrfToken}">
            <input type="hidden" name="accion" value="crear">
            <div class="form-fila">
                <div>
                    <label for="titulo">Título</label>
                    <input type="text" id="titulo" name="titulo" required maxlength="150">
                </div>
                <div>
                    <label for="tipo">Tipo</label>
                    <select id="tipo" name="tipo" required>
                        <option value="ACADEMICO">Académico</option>
                        <option value="HITO">Hito</option>
                        <option value="ENTREGA">Entrega</option>
                        <option value="EXAMEN">Examen</option>
                    </select>
                </div>
            </div>
            <label for="descripcion">Descripción</label>
            <input type="text" id="descripcion" name="descripcion" maxlength="400">
            <div class="form-fila">
                <div>
                    <label for="fecha_inicio">Fecha de inicio</label>
                    <input type="date" id="fecha_inicio" name="fecha_inicio" required>
                </div>
                <div>
                    <label for="fecha_fin">Fecha final (opcional)</label>
                    <input type="date" id="fecha_fin" name="fecha_fin">
                </div>
            </div>
            <button class="btn" type="submit">Agregar evento</button>
        </form>
    </div>
</c:if>

<div class="panel">
    <h2 style="margin-top:0">Eventos (<c:out value="${qEventos.rowCount}"/>)</h2>
    <table>
        <tr>
            <th>Fecha</th>
            <th>Hasta</th>
            <th>Tipo</th>
            <th>Título</th>
            <th>Descripción</th>
        </tr>
        <c:forEach items="${qEventos.rows}" var="ev">
            <tr>
                <td><fmt:formatDate value="${ev.fecha_inicio}" pattern="dd/MM/yyyy"/></td>
                <td>
                    <c:choose>
                        <c:when test="${empty ev.fecha_fin}">—</c:when>
                        <c:otherwise><fmt:formatDate value="${ev.fecha_fin}" pattern="dd/MM/yyyy"/></c:otherwise>
                    </c:choose>
                </td>
                <td>
                    <c:choose>
                        <c:when test="${ev.tipo eq 'ENTREGA'}">Entrega</c:when>
                        <c:when test="${ev.tipo eq 'HITO'}">Hito</c:when>
                        <c:when test="${ev.tipo eq 'EXAMEN'}">Examen</c:when>
                        <c:otherwise>Académico</c:otherwise>
                    </c:choose>
                </td>
                <td><c:out value="${ev.titulo}"/></td>
                <td><c:out value="${empty ev.descripcion ? '—' : ev.descripcion}"/></td>
            </tr>
        </c:forEach>
    </table>
    <c:if test="${empty qEventos.rows}">
        <p>No hay eventos registrados.</p>
    </c:if>
</div>

<%@ include file="common/footer.jsp" %>
