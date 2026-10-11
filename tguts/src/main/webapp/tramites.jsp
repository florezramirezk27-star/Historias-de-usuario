<%-- ==========================================================
     tramites.jsp - Trámites: retiro, prórroga y beneficios
     (RF-38, RF-39, RF-40)
       * Estudiante: crea la solicitud
       * Coordinación/administrador: la resuelve
     ========================================================== --%>
<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ include file="common/config.jsp" %>
<%@ include file="common/guard.jsp" %>

<c:if test="${rol ne 'ADMIN' && rol ne 'COORDINACION' && rol ne 'ESTUDIANTE'}">
    <c:redirect url="403.jsp"/>
</c:if>

<%-- ===== Nueva solicitud (estudiante, POST) ===== --%>
<c:if test="${pageContext.request.method eq 'POST' && param.accion eq 'solicitar'}">
    <%@ include file="common/verify_csrf.jsp" %>
    <c:if test="${rol ne 'ESTUDIANTE'}">
        <c:redirect url="403.jsp"/>
    </c:if>
    <c:choose>
        <c:when test="${empty param.tipo}">
            <c:set var="error" value="Selecciona el tipo de trámite."/>
        </c:when>
        <c:when test="${param.tipo ne 'RETIRO' && param.tipo ne 'PRORROGA' && param.tipo ne 'BENEFICIO'}">
            <c:set var="error" value="Tipo de trámite no válido."/>
        </c:when>
        <c:when test="${empty param.detalle}">
            <c:set var="error" value="Describe el motivo del trámite."/>
        </c:when>
        <c:otherwise>
            <sql:transaction dataSource="${ds}">
                <sql:update>
                    INSERT INTO tramites (estudiante_id, tipo, detalle) VALUES (?, ?, ?)
                    <sql:param value="${yo.id}"/>
                    <sql:param value="${param.tipo}"/>
                    <sql:param value="${param.detalle}"/>
                </sql:update>
                <%-- Notificación a coordinación (RF-37) --%>
                <sql:update>
                    INSERT INTO notificaciones (usuario_id, titulo, mensaje, evento, correo_log)
                    SELECT u.id, 'Nueva solicitud de trámite',
                           CONCAT('El estudiante ${yo.nombre} solicitó un trámite de tipo ', ?, '.'),
                           'TRAMITE_SOLICITADO',
                           CONCAT('Correo a ', u.email, ' (SMTP pendiente)')
                    FROM usuarios u
                    WHERE u.rol = 'COORDINACION' AND u.activo = 1
                    <sql:param value="${param.tipo}"/>
                </sql:update>
            </sql:transaction>
            <c:redirect url="tramites.jsp?exito=solicitado"/>
        </c:otherwise>
    </c:choose>
</c:if>

<%-- ===== Resolver solicitud (coordinación/administrador, POST) ===== --%>
<c:if test="${pageContext.request.method eq 'POST' && param.accion eq 'responder'}">
    <%@ include file="common/verify_csrf.jsp" %>
    <c:if test="${rol ne 'ADMIN' && rol ne 'COORDINACION'}">
        <c:redirect url="403.jsp"/>
    </c:if>
    <c:choose>
        <c:when test="${empty param.id}">
            <c:redirect url="tramites.jsp"/>
        </c:when>
        <c:when test="${param.resultado ne 'APROBADO' && param.resultado ne 'RECHAZADO'}">
            <c:redirect url="tramites.jsp?error=resultado"/>
        </c:when>
        <c:when test="${empty param.respuesta}">
            <c:redirect url="tramites.jsp?error=sinrespuesta"/>
        </c:when>
        <c:otherwise>
            <sql:transaction dataSource="${ds}">
                <sql:update var="filasTram">
                    UPDATE tramites
                    SET estado = ?, respuesta = ?, resuelto_por = ?
                    WHERE id = ? AND estado = 'PENDIENTE'
                    <sql:param value="${param.resultado}"/>
                    <sql:param value="${param.respuesta}"/>
                    <sql:param value="${yo.id}"/>
                    <sql:param value="${param.id}"/>
                </sql:update>
                <c:if test="${filasTram gt 0}">
                    <%-- Notificación al estudiante (RF-37) --%>
                    <sql:update>
                        INSERT INTO notificaciones (usuario_id, titulo, mensaje, evento, correo_log)
                        SELECT estudiante_id, CONCAT('Trámite ', ?),
                               CONCAT('Tu solicitud de trámite fue ', LOWER(?), '. Motivo: ', ?),
                               'TRAMITE_RESPONDIDO',
                               CONCAT('Correo a ', (SELECT email FROM usuarios u WHERE u.id = tramites.estudiante_id),
                                      ' (SMTP pendiente)')
                        FROM tramites WHERE id = ?
                        <sql:param value="${param.resultado}"/>
                        <sql:param value="${param.resultado}"/>
                        <sql:param value="${param.respuesta}"/>
                        <sql:param value="${param.id}"/>
                    </sql:update>
                </c:if>
            </sql:transaction>
            <c:choose>
                <c:when test="${filasTram gt 0}">
                    <c:redirect url="tramites.jsp?exito=resuelto"/>
                </c:when>
                <c:otherwise>
                    <c:redirect url="tramites.jsp?error=ya_resuelto"/>
                </c:otherwise>
            </c:choose>
        </c:otherwise>
    </c:choose>
