<%-- ==========================================================
     anteproyecto_ver.jsp - Detalle y acciones del anteproyecto
       * Estudiante: consulta (RF-15, RF-16, RF-34, RF-36)
       * Director: calificar, aprobar, rechazar (RF-18 a RF-20, RF-35)
       * Evaluador: revisar y aprobar (RF-22, RF-23, RF-24)
       * Coordinación/administrador: solo consulta (RF-28)
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

<%-- Catálogos para resolver nombres de persona (el mapa de JSTL usa
     el nombre REAL de la columna, no el alias SQL) --%>
<sql:query dataSource="${ds}" var="qUsuarios">
    SELECT id, nombre, codigo FROM usuarios ORDER BY nombre
</sql:query>
<sql:query dataSource="${ds}" var="qIdeas">
    SELECT id, titulo FROM ideas ORDER BY id
</sql:query>

<%-- ===== Cargar el anteproyecto (RF-16, RF-18) ===== --%>
<sql:query dataSource="${ds}" var="qAnt">
    SELECT * FROM anteproyectos WHERE id = ?
    <sql:param value="${param.id}"/>
</sql:query>
<c:if test="${qAnt.rowCount eq 0}">
    <c:redirect url="anteproyectos.jsp"/>
</c:if>
<c:set var="ant" value="${qAnt.rows[0]}"/>

<%-- Resolver nombres asociados --%>
<c:set var="buscarId" value="${ant.estudiante_id}"/>
<%@ include file="common/resolver.jsp" %>
<c:set var="estNombre" value="${resNom}"/>
<c:set var="estCodigo" value="${resCod}"/>
<c:set var="buscarId" value="${ant.director_id}"/>
<%@ include file="common/resolver.jsp" %>
<c:set var="dirNombre" value="${empty resNom ? 'Por asignar' : resNom}"/>
<c:set var="buscarId" value="${ant.evaluador_id}"/>
<%@ include file="common/resolver.jsp" %>
<c:set var="evalNombre" value="${empty resNom ? 'Por asignar' : resNom}"/>
<c:set var="buscarIdeaId" value="${ant.idea_id}"/>
<%@ include file="common/resolver_idea.jsp" %>
<c:set var="ideaTitulo" value="${empty resIdea ? '—' : resIdea}"/>

<%-- ===== Control de acceso: cada rol solo ve lo suyo (RNF-03) ===== --%>
<c:if test="${rol eq 'ESTUDIANTE' && ant.estudiante_id ne yo.id}">
    <c:redirect url="403.jsp"/>
</c:if>
<c:if test="${rol eq 'DIRECTOR' && ant.director_id ne yo.id}">
    <c:redirect url="403.jsp"/>
</c:if>
<c:if test="${rol eq 'EVALUADOR' && ant.evaluador_id ne yo.id}">
    <c:redirect url="403.jsp"/>
</c:if>

