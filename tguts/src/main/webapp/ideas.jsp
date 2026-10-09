<%-- ==========================================================
     ideas.jsp - Banco de ideas de proyectos
       * Docente/director publica ideas (RF-09)
       * Todos consultan las ideas disponibles (RF-10)
       * Estudiante selecciona una idea (RF-11, RF-12) y queda
         asociada a su anteproyecto con director asignado (RF-13)
       * Coordinación/administrador gestionan el CRUD (RF-25)
     ========================================================== --%>
<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ include file="common/config.jsp" %>
<%@ include file="common/guard.jsp" %>

<%-- El evaluador no participa del banco de ideas --%>
<c:if test="${rol ne 'ADMIN' && rol ne 'COORDINACION' && rol ne 'DIRECTOR' && rol ne 'ESTUDIANTE'}">
    <c:redirect url="403.jsp"/>
</c:if>

<%-- ================= PROCESO DE ENVÍOS (POST) ================= --%>
<c:if test="${pageContext.request.method eq 'POST'}">
    <%@ include file="common/verify_csrf.jsp" %>

    <%-- Validación de rol en servidor: el docente que publica la idea DEBE tener rol DIRECTOR o EVALUADOR activo --%>
    <c:set var="docOK" value="true"/>
    <c:if test="${not empty param.docente}">
        <sql:query dataSource="${ds}" var="qValDoc">
            SELECT 1 FROM usuarios WHERE id = ? AND rol IN ('DIRECTOR','EVALUADOR') AND activo = 1
            <sql:param value="${param.docente}"/>
        </sql:query>
        <c:set var="docOK" value="${qValDoc.rowCount gt 0}"/>
    </c:if>

    <%-- ---------- CREAR IDEA (RF-09 / RF-25) ---------- --%>
    <c:if test="${param.accion eq 'crear'}">
        <c:choose>
            <c:when test="${rol ne 'ADMIN' && rol ne 'COORDINACION' && rol ne 'DIRECTOR'}">
                <c:redirect url="403.jsp"/>
            </c:when>
            <c:when test="${empty param.titulo}"><c:set var="error" value="El título de la idea es obligatorio."/></c:when>
            <c:when test="${rol ne 'DIRECTOR' && empty param.docente}">
                <c:set var="error" value="Selecciona el docente que publica la idea."/>
            </c:when>
            <c:when test="${not empty param.docente && not docOK}">
                <c:set var="error" value="El usuario seleccionado no es un Docente válido (Director/Evaluador) o está inactivo."/>
            </c:when>
        </c:choose>
        <c:if test="${empty error}">
            <sql:update dataSource="${ds}">
                INSERT INTO ideas (titulo, descripcion, docente_id) VALUES (?, ?, ?)
                <sql:param value="${param.titulo}"/>
                <sql:param value="${param.descripcion}"/>
                <sql:param value="${rol eq 'DIRECTOR' ? yo.id : param.docente}"/>
            </sql:update>
            <c:redirect url="ideas.jsp?exito=creada"/>
        </c:if>
    </c:if>

    <%-- ---------- EDITAR IDEA ---------- --%>
    <c:if test="${param.accion eq 'actualizar'}">
        <c:if test="${empty param.id}">
            <c:redirect url="ideas.jsp"/>
        </c:if>
        <c:choose>
            <c:when test="${empty param.titulo}"><c:set var="error" value="El título de la idea es obligatorio."/></c:when>
        </c:choose>
        <%-- El director solo puede editar sus propias ideas --%>
        <c:if test="${empty error && rol eq 'DIRECTOR'}">
            <sql:query dataSource="${ds}" var="qOwn">
                SELECT id FROM ideas WHERE id = ? AND docente_id = ?
                <sql:param value="${param.id}"/>
                <sql:param value="${yo.id}"/>
            </sql:query>
            <c:if test="${qOwn.rowCount eq 0}">
                <c:redirect url="403.jsp"/>
            </c:if>
        </c:if>
        <c:if test="${empty error}">
            <sql:update dataSource="${ds}">
                UPDATE ideas SET titulo = ?, descripcion = ? WHERE id = ?
                <sql:param value="${param.titulo}"/>
                <sql:param value="${param.descripcion}"/>
                <sql:param value="${param.id}"/>
            </sql:update>
            <c:redirect url="ideas.jsp?exito=editada"/>
        </c:if>
    </c:if>

    <%-- ---------- CERRAR IDEA (coordinación/administrador) ---------- --%>
    <c:if test="${param.accion eq 'cerrar'}">
        <c:if test="${rol ne 'ADMIN' && rol ne 'COORDINACION'}">
            <c:redirect url="403.jsp"/>
        </c:if>
        <c:if test="${empty param.id}">
            <c:redirect url="ideas.jsp"/>
        </c:if>
        <sql:update dataSource="${ds}">
            UPDATE ideas SET estado = 'CERRADA' WHERE id = ?
            <sql:param value="${param.id}"/>
        </sql:update>
        <c:redirect url="ideas.jsp?exito=cerrada"/>
    </c:if>

    <%-- ---------- ELIMINAR IDEA (coordinación/administrador) ---------- --%>
    <c:if test="${param.accion eq 'eliminar'}">
        <c:if test="${rol ne 'ADMIN' && rol ne 'COORDINACION'}">
            <c:redirect url="403.jsp"/>
        </c:if>
        <c:if test="${empty param.id}">
            <c:redirect url="ideas.jsp"/>
        </c:if>
        <sql:update dataSource="${ds}">
            DELETE FROM ideas WHERE id = ?
            <sql:param value="${param.id}"/>
        </sql:update>
        <c:redirect url="ideas.jsp?exito=eliminada"/>
    </c:if>

    <%-- ---------- SELECCIONAR IDEA (estudiante, RF-11 / RF-12) ---------- --%>
    <c:if test="${param.accion eq 'seleccionar'}">
        <c:if test="${rol ne 'ESTUDIANTE'}">
            <c:redirect url="403.jsp"/>
        </c:if>
        <c:if test="${empty param.id}">
            <c:redirect url="ideas.jsp"/>
        </c:if>

        <sql:query dataSource="${ds}" var="qYaTiene">
            SELECT COUNT(*) AS n FROM anteproyectos WHERE estudiante_id = ?
            <sql:param value="${yo.id}"/>
        </sql:query>
        <c:choose>
            <c:when test="${qYaTiene.rows[0].n gt 0}">
                <c:redirect url="ideas.jsp?error=tiene"/>
            </c:when>
            <c:otherwise>
                <sql:query dataSource="${ds}" var="qIdeaSel">
                    SELECT * FROM ideas WHERE id = ? AND estado = 'PUBLICADA'
                    <sql:param value="${param.id}"/>
                </sql:query>
                <c:choose>
                    <c:when test="${qIdeaSel.rowCount eq 0}">
                        <c:redirect url="ideas.jsp?error=noexiste"/>
                    </c:when>
                    <c:otherwise>
                        <%-- La idea queda marcada como seleccionada --%>
                        <sql:update dataSource="${ds}">
                            UPDATE ideas SET estado = 'SELECCIONADA' WHERE id = ?
                            <sql:param value="${param.id}"/>
                        </sql:update>
                        <%-- Se crea el anteproyecto del estudiante con su director (RF-13) --%>
                        <sql:update dataSource="${ds}">
                            INSERT INTO anteproyectos (estudiante_id, idea_id, titulo, director_id, estado)
                            VALUES (?, ?, ?, ?, 'BORRADOR')
                            <sql:param value="${yo.id}"/>
                            <sql:param value="${qIdeaSel.rows[0].id}"/>
                            <sql:param value="${qIdeaSel.rows[0].titulo}"/>
                            <sql:param value="${qIdeaSel.rows[0].docente_id}"/>
                        </sql:update>
                        <%-- Notificación al docente (RF-37) --%>
                        <sql:update dataSource="${ds}">
                            INSERT INTO notificaciones (usuario_id, titulo, mensaje, evento, correo_log)
                            SELECT docente_id, 'Idea seleccionada',
                                   CONCAT('Un estudiante seleccionó la idea: ', titulo, '.'),
                                   'IDEA_SELECCIONADA',
                                   CONCAT('Correo a ', (SELECT email FROM usuarios u WHERE u.id = ideas.docente_id), ' (SMTP pendiente)')
                            FROM ideas WHERE id = ?
                            <sql:param value="${param.id}"/>
                        </sql:update>
                        <c:redirect url="anteproyectos.jsp?exito=seleccionada"/>
                    </c:otherwise>
                </c:choose>
            </c:otherwise>
        </c:choose>
    </c:if>