</c:if>

<%-- Catálogos para resolver nombres (clave = id real) --%>
<sql:query dataSource="${ds}" var="qUsuarios">
    SELECT id, nombre, codigo FROM usuarios ORDER BY nombre
</sql:query>

<%-- ===== Listas =====
     Estudiante: t.* + nombre del resolutor (el nombre real es 'nombre',
     ya que la columna r.nombre no se puede alias en el mapa de JSTL). --%>
<c:choose>
    <c:when test="${rol eq 'ESTUDIANTE'}">
        <sql:query dataSource="${ds}" var="qTramites">
            SELECT t.*, r.nombre AS resolutor_nombre
            FROM tramites t LEFT JOIN usuarios r ON r.id = t.resuelto_por
            WHERE t.estudiante_id = ?
            ORDER BY t.id DESC
            <sql:param value="${yo.id}"/>
        </sql:query>
    </c:when>
    <c:otherwise>
        <sql:query dataSource="${ds}" var="qTramites">
            SELECT * FROM tramites
            ORDER BY (estado = 'PENDIENTE') DESC, id DESC
        </sql:query>
    </c:otherwise>
</c:choose>

<%@ include file="common/header.jsp" %>

<h1>Trámites</h1>
<p class="subtitulo">Retiro del proyecto, prórrogas y beneficios (RF-38 a RF-40).</p>

<c:if test="${param.exito eq 'solicitado'}">
    <div class="aviso aviso-ok">Solicitud enviada. Coordinación fue notificada.</div>
</c:if>
<c:if test="${param.exito eq 'resuelto'}">
    <div class="aviso aviso-ok">Trámite resuelto. El estudiante fue notificado.</div>
</c:if>
<c:if test="${param.error eq 'resultado'}">
    <div class="aviso aviso-error">Debes indicar si el trámite se aprueba o se rechaza.</div>
</c:if>
<c:if test="${param.error eq 'sinrespuesta'}">
    <div class="aviso aviso-error">Debes escribir la respuesta o motivo de la decisión.</div>
</c:if>
<c:if test="${param.error eq 'ya_resuelto'}">
    <div class="aviso aviso-error">Ese trámite ya había sido resuelto.</div>
</c:if>
<c:if test="${not empty error}">
    <div class="aviso aviso-error"><c:out value="${error}"/></div>
</c:if>

<%-- ===== Formulario de solicitud (estudiante) ===== --%>
<c:if test="${rol eq 'ESTUDIANTE'}">
    <div class="panel">
        <h2 style="margin-top:0">Nueva solicitud</h2>
        <form method="post" action="tramites.jsp">
            <input type="hidden" name="csrf_token" value="${csrfToken}">
            <input type="hidden" name="accion" value="solicitar">
            <label for="tipo">Tipo de trámite</label>
            <select id="tipo" name="tipo" required>
                <option value="RETIRO">Retiro del proyecto (RF-38)</option>
                <option value="PRORROGA">Prórroga (RF-39)</option>
                <option value="BENEFICIO">Beneficio (RF-40)</option>
            </select>
            <label for="detalle">Motivo / detalle</label>
            <textarea id="detalle" name="detalle" required maxlength="2000"
                      placeholder="Explica brevemente tu solicitud"></textarea>
            <button class="btn" type="submit">Enviar solicitud</button>
        </form>
    </div>