<%-- ===== Acciones (POST) ===== --%>
<c:if test="${pageContext.request.method eq 'POST'}">
    <%@ include file="common/verify_csrf.jsp" %>

    <%-- ---------- DIRECTOR: CALIFICAR (RF-19, RF-35) ---------- --%>
    <c:if test="${param.accion eq 'calificar'}">
        <c:if test="${rol ne 'DIRECTOR'}"><c:redirect url="403.jsp"/></c:if>
        <c:choose>
            <c:when test="${ant.estado ne 'ENVIADO'}">
                <c:redirect url="anteproyecto_ver.jsp?id=${ant.id}&error=estado"/>
            </c:when>
            <c:when test="${empty param.calificacion}">
                <c:redirect url="anteproyecto_ver.jsp?id=${ant.id}&error=sincalificacion"/>
            </c:when>
            <c:when test="${not (param.calificacion ge '0' && param.calificacion le '5')}">
                <c:redirect url="anteproyecto_ver.jsp?id=${ant.id}&error=malcalificacion"/>
            </c:when>
            <c:otherwise>
                <%-- Se almacena la calificación en el anteproyecto --%>
                <sql:update dataSource="${ds}">
                    UPDATE anteproyectos
                    SET calificacion_director = ?, observacion_director = ?
                    WHERE id = ? AND director_id = ? AND estado = 'ENVIADO'
                    <sql:param value="${param.calificacion}"/>
                    <sql:param value="${param.observacion}"/>
                    <sql:param value="${ant.id}"/>
                    <sql:param value="${yo.id}"/>
                </sql:update>
                <%-- Y en el historial de calificaciones (RF-35) --%>
                <sql:update dataSource="${ds}">
                    INSERT INTO calificaciones (anteproyecto_id, usuario_id, rol_calificador, calificacion, observacion)
                    VALUES (?, ?, 'DIRECTOR', ?, ?)
                    <sql:param value="${ant.id}"/>
                    <sql:param value="${yo.id}"/>
                    <sql:param value="${param.calificacion}"/>
                    <sql:param value="${param.observacion}"/>
                </sql:update>
                <%-- Notificación al estudiante (RF-37) --%>
                <sql:update dataSource="${ds}">
                    INSERT INTO notificaciones (usuario_id, titulo, mensaje, evento, correo_log)
                    SELECT estudiante_id, 'Anteproyecto calificado',
                           CONCAT('Tu anteproyecto fue calificado por el director: ', titulo, '.'),
                           'ANTEPROYECTO_CALIFICADO',
                           CONCAT('Correo a ', (SELECT email FROM usuarios u WHERE u.id = anteproyectos.estudiante_id),
                                  ' (SMTP pendiente)')
                    FROM anteproyectos WHERE id = ?
                    <sql:param value="${ant.id}"/>
                </sql:update>
                <c:redirect url="anteproyecto_ver.jsp?id=${ant.id}&exito=calificado"/>
            </c:otherwise>
        </c:choose>
    </c:if>

    <%-- ---------- DIRECTOR: APROBAR PARA EL EVALUADOR (RF-20) ---------- --%>
    <c:if test="${param.accion eq 'aprobar'}">
        <c:if test="${rol ne 'DIRECTOR'}"><c:redirect url="403.jsp"/></c:if>
        <c:choose>
            <c:when test="${ant.estado ne 'ENVIADO'}">
                <c:redirect url="anteproyecto_ver.jsp?id=${ant.id}&error=estado"/>
            </c:when>
            <c:when test="${empty ant['calificacion_director']}">
                <c:redirect url="anteproyecto_ver.jsp?id=${ant.id}&error=nocalifica"/>
            </c:when>
            <c:otherwise>
                <%-- Cambia de estado y, si no hay evaluador, se asigna el primero activo --%>
                <sql:update dataSource="${ds}">
                    UPDATE anteproyectos
                    SET estado = 'APROBADO_DIRECTOR',
                        evaluador_id = COALESCE(evaluador_id,
                            (SELECT id FROM (SELECT id FROM usuarios
                                             WHERE rol = 'EVALUADOR' AND activo = 1
                                             ORDER BY id LIMIT 1) t))
                    WHERE id = ? AND director_id = ? AND estado = 'ENVIADO'
                    <sql:param value="${ant.id}"/>
                    <sql:param value="${yo.id}"/>
                </sql:update>
                <%-- Notificación al evaluador asignado (RF-37) --%>
                <sql:update dataSource="${ds}">
                    INSERT INTO notificaciones (usuario_id, titulo, mensaje, evento, correo_log)
                    SELECT evaluador_id, 'Anteproyecto listo para evaluar',
                           CONCAT('El director aprobó el anteproyecto: ', titulo, '. Pendiente tu evaluación.'),
                           'EVALUADOR_ASIGNADO',
                           CONCAT('Correo a ', (SELECT email FROM usuarios u WHERE u.id = anteproyectos.evaluador_id),
                                  ' (SMTP pendiente)')
                    FROM anteproyectos WHERE id = ?
                    <sql:param value="${ant.id}"/>
                </sql:update>
                <%-- Notificación al estudiante (RF-37) --%>
                <sql:update dataSource="${ds}">
                    INSERT INTO notificaciones (usuario_id, titulo, mensaje, evento, correo_log)
                    SELECT estudiante_id, 'Anteproyecto aprobado por el director',
                           CONCAT('Tu anteproyecto: ', titulo, ' fue aprobado por el director y pasa al evaluador.'),
                           'ANTEPROYECTO_APROBADO_DIRECTOR',
                           CONCAT('Correo a ', (SELECT email FROM usuarios u WHERE u.id = anteproyectos.estudiante_id),
                                  ' (SMTP pendiente)')
                    FROM anteproyectos WHERE id = ?
                    <sql:param value="${ant.id}"/>
                </sql:update>
                <c:redirect url="anteproyecto_ver.jsp?id=${ant.id}&exito=aprobado"/>
            </c:otherwise>
        </c:choose>
    </c:if>

    <%-- ---------- DIRECTOR: RECHAZAR ---------- --%>
    <c:if test="${param.accion eq 'rechazar'}">
        <c:if test="${rol ne 'DIRECTOR'}"><c:redirect url="403.jsp"/></c:if>
        <c:choose>
            <c:when test="${ant.estado ne 'ENVIADO'}">
                <c:redirect url="anteproyecto_ver.jsp?id=${ant.id}&error=estado"/>
            </c:when>
            <c:otherwise>
                <sql:update dataSource="${ds}">
                    UPDATE anteproyectos
                    SET estado = 'RECHAZADO', observacion_director = ?
                    WHERE id = ? AND director_id = ? AND estado = 'ENVIADO'
                    <sql:param value="${param.observacion}"/>
                    <sql:param value="${ant.id}"/>
                    <sql:param value="${yo.id}"/>
                </sql:update>
                <sql:update dataSource="${ds}">
                    INSERT INTO notificaciones (usuario_id, titulo, mensaje, evento, correo_log)
                    SELECT estudiante_id, 'Anteproyecto rechazado',
                           CONCAT('Tu anteproyecto: ', titulo, ' fue rechazado. Revisa las observaciones y vuelve a enviarlo.'),
                           'ANTEPROYECTO_RECHAZADO',
                           CONCAT('Correo a ', (SELECT email FROM usuarios u WHERE u.id = anteproyectos.estudiante_id),
                                  ' (SMTP pendiente)')
                    FROM anteproyectos WHERE id = ?
                    <sql:param value="${ant.id}"/>
                </sql:update>
                <c:redirect url="anteproyecto_ver.jsp?id=${ant.id}&exito=rechazado"/>
            </c:otherwise>
        </c:choose>
    </c:if>

    <%-- ---------- EVALUADOR: REVISAR Y APROBAR (RF-22 a RF-24) ---------- --%>
    <c:if test="${param.accion eq 'evaluar'}">
        <c:if test="${rol ne 'EVALUADOR'}"><c:redirect url="403.jsp"/></c:if>
        <c:choose>
            <c:when test="${ant.estado ne 'APROBADO_DIRECTOR'}">
                <c:redirect url="anteproyecto_ver.jsp?id=${ant.id}&error=estado"/>
            </c:when>
            <c:when test="${not empty param.calificacion && not (param.calificacion ge '0' && param.calificacion le '5')}">
                <c:redirect url="anteproyecto_ver.jsp?id=${ant.id}&error=malcalificacion"/>
            </c:when>
            <c:otherwise>
                <c:choose>
                    <%-- Con calificación del evaluador --%>
                    <c:when test="${not empty param.calificacion}">
                        <sql:update dataSource="${ds}">
                            UPDATE anteproyectos
                            SET estado = 'APROBADO_EVALUADOR',
                                calificacion_evaluador = ?, observacion_evaluador = ?
                            WHERE id = ? AND evaluador_id = ? AND estado = 'APROBADO_DIRECTOR'
                            <sql:param value="${param.calificacion}"/>
                            <sql:param value="${param.observacion}"/>
                            <sql:param value="${ant.id}"/>
                            <sql:param value="${yo.id}"/>
                        </sql:update>
                        <sql:update dataSource="${ds}">
                            INSERT INTO calificaciones (anteproyecto_id, usuario_id, rol_calificador, calificacion, observacion)
                            VALUES (?, ?, 'EVALUADOR', ?, ?)
                            <sql:param value="${ant.id}"/>
                            <sql:param value="${yo.id}"/>
                            <sql:param value="${param.calificacion}"/>
                            <sql:param value="${param.observacion}"/>
                        </sql:update>
                    </c:when>
                    <%-- Solo aprobación --%>
                    <c:otherwise>
                        <sql:update dataSource="${ds}">
                            UPDATE anteproyectos
                            SET estado = 'APROBADO_EVALUADOR'
                            WHERE id = ? AND evaluador_id = ? AND estado = 'APROBADO_DIRECTOR'
                            <sql:param value="${ant.id}"/>
                            <sql:param value="${yo.id}"/>
                        </sql:update>
                    </c:otherwise>
                </c:choose>

                <%-- Notificación al estudiante (RF-37) --%>
                <sql:update dataSource="${ds}">
                    INSERT INTO notificaciones (usuario_id, titulo, mensaje, evento, correo_log)
                    SELECT estudiante_id, 'Anteproyecto aprobado por el evaluador',
                           CONCAT('¡Buen trabajo! Tu anteproyecto: ', titulo, ' fue aprobado por el evaluador.'),
                           'ANTEPROYECTO_APROBADO_EVALUADOR',
                           CONCAT('Correo a ', (SELECT email FROM usuarios u WHERE u.id = anteproyectos.estudiante_id),
                                  ' (SMTP pendiente)')
                    FROM anteproyectos WHERE id = ?
                    <sql:param value="${ant.id}"/>
                </sql:update>
                <%-- Notificación a coordinación (RF-37) --%>
                <sql:update dataSource="${ds}">
                    INSERT INTO notificaciones (usuario_id, titulo, mensaje, evento, correo_log)
                    SELECT u.id, 'Anteproyecto finalizado', ?, 'ANTEPROYECTO_FINALIZADO',
                           CONCAT('Correo a ', u.email, ' (SMTP pendiente)')
                    FROM usuarios u
                    WHERE u.rol = 'COORDINACION' AND u.activo = 1
                    <sql:param value="El anteproyecto ${ant.titulo} de ${estNombre} fue aprobado por el evaluador."/>
                </sql:update>
                <c:redirect url="anteproyecto_ver.jsp?id=${ant.id}&exito=evaluado"/>
            </c:otherwise>
        </c:choose>
    </c:if>
