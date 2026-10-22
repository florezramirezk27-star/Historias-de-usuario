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
<c:if test="${pageContext.request.method eq 'POST' && (param.accion eq 'crear' || param.accion eq 'editar')}">
    <%@ include file="common/verify_csrf.jsp" %>
    <c:if test="${rol ne 'ADMIN' && rol ne 'COORDINACION'}">
        <c:redirect url="403.jsp"/>
    </c:if>
    <c:choose>
        <c:when test="${empty param.titulo || empty param.fecha_inicio}">
            <c:set var="error" value="El título y la fecha de inicio son obligatorios."/>
        </c:when>
        <%-- Editar exige que el evento exista --%>
        <c:when test="${param.accion eq 'editar' && empty param.id}">
            <c:set var="error" value="No se indicó el evento a actualizar."/>
        </c:when>
        <c:otherwise>
            <c:choose>
                <c:when test="${param.accion eq 'editar'}">
                    <sql:update dataSource="${ds}">
                        UPDATE calendario
                        SET titulo = ?, descripcion = ?, fecha_inicio = ?,
                            fecha_fin = NULLIF(?, ''), tipo = ?
                        WHERE id = ?
                        <sql:param value="${param.titulo}"/>
                        <sql:param value="${param.descripcion}"/>
                        <sql:param value="${param.fecha_inicio}"/>
                        <sql:param value="${param.fecha_fin}"/>
                        <sql:param value="${param.tipo}"/>
                        <sql:param value="${param.id}"/>
                    </sql:update>
                    <c:redirect url="calendario.jsp?exito=editado"/>
                </c:when>
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
                    <c:redirect url="calendario.jsp?exito=creado"/>
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
                    <c:redirect url="calendario.jsp?exito=creado"/>
                </c:otherwise>
            </c:choose>
        </c:otherwise>
    </c:choose>
</c:if>

<%-- ===== Eliminar evento (solo administración/coordinación, POST) ===== --%>
<c:if test="${pageContext.request.method eq 'POST' && param.accion eq 'eliminar'}">
    <%@ include file="common/verify_csrf.jsp" %>
    <c:if test="${rol ne 'ADMIN' && rol ne 'COORDINACION'}">
        <c:redirect url="403.jsp"/>
    </c:if>
    <c:choose>
        <c:when test="${empty param.id}">
            <c:redirect url="calendario.jsp"/>
        </c:when>
        <c:otherwise>
            <sql:update dataSource="${ds}">
                DELETE FROM calendario WHERE id = ?
                <sql:param value="${param.id}"/>
            </sql:update>
            <c:redirect url="calendario.jsp?exito=eliminado"/>
        </c:otherwise>
    </c:choose>
</c:if>

<%-- ===== Datos del evento en edición (GET ?accion=editar&id=) ===== --%>
<c:set var="modo" value="'crear'"/>
<c:set var="eId" value=""/>
<c:set var="eTitulo" value=""/>
<c:set var="eDescripcion" value=""/>
<c:set var="eFechaInicio" value=""/>
<c:set var="eFechaFin" value=""/>
<c:set var="eTipo" value="ACADEMICO"/>
<c:if test="${pageContext.request.method eq 'GET' && param.accion eq 'editar' && not empty param.id}">
    <sql:query dataSource="${ds}" var="qEvento">
        SELECT * FROM calendario WHERE id = ?
        <sql:param value="${param.id}"/>
    </sql:query>
    <c:if test="${qEvento.rowCount gt 0}">
        <c:set var="modo" value="'editar'"/>
        <c:set var="eId" value="${qEvento.rows[0].id}"/>
        <c:set var="eTitulo" value="${qEvento.rows[0].titulo}"/>
        <c:set var="eDescripcion" value="${qEvento.rows[0].descripcion}"/>
        <c:set var="eFechaInicio" value="${qEvento.rows[0].fecha_inicio}"/>
        <c:set var="eFechaFin" value="${qEvento.rows[0].fecha_fin}"/>
        <c:set var="eTipo" value="${qEvento.rows[0].tipo}"/>
    </c:if>
</c:if>

<%-- ===== Eventos ordenados por fecha ===== --%>
<sql:query dataSource="${ds}" var="qEventos">
    SELECT * FROM calendario
    ORDER BY fecha_inicio
</sql:query>

<%@ include file="common/header.jsp" %>

