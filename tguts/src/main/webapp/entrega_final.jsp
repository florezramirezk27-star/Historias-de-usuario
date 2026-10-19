<%-- ==========================================================
     entrega_final.jsp - Entrega del documento final
     Flujo: tras APROBADO_EVALUADOR → ENTREGA_DOCUMENTO_FINAL
     Roles:
       - Estudiante: registra el documento final (archivo o URL)
       - Director/Coordinación: revisan y aprueban/observan
       - Evaluador: consulta
     El formulario usa multipart/form-data; common/config.jsp procesa
     los campos (Map "campos") y guarda el archivo con validación.
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

<%-- El estudiante puede crear la primera entrega o reemplazar una entrega observada. --%>
<c:if test="${rol eq 'ESTUDIANTE' && not ((ant.estado eq 'APROBADO_EVALUADOR' && empty entrega) || (ant.estado eq 'ENTREGA_DOCUMENTO_FINAL' && not empty entrega && entrega.estado eq 'OBSERVADO'))}">
    <c:redirect url="anteproyectos.jsp"/>
</c:if>

<%-- Procesar la corrección de un documento observado. Conserva el mismo
     registro de entrega y lo devuelve a revisión. --%>
<c:if test="${pageContext.request.method eq 'POST' && campos.accion eq 'corregir'}">
    <%@ include file="common/verify_csrf.jsp" %>
    <c:if test="${rol ne 'ESTUDIANTE'}"><c:redirect url="403.jsp"/></c:if>
    <c:set var="docCorregido" value="${campos.documento}"/>
    <c:if test="${not empty requestScope.archivo_subido}"><c:set var="docCorregido" value="${requestScope.archivo_subido}"/></c:if>
    <c:choose>
        <c:when test="${not empty requestScope.archivo_error}"><c:set var="error" value="${requestScope.archivo_error}"/></c:when>
        <c:when test="${ant.estado ne 'ENTREGA_DOCUMENTO_FINAL' || empty entrega || entrega.estado ne 'OBSERVADO'}"><c:set var="error" value="No hay una entrega observada disponible para corregir."/></c:when>
        <c:when test="${empty campos.titulo || empty docCorregido}"><c:set var="error" value="El título y el documento corregido son obligatorios."/></c:when>
        <c:when test="${empty requestScope.archivo_subido && not (fn:startsWith(campos.documento, 'http://') || fn:startsWith(campos.documento, 'https://'))}"><c:set var="error" value="La URL debe comenzar por http:// o https://."/></c:when>
        <c:otherwise>
            <sql:transaction dataSource="${ds}">
                <sql:update var="filasCorregidas">
                    UPDATE entrega_final SET titulo = ?, documento = ?, estado = 'ENTREGADO', observaciones = NULL, revisado_por = NULL, fecha_entrega = CURRENT_TIMESTAMP
                    WHERE id = ? AND anteproyecto_id = ? AND estado = 'OBSERVADO'
                    <sql:param value="${campos.titulo}"/><sql:param value="${docCorregido}"/><sql:param value="${entrega.id}"/><sql:param value="${ant.id}"/>
                </sql:update>
                <c:if test="${filasCorregidas gt 0}">
                    <sql:update>
                        INSERT INTO notificaciones (usuario_id, titulo, mensaje, evento, correo_log)
                        SELECT director_id, 'Documento final corregido', CONCAT('El estudiante cargó una corrección: ', titulo, '.'), 'ENTREGA_FINAL_CORREGIDA', CONCAT('Correo a ', email, ' (SMTP pendiente)')
                        FROM anteproyectos a JOIN usuarios u ON u.id = a.director_id WHERE a.id = ?
                        <sql:param value="${ant.id}"/>
                    </sql:update>
                </c:if>
            </sql:transaction>
            <c:choose><c:when test="${filasCorregidas gt 0}"><c:redirect url="entrega_final.jsp?id=${ant.id}&exito=corregido"/></c:when><c:otherwise><c:set var="error" value="No se pudo registrar la corrección."/></c:otherwise></c:choose>
        </c:otherwise>
    </c:choose>
</c:if>