</c:if>

<%-- ===== Historial de calificaciones (RF-35) ===== --%>
<sql:query dataSource="${ds}" var="qCalif">
    SELECT c.*, u.nombre
    FROM calificaciones c JOIN usuarios u ON u.id = c.usuario_id
    WHERE c.anteproyecto_id = ?
    ORDER BY c.creado_en
    <sql:param value="${ant.id}"/>
</sql:query>

<%@ include file="common/header.jsp" %>

<h1>Anteproyecto</h1>
<p class="subtitulo">Detalle completo, estados y acciones del proceso.</p>

<c:if test="${param.exito eq 'calificado'}">
    <div class="aviso aviso-ok">Calificación guardada (RF-19, RF-35).</div>
</c:if>
<c:if test="${param.exito eq 'aprobado'}">
    <div class="aviso aviso-ok">Anteproyecto aprobado. Pasó al evaluador y se notificó por correo (RF-20, RF-37).</div>
</c:if>
<c:if test="${param.exito eq 'rechazado'}">
    <div class="aviso aviso-info">Anteproyecto rechazado. El estudiante fue notificado para correcciones.</div>
</c:if>
<c:if test="${param.exito eq 'evaluado'}">
    <div class="aviso aviso-ok">Anteproyecto aprobado por el evaluador. Estudiante y coordinación fueron notificados (RF-23, RF-24).</div>
