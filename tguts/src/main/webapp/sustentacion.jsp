<%-- ==========================================================
     sustentacion.jsp - Acto de sustentación pública
     Flujo: tras REVISIÓN_FINAL → SUSTENTACIÓN → FINALIZADO
     Roles:
       - Coordinación/Administrador: programa la sustentación (fecha, hora, lugar)
       - Director/Evaluador: registran resultado
       - Estudiante: consulta fecha/lugar/resultado
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

<%-- Segundo: buscar sustentación si existe --%>
<sql:query dataSource="${ds}" var="qSust">
    SELECT s.*, a.estado as ant_estado, a.titulo as ant_titulo
    FROM sustentacion s
    JOIN anteproyectos a ON a.id = s.anteproyecto_id
    WHERE s.anteproyecto_id = ?
    <sql:param value="${param.id}"/>
</sql:query>
<c:set var="sust" value="${qSust.rowCount gt 0 ? qSust.rows[0] : null}"/>

<%-- Coordinación/Admin puede ver para programar solo si el estado es Revisión Final --%>
<c:if test="${(rol eq 'ADMIN' || rol eq 'COORDINACION') && empty sust && ant.estado ne 'REVISIÓN_FINAL'}">
    <c:redirect url="anteproyectos.jsp"/>
</c:if>
<%-- Director/Evaluador/Estudiante solo ven si ya existe la sustentación --%>
<c:if test="${rol ne 'ADMIN' && rol ne 'COORDINACION' && empty sust}">
    <c:redirect url="anteproyectos.jsp"/>
</c:if>

<%-- Procesar POST programar (coordinación/administrador) --%>
<c:if test="${pageContext.request.method eq 'POST' && param.accion eq 'programar'}">
    <%@ include file="common/verify_csrf.jsp" %>
    <c:if test="${rol ne 'ADMIN' && rol ne 'COORDINACION'}">
        <c:redirect url="403.jsp"/>
    </c:if>
    <c:choose>
        <c:when test="${not empty sust}">
            <c:set var="error" value="Este anteproyecto ya tiene una sustentación programada."/>
        </c:when>
        <c:when test="${ant.estado ne 'REVISIÓN_FINAL'}">
            <c:set var="error" value="La sustentación solo puede programarse cuando el trabajo está en Revisión Final."/>
        </c:when>
        <c:when test="${empty param.fecha || empty param.hora || empty param.lugar}">
            <c:set var="error" value="Fecha, hora y lugar son obligatorios."/>
        </c:when>
        <c:otherwise>
            <sql:transaction dataSource="${ds}">
                <sql:update>
                    INSERT INTO sustentacion (anteproyecto_id, fecha, hora, lugar, resultado)
                    VALUES (?, ?, ?, ?, 'PENDIENTE')
                    <sql:param value="${ant.id}"/>
                    <sql:param value="${param.fecha}"/>
                    <sql:param value="${param.hora}"/>
                    <sql:param value="${param.lugar}"/>
                </sql:update>
                <%-- Guarda de estado: solo cambia si sigue en Revisión Final. --%>
                <sql:update var="filasSust">
                    UPDATE anteproyectos SET estado = 'SUSTENTACIÓN'
                    WHERE id = ? AND estado = 'REVISIÓN_FINAL'
                    <sql:param value="${ant.id}"/>
                </sql:update>
                <c:if test="${filasSust gt 0}">
                    <sql:update>
                        INSERT INTO notificaciones (usuario_id, titulo, mensaje, evento, correo_log)
                        SELECT estudiante_id, 'Sustentación programada',
                               CONCAT('Tu sustentación fue programada para el ', ?, ' a las ', ?, ' en ', ?, '.'),
                               'SUSTENTACION_PROGRAMADA',
                               CONCAT('Correo a ', email, ' (SMTP pendiente)')
                        FROM anteproyectos a JOIN usuarios u ON u.id = a.estudiante_id
                        WHERE a.id = ?
                        <sql:param value="${param.fecha}"/>
                        <sql:param value="${param.hora}"/>
                        <sql:param value="${param.lugar}"/>
                        <sql:param value="${ant.id}"/>
                    </sql:update>
                    <sql:update>
                        INSERT INTO notificaciones (usuario_id, titulo, mensaje, evento, correo_log)
                        SELECT director_id, 'Sustentación de tu dirigido programada',
                               CONCAT('La sustentación del anteproyecto ', (SELECT titulo FROM anteproyectos WHERE id = ?), ' es el ', ?, ' a las ', ?, '.'),
                               'SUSTENTACION_PROGRAMADA',
                               CONCAT('Correo a ', email, ' (SMTP pendiente)')
                        FROM anteproyectos a JOIN usuarios u ON u.id = a.director_id
                        WHERE a.id = ?
                        <sql:param value="${ant.id}"/>
                        <sql:param value="${param.fecha}"/>
                        <sql:param value="${param.hora}"/>
                        <sql:param value="${ant.id}"/>
                    </sql:update>
                    <c:if test="${not empty ant.evaluador_id}">
                        <sql:update>
                            INSERT INTO notificaciones (usuario_id, titulo, mensaje, evento, correo_log)
                            SELECT evaluador_id, 'Sustentación a evaluar programada',
                                   CONCAT('La sustentación a evaluar es el ', ?, ' a las ', ?, ' en ', ?, '.'),
                                   'SUSTENTACION_PROGRAMADA',
                                   CONCAT('Correo a ', email, ' (SMTP pendiente)')
                            FROM anteproyectos a JOIN usuarios u ON u.id = a.evaluador_id
                            WHERE a.id = ?
                            <sql:param value="${param.fecha}"/>
                            <sql:param value="${param.hora}"/>
                            <sql:param value="${param.lugar}"/>
                            <sql:param value="${ant.id}"/>
                        </sql:update>
                    </c:if>
                </c:if>
            </sql:transaction>
            <c:choose>
                <c:when test="${filasSust gt 0}">
                    <c:redirect url="sustentacion.jsp?id=${ant.id}&exito=programada"/>
                </c:when>
                <c:otherwise>
                    <c:set var="error" value="No se pudo programar la sustentación; el estado cambió."/>
                </c:otherwise>
            </c:choose>
        </c:otherwise>
    </c:choose>