</c:if>

<%-- ================= DATOS PARA EL FORMULARIO ================= --%>
<c:choose>
    <c:when test="${pageContext.request.method eq 'GET' && param.accion eq 'editar' && not empty param.id}">
        <sql:query dataSource="${ds}" var="qIdea">
            SELECT * FROM ideas WHERE id = ?
            <sql:param value="${param.id}"/>
        </sql:query>
        <c:choose>
            <c:when test="${qIdea.rowCount eq 0}">
                <c:redirect url="ideas.jsp"/>
            </c:when>
            <c:otherwise>
                <c:set var="modo" value="editar"/>
                <c:set var="fId" value="${qIdea.rows[0].id}"/>
                <c:set var="fTitulo" value="${qIdea.rows[0].titulo}"/>
                <c:set var="fDescripcion" value="${qIdea.rows[0].descripcion}"/>
                <c:set var="fDocente" value="${qIdea.rows[0].docente_id}"/>
            </c:otherwise>
        </c:choose>
    </c:when>
    <c:when test="${pageContext.request.method eq 'POST' && param.accion eq 'actualizar'}">
        <c:set var="modo" value="editar"/>
        <c:set var="fId" value="${param.id}"/>
        <c:set var="fTitulo" value="${param.titulo}"/>
        <c:set var="fDescripcion" value="${param.descripcion}"/>
        <c:set var="fDocente" value="${param.docente}"/>
    </c:when>
    <c:otherwise>
        <c:set var="modo" value="crear"/>
        <c:set var="fTitulo" value="${param.titulo}"/>
        <c:set var="fDescripcion" value="${param.descripcion}"/>
    </c:otherwise>