</c:if>
<c:if test="${param.error eq 'sincalificacion'}">
    <div class="aviso aviso-error">Debes ingresar una calificación (0 a 5) antes de continuar.</div>
</c:if>
<c:if test="${param.error eq 'malcalificacion'}">
    <div class="aviso aviso-error">La calificación debe estar entre 0 y 5.</div>
</c:if>
<c:if test="${param.error eq 'nocalifica'}">
    <div class="aviso aviso-error">Primero califica el anteproyecto para poder aprobarlo (RF-19 → RF-20).</div>
</c:if>
<c:if test="${param.error eq 'estado'}">
    <div class="aviso aviso-error">La operación no está permitida en el estado actual del anteproyecto.</div>
</c:if>

<%-- ================= FICHA ================= --%>
<div class="panel">
    <h2 style="margin-top:0">Información general</h2>
    <p class="dato"><b>Estado:</b>
        <c:set var="est" value="${ant.estado}"/>
        <span class="estado estado-${est}"><%@ include file="common/estado.jsp" %></span>
    </p>
    <p class="dato"><b>Título:</b> <c:out value="${ant.titulo}"/></p>
    <p class="dato"><b>Idea:</b> <c:out value="${ideaTitulo}"/></p>
    <p class="dato"><b>Estudiante:</b> <c:out value="${estNombre}"/></p>
    <p class="dato"><b>Código:</b> <c:out value="${empty estCodigo ? '—' : estCodigo}"/></p>
    <p class="dato"><b>Director:</b> <c:out value="${dirNombre}"/></p>
    <p class="dato"><b>Evaluador:</b> <c:out value="${evalNombre}"/></p>
    <p class="dato"><b>Enviado:</b>
        <fmt:formatDate value="${ant['creado_en']}" pattern="dd/MM/yyyy HH:mm"/>
    </p>
    <c:if test="${not empty ant.documento}">
        <p class="dato"><b>Documento:</b>
            <c:choose>
                <c:when test="${fn:startsWith(ant.documento, 'http')}">
                    <a class="enlace-doc" href="${ant.documento}" target="_blank">Abrir enlace</a>
                </c:when>
                <c:when test="${fn:contains(ant.documento, '/')}">
                    <c:url value="${ant.documento}" var="docUrl"/>
                    <a class="enlace-doc" href="${docUrl}" target="_blank">Descargar / ver</a>
                </c:when>
                <c:otherwise>
                    <c:url value="/uploads/${ant.documento}" var="docUrl"/>
                    <a class="enlace-doc" href="${docUrl}" target="_blank">Descargar / ver</a>
                </c:otherwise>
            </c:choose>
        </p>
    </c:if>

    <h2>Calificaciones</h2>
    <p class="dato"><b>Director:</b>
        <c:choose>
            <c:when test="${not empty ant['calificacion_director']}">
                <fmt:formatNumber value="${ant['calificacion_director']}" maxFractionDigits="1"/> / 5
                <c:if test="${not empty ant['observacion_director']}">
                    — <i><c:out value="${ant['observacion_director']}"/></i>
                </c:if>
            </c:when>
            <c:otherwise>Sin calificar</c:otherwise>
        </c:choose>
    </p>
    <p class="dato"><b>Evaluador:</b>
        <c:choose>
            <c:when test="${not empty ant['calificacion_evaluador']}">
                <fmt:formatNumber value="${ant['calificacion_evaluador']}" maxFractionDigits="1"/> / 5
                <c:if test="${not empty ant['observacion_evaluador']}">
                    — <i><c:out value="${ant['observacion_evaluador']}"/></i>
                </c:if>
            </c:when>
            <c:otherwise>
                <c:choose>
                    <c:when test="${ant.estado eq 'APROBADO_EVALUADOR'}">Aprobado sin calificación numérica</c:when>
                    <c:otherwise>Pendiente</c:otherwise>
                </c:choose>
            </c:otherwise>
        </c:choose>
    </p>

    <c:if test="${not empty qCalif.rows}">
        <table style="margin-top:12px">
            <tr><th>Quién calificó</th><th>Rol</th><th>Calificación</th><th>Observación</th><th>Fecha</th></tr>
            <c:forEach items="${qCalif.rows}" var="c">
                <tr>
                    <td><c:out value="${c.nombre}"/></td>
                    <td><c:choose>
                        <c:when test="${c.rol_calificador eq 'DIRECTOR'}">Director</c:when>
                        <c:otherwise>Evaluador</c:otherwise>
                    </c:choose></td>
                    <td><fmt:formatNumber value="${c.calificacion}" maxFractionDigits="1"/> / 5</td>
                    <td><c:out value="${empty c.observacion ? '—' : c.observacion}"/></td>
                    <td><fmt:formatDate value="${c['creado_en']}" pattern="dd/MM/yyyy HH:mm"/></td>
                </tr>
            </c:forEach>
        </table>
    </c:if>