</c:if>

<%-- ===== Listado ===== --%>
<div class="panel">
    <h2 style="margin-top:0">
        <c:choose>
            <c:when test="${rol eq 'ESTUDIANTE'}">Mis solicitudes</c:when>
            <c:otherwise>Solicitudes de trámites</c:otherwise>
        </c:choose>
        (<c:out value="${qTramites.rowCount}"/>)
    </h2>

    <table>
        <tr>
            <c:if test="${rol ne 'ESTUDIANTE'}">
                <th>Estudiante</th>
            </c:if>
            <th>Tipo</th>
            <th>Detalle</th>
            <th>Estado</th>
            <th>Respuesta</th>
            <th>Fecha</th>
            <c:if test="${rol ne 'ESTUDIANTE'}"><th>Acción</th></c:if>
        </tr>
        <c:forEach items="${qTramites.rows}" var="t">
            <c:if test="${rol ne 'ESTUDIANTE'}">
                <c:set var="buscarId" value="${t.estudiante_id}"/>
                <%@ include file="common/resolver.jsp" %>
                <c:set var="estNombre" value="${resNom}"/>
                <c:set var="estCodigo" value="${resCod}"/>
                <c:set var="buscarId" value="${t.resuelto_por}"/>
                <%@ include file="common/resolver.jsp" %>
                <c:set var="resNombre" value="${resNom}"/>
            </c:if>
            <tr>
                <c:if test="${rol ne 'ESTUDIANTE'}">
                    <td>
                        <c:out value="${estNombre}"/>
                        <c:if test="${not empty estCodigo}">
                            (<c:out value="${estCodigo}"/>)
                        </c:if>
                    </td>
                </c:if>
                <td>
                    <c:choose>
                        <c:when test="${t.tipo eq 'RETIRO'}">Retiro</c:when>
                        <c:when test="${t.tipo eq 'PRORROGA'}">Prórroga</c:when>
                        <c:otherwise>Beneficio</c:otherwise>
                    </c:choose>
                </td>
                <td><c:out value="${t.detalle}"/></td>
                <td>
                    <c:set var="est" value="${t.estado}"/>
                    <span class="estado estado-${est}"><%@ include file="common/estado.jsp" %></span>
                </td>
                <td>
                    <c:choose>
                        <c:when test="${empty t.respuesta}">—</c:when>
                        <c:otherwise>
                            <c:out value="${t.respuesta}"/>
                            <c:if test="${rol eq 'ESTUDIANTE' ? not empty t.nombre : not empty resNombre}">
                                <br><i>por <c:out value="${rol eq 'ESTUDIANTE' ? t.nombre : resNombre}"/></i>
                            </c:if>
                        </c:otherwise>
                    </c:choose>
                </td>
                <td><fmt:formatDate value="${t['creado_en']}" pattern="dd/MM/yyyy"/></td>
                <c:if test="${rol ne 'ESTUDIANTE'}">
                    <td>
                        <c:choose>
                            <c:when test="${t.estado eq 'PENDIENTE'}">
                                <form method="post" action="tramites.jsp">
                                    <input type="hidden" name="csrf_token" value="${csrfToken}">
                                    <input type="hidden" name="accion" value="responder">
                                    <input type="hidden" name="id" value="${t.id}">
                                    <select name="resultado" required>
                                        <option value="APROBADO">Aprobar</option>
                                        <option value="RECHAZADO">Rechazar</option>
                                    </select>
                                    <input type="text" name="respuesta" maxlength="400"
                                           placeholder="Respuesta obligatoria" required>
                                    <button class="btn btn-mini btn-verde" type="submit"
                                            onclick="return confirm('¿Enviar la respuesta del trámite?')">Enviar</button>
                                </form>
                            </c:when>
                            <c:otherwise>—</c:otherwise>
                        </c:choose>
                    </td>
                </c:if>
            </tr>
        </c:forEach>
    </table>
    <c:if test="${empty qTramites.rows}">
        <p>No hay solicitudes registradas.</p>
    </c:if>
</div>

<%@ include file="common/footer.jsp" %>