<%-- Procesar POST crear entrega (estudiante registra archivo o URL) --%>
<c:if test="${pageContext.request.method eq 'POST' && campos.accion eq 'crear'}">
    <%@ include file="common/verify_csrf.jsp" %>
    <c:if test="${rol ne 'ESTUDIANTE'}">
        <c:redirect url="403.jsp"/>
    </c:if>

    <c:set var="docFinal" value="${campos.documento}"/>
    <c:if test="${not empty requestScope.archivo_subido}">
        <c:set var="docFinal" value="${requestScope.archivo_subido}"/>
    </c:if>

    <c:choose>
        <c:when test="${not empty requestScope.archivo_error}">
            <c:set var="error" value="${requestScope.archivo_error}"/>
        </c:when>
        <c:when test="${ant.estado ne 'APROBADO_EVALUADOR' || not empty entrega}">
            <c:set var="error" value="La entrega final no está permitida en el estado actual."/>
        </c:when>
        <c:when test="${empty campos.titulo}">
            <c:set var="error" value="El título es obligatorio."/>
        </c:when>
        <c:when test="${empty docFinal}">
            <c:set var="error" value="Debes subir el archivo o indicar la URL del documento final."/>
        </c:when>
        <c:when test="${empty requestScope.archivo_subido && not (fn:startsWith(campos.documento, 'http://') || fn:startsWith(campos.documento, 'https://'))}">
            <c:set var="error" value="La URL del documento final debe comenzar por http:// o https://."/>
        </c:when>
        <c:otherwise>
            <sql:transaction dataSource="${ds}">
                <sql:update>
                    INSERT INTO entrega_final (anteproyecto_id, titulo, documento, estado)
                    VALUES (?, ?, ?, 'ENTREGADO')
                    <sql:param value="${ant.id}"/>
                    <sql:param value="${campos.titulo}"/>
                    <sql:param value="${docFinal}"/>
                </sql:update>
                <sql:update var="filasEstado">
                    UPDATE anteproyectos SET estado = 'ENTREGA_DOCUMENTO_FINAL'
                    WHERE id = ? AND estado = 'APROBADO_EVALUADOR'
                    <sql:param value="${ant.id}"/>
                </sql:update>
                <c:if test="${filasEstado gt 0}">
                    <sql:update>
                        INSERT INTO notificaciones (usuario_id, titulo, mensaje, evento, correo_log)
                        SELECT director_id, 'Documento final entregado',
                               CONCAT('El estudiante entregó el documento final: ', ?, '.'),
                               'ENTREGA_FINAL', CONCAT('Correo a ', email, ' (SMTP pendiente)')
                        FROM anteproyectos a JOIN usuarios u ON u.id = a.director_id
                        WHERE a.id = ?
                        <sql:param value="${campos.titulo}"/>
                        <sql:param value="${ant.id}"/>
                    </sql:update>
                </c:if>
            </sql:transaction>
            <c:redirect url="entrega_final.jsp?id=${ant.id}&exito=entregado"/>
        </c:otherwise>
    </c:choose>
</c:if>

<%-- Procesar POST revisar (director/coordinación) --%>
<c:if test="${pageContext.request.method eq 'POST' && campos.accion eq 'revisar'}">
    <%@ include file="common/verify_csrf.jsp" %>
    <c:if test="${rol ne 'ADMIN' && rol ne 'COORDINACION' && rol ne 'DIRECTOR'}">
        <c:redirect url="403.jsp"/>
    </c:if>
    <c:choose>
        <c:when test="${empty campos.estado_nuevo || empty campos.entrega_id}">
            <c:set var="error" value="Datos incompletos."/>
        </c:when>
        <c:when test="${campos.estado_nuevo ne 'EN_REVISION' && campos.estado_nuevo ne 'OBSERVADO' && campos.estado_nuevo ne 'APROBADO'}">
            <c:set var="error" value="Estado de revisión no válido."/>
        </c:when>
        <c:when test="${empty entrega || entrega.id ne campos.entrega_id}">
            <c:set var="error" value="La entrega indicada no pertenece a este anteproyecto."/>
        </c:when>
        <c:otherwise>
            <sql:transaction dataSource="${ds}">
                <sql:update var="filasEntrega">
                    UPDATE entrega_final
                    SET estado = ?, observaciones = ?, revisado_por = ?
                    WHERE id = ? AND anteproyecto_id = ?
                    <sql:param value="${campos.estado_nuevo}"/>
                    <sql:param value="${campos.observaciones}"/>
                    <sql:param value="${yo.id}"/>
                    <sql:param value="${campos.entrega_id}"/>
                    <sql:param value="${ant.id}"/>
                </sql:update>

                <c:if test="${campos.estado_nuevo eq 'APROBADO' && filasEntrega gt 0}">
                    <sql:update>
                        UPDATE anteproyectos SET estado = 'REVISIÓN_FINAL'
                        WHERE id = ? AND estado = 'ENTREGA_DOCUMENTO_FINAL'
                        <sql:param value="${ant.id}"/>
                    </sql:update>
                </c:if>

                <c:if test="${filasEntrega gt 0}">
                    <sql:update>
                        INSERT INTO notificaciones (usuario_id, titulo, mensaje, evento, correo_log)
                        SELECT estudiante_id, 'Revisión del documento final',
                               CONCAT('Tu documento final fue ', LOWER(?), '. Observaciones: ', ?),
                               'REVISION_FINAL', CONCAT('Correo a ', email, ' (SMTP pendiente)')
                        FROM anteproyectos a JOIN usuarios u ON u.id = a.estudiante_id
                        WHERE a.id = ?
                        <sql:param value="${campos.estado_nuevo}"/>
                        <sql:param value="${campos.observaciones}"/>
                        <sql:param value="${ant.id}"/>
                    </sql:update>
                </c:if>
            </sql:transaction>

            <c:choose>
                <c:when test="${filasEntrega gt 0}">
                    <c:redirect url="entrega_final.jsp?id=${ant.id}&exito=revisado"/>
                </c:when>
                <c:otherwise>
                    <c:set var="error" value="No se pudo actualizar la entrega."/>
                </c:otherwise>
            </c:choose>
        </c:otherwise>
    </c:choose>