</div>

<%-- ================= ACCIONES DEL DIRECTOR (RF-19, RF-20) ================= --%>
<c:if test="${rol eq 'DIRECTOR' && ant.estado eq 'ENVIADO'}">
    <div class="panel">
        <h2 style="margin-top:0">Acciones del director</h2>

        <h3>1. Calificar (RF-19)</h3>
        <form method="post" action="anteproyecto_ver.jsp?id=${ant.id}">
            <input type="hidden" name="csrf_token" value="${csrfToken}">
            <input type="hidden" name="accion" value="calificar">
            <label for="calificacion">Calificación (0 a 5)</label>
            <input type="number" id="calificacion" name="calificacion" min="0" max="5" step="0.1"
                   required value="${ant['calificacion_director']}">
            <label for="observacion">Observaciones</label>
            <textarea id="observacion" name="observacion" maxlength="1000"
                      placeholder="Comentarios sobre el anteproyecto"><c:out value="${ant['observacion_director']}"/></textarea>
            <button class="btn" type="submit">Guardar calificación</button>
        </form>

        <h3>2. Decisión</h3>
        <form method="post" action="anteproyecto_ver.jsp?id=${ant.id}" style="display:inline"
              onsubmit="return confirm('¿Aprobar este anteproyecto para el evaluador?')">
            <input type="hidden" name="csrf_token" value="${csrfToken}">
            <input type="hidden" name="accion" value="aprobar">
            <button class="btn btn-verde" type="submit">Aprobar para el evaluador (RF-20)</button>
        </form>
        <form method="post" action="anteproyecto_ver.jsp?id=${ant.id}">
            <input type="hidden" name="csrf_token" value="${csrfToken}">
            <input type="hidden" name="accion" value="rechazar">
            <label for="obsRech">Motivo del rechazo (opcional, se lo verá el estudiante)</label>
            <textarea id="obsRech" name="observacion" maxlength="1000"><c:out value="${ant['observacion_director']}"/></textarea>
            <button class="btn btn-rojo" type="submit"
                    onclick="return confirm('¿Rechazar este anteproyecto?')">Rechazar</button>
        </form>
        <p class="dato" style="margin-top:8px">
            <i>Si no hay evaluador asignado, el sistema asigna automáticamente el primero disponible
               (coordinación puede cambiarlo).</i>
        </p>
    </div>