</c:choose>

<%-- Listado según el rol --%>
<c:choose>
    <c:when test="${rol eq 'ESTUDIANTE'}">
        <sql:query dataSource="${ds}" var="qIdeas">
            SELECT i.*, u.nombre
            FROM ideas i JOIN usuarios u ON u.id = i.docente_id
            WHERE i.estado = 'PUBLICADA'
            ORDER BY i.id DESC
        </sql:query>
        <sql:query dataSource="${ds}" var="qMiAnt">
            SELECT id, estado FROM anteproyectos WHERE estudiante_id = ?
            <sql:param value="${yo.id}"/>
        </sql:query>
    </c:when>
    <c:otherwise>
        <sql:query dataSource="${ds}" var="qIdeas">
            SELECT i.*, u.nombre
            FROM ideas i JOIN usuarios u ON u.id = i.docente_id
            ORDER BY i.id DESC
        </sql:query>
        <sql:query dataSource="${ds}" var="qDocentes">
            SELECT id, nombre FROM usuarios
            WHERE rol IN ('DIRECTOR', 'COORDINACION') AND activo = 1
            ORDER BY nombre
        </sql:query>
    </c:otherwise>
</c:choose>

<%@ include file="common/header.jsp" %>

<h1>Banco de ideas</h1>
<p class="subtitulo">Los docentes publican ideas y los estudiantes seleccionan la suya (RF-09 a RF-13).</p>

<c:if test="${not empty error}">
    <div class="aviso aviso-error"><c:out value="${error}"/></div>
</c:if>
<c:if test="${param.exito eq 'creada'}">
    <div class="aviso aviso-ok">Idea publicada correctamente.</div>
</c:if>
<c:if test="${param.exito eq 'editada'}">
    <div class="aviso aviso-ok">Idea actualizada correctamente.</div>
</c:if>
<c:if test="${param.exito eq 'cerrada'}">
    <div class="aviso aviso-ok">Idea cerrada. Ya no está disponible para selección.</div>
</c:if>
<c:if test="${param.exito eq 'eliminada'}">
    <div class="aviso aviso-ok">Idea eliminada.</div>
</c:if>
<c:if test="${param.error eq 'tiene'}">
    <div class="aviso aviso-error">Ya tienes un anteproyecto registrado. No puedes seleccionar otra idea.</div>
</c:if>
<c:if test="${param.error eq 'noexiste'}">
    <div class="aviso aviso-error">La idea ya no está disponible.</div>
</c:if>

<%-- ---------- Aviso del estudiante con anteproyecto ---------- --%>
<c:if test="${rol eq 'ESTUDIANTE' && not empty qMiAnt.rows}">
    <div class="aviso aviso-info">
        Ya seleccionaste una idea y tu anteproyecto está en estado
        <b><c:set var="est" value="${qMiAnt.rows[0].estado}"/><%@ include file="common/estado.jsp" %></b>.
        <a href="anteproyectos.jsp">Ir a mi anteproyecto</a>
    </div>
</c:if>