<h1>Calendario académico</h1>
<p class="subtitulo">Fechas importantes del proceso de trabajos de grado (RF-32).</p>
<div class="aviso aviso-info">
    Las fechas iniciales son <b>datos de demostración</b>, no el calendario académico
    oficial. Deben reemplazarse con las fechas publicadas por la institución.
</div>

<c:if test="${param.exito eq 'creado'}">
    <div class="aviso aviso-ok">Evento agregado al calendario.</div>
</c:if>
<c:if test="${param.exito eq 'editado'}">
    <div class="aviso aviso-ok">Evento actualizado.</div>
</c:if>
<c:if test="${param.exito eq 'eliminado'}">
    <div class="aviso aviso-ok">Evento eliminado del calendario.</div>
</c:if>
<c:if test="${not empty error}">
    <div class="aviso aviso-error"><c:out value="${error}"/></div>
</c:if>

<c:if test="${rol eq 'ADMIN' || rol eq 'COORDINACION'}">
    <div class="panel">
        <h2 style="margin-top:0">
            <c:choose>
                <c:when test="${modo eq 'editar'}">Editar evento</c:when>
                <c:otherwise>Agregar evento</c:otherwise>
            </c:choose>
        </h2>
        <form method="post" action="calendario.jsp">
            <input type="hidden" name="csrf_token" value="${csrfToken}">
            <input type="hidden" name="accion" value="${modo eq 'editar' ? 'editar' : 'crear'}">
            <c:if test="${modo eq 'editar'}">
                <input type="hidden" name="id" value="${eId}">
            </c:if>
            <div class="form-fila">
                <div>
                    <label for="titulo">Título</label>
                    <input type="text" id="titulo" name="titulo" required maxlength="150"
                           value="${fn:escapeXml(eTitulo)}">
                </div>
                <div>
                    <label for="tipo">Tipo</label>
                    <select id="tipo" name="tipo" required>
                        <option value="ACADEMICO" ${eTipo eq 'ACADEMICO' ? 'selected' : ''}>Académico</option>
                        <option value="HITO" ${eTipo eq 'HITO' ? 'selected' : ''}>Hito</option>
                        <option value="ENTREGA" ${eTipo eq 'ENTREGA' ? 'selected' : ''}>Entrega</option>
                        <option value="EXAMEN" ${eTipo eq 'EXAMEN' ? 'selected' : ''}>Examen</option>
                    </select>
                </div>
            </div>
            <label for="descripcion">Descripción</label>
            <input type="text" id="descripcion" name="descripcion" maxlength="400"
                   value="${fn:escapeXml(eDescripcion)}">
            <div class="form-fila">
                <div>
                    <label for="fecha_inicio">Fecha de inicio</label>
                    <input type="date" id="fecha_inicio" name="fecha_inicio" required
                           value="${fn:escapeXml(eFechaInicio)}">
                </div>
                <div>
                    <label for="fecha_fin">Fecha final (opcional)</label>
                    <input type="date" id="fecha_fin" name="fecha_fin"
                           value="${fn:escapeXml(eFechaFin)}">
                </div>
            </div>
            <button class="btn ${modo eq 'editar' ? 'btn-verde' : ''}" type="submit">
                <c:choose>
                    <c:when test="${modo eq 'editar'}">Guardar cambios</c:when>
                    <c:otherwise>Agregar evento</c:otherwise>
                </c:choose>
            </button>
            <c:if test="${modo eq 'editar'}">
                <a class="btn btn-gris" href="calendario.jsp">Cancelar</a>
            </c:if>
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
            <c:if test="${rol eq 'ADMIN' || rol eq 'COORDINACION'}">
                <th>Acciones</th>
            </c:if>
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
                <c:if test="${rol eq 'ADMIN' || rol eq 'COORDINACION'}">
                    <td>
                        <a class="btn btn-mini btn-gris" href="calendario.jsp?accion=editar&amp;id=${ev.id}">Editar</a>
                        <form method="post" action="calendario.jsp" style="display:inline"
                              onsubmit="return confirm('¿Eliminar este evento del calendario?')">
                            <input type="hidden" name="csrf_token" value="${csrfToken}">
                            <input type="hidden" name="accion" value="eliminar">
                            <input type="hidden" name="id" value="${ev.id}">
                            <button class="btn btn-mini btn-rojo" type="submit">Eliminar</button>
                        </form>
                    </td>
                </c:if>
            </tr>
        </c:forEach>
    </table>
    <c:if test="${empty qEventos.rows}">
        <p>No hay eventos registrados.</p>
    </c:if>
</div>

<%@ include file="common/footer.jsp" %>