</c:if>

<%-- ================= ACCIONES DEL EVALUADOR (RF-22 a RF-24) ================= --%>
<c:if test="${rol eq 'EVALUADOR' && ant.estado eq 'APROBADO_DIRECTOR'}">
    <div class="panel">
        <h2 style="margin-top:0">Evaluación del anteproyecto (RF-22)</h2>
        <form method="post" action="anteproyecto_ver.jsp?id=${ant.id}">
            <input type="hidden" name="csrf_token" value="${csrfToken}">
            <input type="hidden" name="accion" value="evaluar">
            <label for="califEval">Calificación (opcional, 0 a 5)</label>
            <input type="number" id="califEval" name="calificacion" min="0" max="5" step="0.1">
            <label for="obsEval">Observaciones</label>
            <textarea id="obsEval" name="observacion" maxlength="1000"></textarea>
            <button class="btn btn-verde" type="submit"
                    onclick="return confirm('¿Aprobar el anteproyecto? Se notificará al estudiante y a coordinación.')">
                Aprobar anteproyecto (RF-23)
            </button>
        </form>
    </div>
</c:if>

<%-- ================= AVISOS SEGÚN ESTADO ================= --%>
<c:if test="${rol eq 'ESTUDIANTE'}">
    <div class="aviso aviso-info">
        Este es el estado de tu anteproyecto (RF-34, RF-36).
        <c:if test="${ant.estado eq 'BORRADOR' || ant.estado eq 'RECHAZADO'}">
            <a href="anteproyecto_form.jsp?id=${ant.id}">Completar y enviar</a>
        </c:if>
    </div>