<%-- ================= FORMULARIO CREAR / EDITAR (no estudiantes) ================= --%>
<c:if test="${rol ne 'ESTUDIANTE'}">
    <div class="panel">
        <h2 style="margin-top:0">
            <c:choose>
                <c:when test="${modo eq 'editar'}">Editar idea</c:when>
                <c:otherwise>Publicar nueva idea</c:otherwise>
            </c:choose>
        </h2>

        <form method="post" action="ideas.jsp">
            <input type="hidden" name="csrf_token" value="${csrfToken}">
            <input type="hidden" name="accion" value="${modo eq 'editar' ? 'actualizar' : 'crear'}">
            <c:if test="${modo eq 'editar'}">
                <input type="hidden" name="id" value="${fId}">
            </c:if>

            <label for="titulo">Título de la idea</label>
            <input type="text" id="titulo" name="titulo" required maxlength="200"
                   placeholder="Ej.: Sistema de gestión de inventarios"
                   value="${fn:escapeXml(fTitulo)}">

            <label for="descripcion">Descripción</label>
            <textarea id="descripcion" name="descripcion" maxlength="2000"
                      placeholder="Describe brevemente el proyecto"><c:out value="${fDescripcion}"/></textarea>

            <c:if test="${rol eq 'ADMIN' || rol eq 'COORDINACION'}">
                <label for="docente">Docente que publica</label>
                <select id="docente" name="docente" required>
                    <option value="">-- Selecciona --</option>
                    <c:forEach items="${qDocentes.rows}" var="d">
                        <option value="${d.id}" ${fDocente eq d.id ? 'selected' : ''}>
                            <c:out value="${d.nombre}"/>
                        </option>
                    </c:forEach>
                </select>
            </c:if>

            <div>
                <button class="btn ${modo eq 'editar' ? 'btn-verde' : ''}" type="submit">
                    <c:choose>
                        <c:when test="${modo eq 'editar'}">Guardar cambios</c:when>
                        <c:otherwise>Publicar idea</c:otherwise>
                    </c:choose>
                </button>
                <c:if test="${modo eq 'editar'}">
                    <a class="btn btn-gris" href="ideas.jsp">Cancelar</a>
                </c:if>
            </div>
        </form>
    </div>
</c:if>

<%-- ================= LISTADO DE IDEAS ================= --%>
<div class="panel">
    <h2 style="margin-top:0">Ideas disponibles (<c:out value="${qIdeas.rowCount}"/>)</h2>
    <table>
        <tr>
            <th>Título</th>
            <th>Descripción</th>
            <th>Docente</th>
            <th>Estado</th>
            <th>Acciones</th>
        </tr>
        <c:forEach items="${qIdeas.rows}" var="i">
            <tr>
                <td><c:out value="${i.titulo}"/></td>
                <td><c:out value="${i.descripcion}"/></td>
                <td><c:out value="${i.nombre}"/></td>
                <td>
                    <c:set var="est" value="${i.estado}"/>
                    <span class="estado estado-${est}"><%@ include file="common/estado.jsp" %></span>
                </td>
                <td>
                    <c:choose>
                        <%-- Estudiante: seleccionar la idea (RF-11) --%>
                        <c:when test="${rol eq 'ESTUDIANTE'}">
                            <c:if test="${empty qMiAnt.rows}">
                                <form method="post" action="ideas.jsp" style="display:inline"
                                      onsubmit="return confirm('¿Seleccionar esta idea para tu anteproyecto?')">
                                    <input type="hidden" name="csrf_token" value="${csrfToken}">
                                    <input type="hidden" name="accion" value="seleccionar">
                                    <input type="hidden" name="id" value="${i.id}">
                                    <button class="btn btn-mini btn-verde" type="submit">Seleccionar</button>
                                </form>
                            </c:if>
                        </c:when>
                        <c:otherwise>
                            <c:set var="puedeEditar" value="${rol eq 'ADMIN' || rol eq 'COORDINACION' || (rol eq 'DIRECTOR' && i.docente_id eq yo.id)}"/>
                            <c:if test="${puedeEditar && i.estado ne 'SELECCIONADA'}">
                                <a class="btn btn-mini btn-gris" href="ideas.jsp?accion=editar&id=${i.id}">Editar</a>
                            </c:if>
                            <c:if test="${(rol eq 'ADMIN' || rol eq 'COORDINACION') && i.estado eq 'PUBLICADA'}">
                                <form method="post" action="ideas.jsp" style="display:inline"
                                      onsubmit="return confirm('¿Cerrar esta idea?')">
                                    <input type="hidden" name="csrf_token" value="${csrfToken}">
                                    <input type="hidden" name="accion" value="cerrar">
                                    <input type="hidden" name="id" value="${i.id}">
                                    <button class="btn btn-mini btn-gris" type="submit">Cerrar</button>
                                </form>
                            </c:if>
                            <c:if test="${rol eq 'ADMIN' || rol eq 'COORDINACION'}">
                                <form method="post" action="ideas.jsp" style="display:inline"
                                      onsubmit="return confirm('¿Eliminar la idea ${fn:escapeXml(i.titulo)}?')">
                                    <input type="hidden" name="csrf_token" value="${csrfToken}">
                                    <input type="hidden" name="accion" value="eliminar">
                                    <input type="hidden" name="id" value="${i.id}">
                                    <button class="btn btn-mini btn-rojo" type="submit">Eliminar</button>
                                </form>
                            </c:if>
                        </c:otherwise>
                    </c:choose>
                </td>
            </tr>
        </c:forEach>
    </table>
</div>

<%@ include file="common/footer.jsp" %>