</c:if>

<%@ include file="common/header.jsp" %>

<h1>Entrega del documento final</h1>
<p class="subtitulo">Anteproyecto: <c:out value="${ant.titulo}"/> — Estado: <c:set var="est" value="${ant.estado}"/><span class="estado estado-${est}"><%@ include file="common/estado.jsp" %></span></p>

<c:if test="${param.exito eq 'entregado'}">
    <div class="aviso aviso-ok">Documento final entregado. El director ha sido notificado para su revisión.</div>
</c:if>
<c:if test="${param.exito eq 'revisado'}">
    <div class="aviso aviso-ok">Revisión registrada. El estudiante ha sido notificado.</div>
</c:if>
<c:if test="${param.exito eq 'corregido'}">
    <div class="aviso aviso-ok">Corrección enviada al director para una nueva revisión.</div>
</c:if>
<c:if test="${not empty error}">
    <div class="aviso aviso-error"><c:out value="${error}"/></div>
</c:if>

<c:choose>
    <c:when test="${empty entrega}">
        <c:if test="${rol eq 'ESTUDIANTE'}">
            <div class="panel">
                <h2 style="margin-top:0">Entregar documento final</h2>
                <form method="post" action="entrega_final.jsp?id=${param.id}" enctype="multipart/form-data">
                    <input type="hidden" name="csrf_token" value="${csrfToken}">
                    <input type="hidden" name="accion" value="crear">
                    <label for="titulo">Título del trabajo de grado</label>
                    <input type="text" id="titulo" name="titulo" required maxlength="200"
                           value="${fn:escapeXml(ant.titulo)}">
                    <label for="archivo">Archivo final (PDF, DOC, DOCX, ODT, PPT o PPTX — máx. 20 MB)</label>
                    <input type="file" id="archivo" name="archivo"
                           accept=".pdf,.doc,.docx,.odt,.ppt,.pptx">
                    <label for="documento">… o URL del documento final</label>
                    <div class="campo-url">
                        <span class="icono-url" aria-hidden="true">
                            <svg xmlns="http://www.w3.org/2000/svg" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/></svg>
                        </span>
                        <input type="url" id="documento" name="documento"
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
                <c:choose>
                    <c:when test="${fn:startsWith(entrega.documento, 'http://') || fn:startsWith(entrega.documento, 'https://')}">
                        <a class="enlace-doc" href="${fn:escapeXml(entrega.documento)}" target="_blank" rel="noopener">Abrir documento</a>
                    </c:when>
                    <c:otherwise>
                        <c:url value="/descargar.jsp" var="docUrl">
                            <c:param name="f" value="${entrega.documento}"/>
                        </c:url>
                        <a class="enlace-doc" href="${docUrl}" target="_blank" rel="noopener">Abrir documento</a>
                    </c:otherwise>
                </c:choose>
            </p>
            <c:if test="${not empty entrega.observaciones}">
                <p class="dato"><b>Observaciones:</b> <c:out value="${entrega.observaciones}"/></p>
            </c:if>
        </div>

        <c:if test="${rol eq 'ESTUDIANTE' && entrega.estado eq 'OBSERVADO' && ant.estado eq 'ENTREGA_DOCUMENTO_FINAL'}">
            <div class="panel">
                <h2 style="margin-top:0">Corregir y reenviar documento</h2>
                <form method="post" action="entrega_final.jsp?id=${param.id}" enctype="multipart/form-data">
                    <input type="hidden" name="csrf_token" value="${csrfToken}"><input type="hidden" name="accion" value="corregir">
                    <label for="tituloCorreccion">Título</label><input type="text" id="tituloCorreccion" name="titulo" required maxlength="200" value="${fn:escapeXml(entrega.titulo)}">
                    <label for="archivoCorreccion">Archivo corregido</label><input type="file" id="archivoCorreccion" name="archivo" accept=".pdf,.doc,.docx,.odt,.ppt,.pptx">
                    <label for="documentoCorreccion">… o URL del documento corregido</label><input type="url" id="documentoCorreccion" name="documento" placeholder="https://drive.google.com/...">
                    <button class="btn btn-verde" type="submit">Enviar corrección</button>
                </form>
            </div>
        </c:if>

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