</c:if>
<c:if test="${ant.estado eq 'APROBADO_EVALUADOR'}">
    <div class="aviso aviso-ok">Proceso del anteproyecto completado: aprobado por el director y por el evaluador.</div>
    <div class="panel">
        <h2 style="margin-top:0">Próximos pasos</h2>
        <p class="dato">El anteproyecto ha sido aprobado. Ahora sigue la entrega del documento final.</p>
        <c:if test="${rol eq 'ESTUDIANTE'}">
            <a class="btn btn-verde" href="entrega_final.jsp?id=${ant.id}">Entregar documento final</a>
        </c:if>
        <c:if test="${rol eq 'ADMIN' || rol eq 'COORDINACION' || rol eq 'DIRECTOR'}">
            <a class="btn" href="entrega_final.jsp?id=${ant.id}">Ver / Revisar entrega final</a>
        </c:if>
    </div>
</c:if>
<c:if test="${ant.estado eq 'REVISIÓN_FINAL'}">
    <div class="aviso aviso-ok">Documento final aprobado. Se puede programar la sustentación.</div>
    <div class="panel">
        <h2 style="margin-top:0">Próximos pasos</h2>
        <c:if test="${rol eq 'ADMIN' || rol eq 'COORDINACION'}">
            <a class="btn btn-verde" href="sustentacion.jsp?id=${ant.id}">Programar sustentación</a>
        </c:if>
        <c:if test="${rol eq 'ESTUDIANTE'}">
            <a class="btn" href="sustentacion.jsp?id=${ant.id}">Ver sustentación</a>
        </c:if>
    </div>
</c:if>
<c:if test="${ant.estado eq 'SUSTENTACIÓN'}">
    <div class="aviso aviso-ok">Sustentación programada.</div>
    <div class="panel">
        <h2 style="margin-top:0">Ver sustentación</h2>
        <a class="btn" href="sustentacion.jsp?id=${ant.id}">Ver detalle / Registrar resultado</a>
    </div>
</c:if>
<c:if test="${ant.estado eq 'FINALIZADO'}">
    <div class="aviso aviso-ok">¡Proceso completado! El trabajo de grado ha sido finalizado.</div>
</c:if>

<%@ include file="common/footer.jsp" %>