</c:if>

<%-- Procesar POST registrar resultado (director/evaluador/coordinación) --%>
<c:if test="${pageContext.request.method eq 'POST' && param.accion eq 'resultado'}">
    <%@ include file="common/verify_csrf.jsp" %>
    <c:if test="${rol ne 'ADMIN' && rol ne 'COORDINACION' && rol ne 'DIRECTOR' && rol ne 'EVALUADOR'}">
        <c:redirect url="403.jsp"/>
    </c:if>
    <c:choose>
        <c:when test="${empty param.resultado || empty param.sust_id}">
            <c:set var="error" value="Resultado y sustentación son obligatorios."/>
        </c:when>
        <c:when test="${param.resultado ne 'APROBADO' && param.resultado ne 'RECHAZADO' && param.resultado ne 'PENDIENTE'}">
            <c:set var="error" value="Resultado no válido."/>
        </c:when>
        <c:when test="${empty sust || sust.id ne param.sust_id}">
            <c:set var="error" value="La sustentación indicada no pertenece a este anteproyecto."/>
        </c:when>
        <c:when test="${ant.estado ne 'SUSTENTACIÓN'}">
            <c:set var="error" value="El trabajo no está en el estado de sustentación."/>
        </c:when>
        <c:otherwise>
            <sql:transaction dataSource="${ds}">
                <sql:update var="filasRes">
                    UPDATE sustentacion
                    SET resultado = ?, observaciones = ?
                    WHERE id = ? AND anteproyecto_id = ?
                    <sql:param value="${param.resultado}"/>
                    <sql:param value="${param.observaciones}"/>
                    <sql:param value="${param.sust_id}"/>
                    <sql:param value="${ant.id}"/>
                </sql:update>
                <c:if test="${param.resultado eq 'APROBADO' && filasRes gt 0}">
                    <sql:update>
                        UPDATE anteproyectos SET estado = 'FINALIZADO'
                        WHERE id = ? AND estado = 'SUSTENTACIÓN'
                        <sql:param value="${ant.id}"/>
                    </sql:update>
                </c:if>
                <c:if test="${filasRes gt 0}">
                    <sql:update>
                        INSERT INTO notificaciones (usuario_id, titulo, mensaje, evento, correo_log)
                        SELECT estudiante_id, 'Resultado de sustentación',
                               CONCAT('Tu sustentación fue: ', ?, '. Observaciones: ', ?),
                               'RESULTADO_SUSTENTACION',
                               CONCAT('Correo a ', email, ' (SMTP pendiente)')
                        FROM anteproyectos a JOIN usuarios u ON u.id = a.estudiante_id
                        WHERE a.id = ?
                        <sql:param value="${param.resultado}"/>
                        <sql:param value="${param.observaciones}"/>
                        <sql:param value="${ant.id}"/>
                    </sql:update>
                </c:if>
            </sql:transaction>
            <c:choose>
                <c:when test="${filasRes gt 0}">
                    <c:redirect url="sustentacion.jsp?id=${ant.id}&exito=resultado"/>
                </c:when>
                <c:otherwise>
                    <c:set var="error" value="No se pudo registrar el resultado."/>
                </c:otherwise>
            </c:choose>
        </c:otherwise>
    </c:choose>
</c:if>

<%@ include file="common/header.jsp" %>

<h1>Sustentación</h1>
<p class="subtitulo">Anteproyecto: <c:out value="${ant.titulo}"/> — Estado: <c:set var="est" value="${ant.estado}"/><span class="estado estado-${est}"><%@ include file="common/estado.jsp" %></span></p>

<c:if test="${param.exito eq 'programada'}">
    <div class="aviso aviso-ok">Sustentación programada. Notificaciones enviadas a estudiante, director y evaluador.</div>
</c:if>
<c:if test="${param.exito eq 'resultado'}">
    <div class="aviso aviso-ok">Resultado registrado. El estudiante ha sido notificado.</div>
</c:if>
<c:if test="${not empty error}">
    <div class="aviso aviso-error"><c:out value="${error}"/></div>
</c:if>

<c:choose>
    <c:when test="${empty sust}">
        <c:if test="${rol eq 'ADMIN' || rol eq 'COORDINACION'}">
            <div class="panel">
                <h2 style="margin-top:0">Programar sustentación</h2>
                <form method="post" action="sustentacion.jsp?id=${param.id}">
                    <input type="hidden" name="csrf_token" value="${csrfToken}">
                    <input type="hidden" name="accion" value="programar">
                    <div class="form-fila">
                        <div>
                            <label for="fecha">Fecha</label>
                            <input type="date" id="fecha" name="fecha" required>
                        </div>
                        <div>
                            <label for="hora">Hora</label>
                            <input type="time" id="hora" name="hora" required>
                        </div>
                    </div>
                    <label for="lugar">Lugar (aula, sala, enlace virtual...)</label>
                    <input type="text" id="lugar" name="lugar" required maxlength="200"
                           placeholder="Ej.: Auditorio Principal / Google Meet: abc-def-ghi">
                    <button class="btn btn-verde" type="submit">Programar sustentación</button>
                    <a class="btn btn-gris" href="anteproyectos.jsp">Volver</a>
                </form>
            </div>
        </c:if>
        <c:if test="${rol ne 'ADMIN' && rol ne 'COORDINACION'}">
            <div class="aviso aviso-info">La sustentación aún no ha sido programada por coordinación.</div>
        </c:if>
    </c:when>

    <c:otherwise>
        <div class="panel">
            <h2 style="margin-top:0">Detalle de la sustentación</h2>
            <p class="dato"><b>Fecha:</b> <fmt:formatDate value="${sust.fecha}" pattern="dd/MM/yyyy"/></p>
            <p class="dato"><b>Hora:</b> <fmt:formatDate value="${sust.hora}" pattern="HH:mm"/></p>
            <p class="dato"><b>Lugar:</b> <c:out value="${sust.lugar}"/></p>
            <p class="dato"><b>Resultado:</b>
                <span class="estado estado-${sust.resultado}"><c:out value="${sust.resultado}"/></span>
            </p>
            <c:if test="${not empty sust.observaciones}">
                <p class="dato"><b>Observaciones:</b> <c:out value="${sust.observaciones}"/></p>
            </c:if>
        </div>

        <c:if test="${rol eq 'ADMIN' || rol eq 'COORDINACION' || rol eq 'DIRECTOR' || rol eq 'EVALUADOR'}">
            <div class="panel">
                <h2 style="margin-top:0">Registrar resultado</h2>
                <form method="post" action="sustentacion.jsp?id=${param.id}">
                    <input type="hidden" name="csrf_token" value="${csrfToken}">
                    <input type="hidden" name="accion" value="resultado">
                    <input type="hidden" name="sust_id" value="${sust.id}">
                    <label for="resultado">Resultado</label>
                    <select id="resultado" name="resultado" required>
                        <option value="APROBADO" ${sust.resultado eq 'APROBADO' ? 'selected' : ''}>Aprobado → Finalizado</option>
                        <option value="RECHAZADO" ${sust.resultado eq 'RECHAZADO' ? 'selected' : ''}>Rechazado</option>
                        <option value="PENDIENTE" ${sust.resultado eq 'PENDIENTE' ? 'selected' : ''}>Pendiente</option>
                    </select>
                    <label for="observaciones">Observaciones</label>
                    <textarea id="observaciones" name="observaciones" rows="4"
                              placeholder="Fundamentación del resultado...">${fn:escapeXml(sust.observaciones)}</textarea>
                    <button class="btn btn-verde" type="submit">Guardar resultado</button>
                </form>
            </div>
        </c:if>
    </c:otherwise>
</c:choose>

<%@ include file="common/footer.jsp" %>