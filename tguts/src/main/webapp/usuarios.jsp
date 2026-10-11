<%-- ==========================================================
     usuarios.jsp - Administrador: CRUD de usuarios (RF-04 a RF-08)
     ========================================================== --%>
<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ include file="common/config.jsp" %>
<%@ include file="common/guard.jsp" %>

<%-- Solo el administrador (RNF-02 / RNF-03) --%>
<c:if test="${rol ne 'ADMIN'}">
    <c:redirect url="403.jsp"/>
</c:if>

<%-- ================= PROCESO DE ENVÍOS (POST) ================= --%>
<c:if test="${pageContext.request.method eq 'POST'}">
    <%@ include file="common/verify_csrf.jsp" %>

    <%-- ---------- CREAR ---------- --%>
    <c:if test="${param.accion eq 'crear'}">
        <c:choose>
            <c:when test="${empty param.nombre}"><c:set var="error" value="El nombre es obligatorio."/></c:when>
            <c:when test="${empty param.email}"><c:set var="error" value="El correo es obligatorio."/></c:when>
            <c:when test="${not fn:contains(param.email, '@')}"><c:set var="error" value="El correo no es válido (debe contener @)."/></c:when>
            <c:when test="${empty param.password}"><c:set var="error" value="La contraseña es obligatoria."/></c:when>
            <c:when test="${fn:length(param.password) lt 8}"><c:set var="error" value="La contraseña debe tener al menos 8 caracteres."/></c:when>
            <c:when test="${empty param.rol}"><c:set var="error" value="Selecciona el rol del usuario."/></c:when>
            <c:when test="${param.rol eq 'ESTUDIANTE' && empty param.codigo}"><c:set var="error" value="El código del estudiante es obligatorio."/></c:when>
        </c:choose>

        <c:if test="${empty error}">
            <sql:query dataSource="${ds}" var="qExis">
                SELECT id FROM usuarios WHERE email = ?
                <sql:param value="${param.email}"/>
            </sql:query>
            <c:choose>
                <c:when test="${qExis.rowCount gt 0}">
                    <c:set var="error" value="Ya existe un usuario con ese correo electrónico."/>
                </c:when>
                <c:otherwise>
                    <%-- Hash PBKDF2 generado en el servidor (no en la base de datos) --%>
                    <% request.setAttribute("hashPwd", pgHash(request.getParameter("password"))); %>
                    <sql:update dataSource="${ds}">
                        INSERT INTO usuarios (nombre, email, password, rol, codigo)
                        VALUES (?, ?, ?, ?, NULLIF(?, ''))
                        <sql:param value="${param.nombre}"/>
                        <sql:param value="${param.email}"/>
                        <sql:param value="${hashPwd}"/>
                        <sql:param value="${param.rol}"/>
                        <sql:param value="${param.codigo}"/>
                    </sql:update>
                    <c:redirect url="usuarios.jsp?exito=creado"/>
                </c:otherwise>
            </c:choose>
        </c:if>
    </c:if>

    <%-- ---------- ACTUALIZAR ---------- --%>
    <c:if test="${param.accion eq 'actualizar'}">
        <c:if test="${empty param.id}">
            <c:redirect url="usuarios.jsp"/>
        </c:if>
        <c:choose>
            <c:when test="${empty param.nombre}"><c:set var="error" value="El nombre es obligatorio."/></c:when>
            <c:when test="${empty param.email}"><c:set var="error" value="El correo es obligatorio."/></c:when>
            <c:when test="${not fn:contains(param.email, '@')}"><c:set var="error" value="El correo no es válido (debe contener @)."/></c:when>
            <c:when test="${not empty param.password && fn:length(param.password) lt 8}"><c:set var="error" value="La contraseña debe tener al menos 8 caracteres."/></c:when>
            <c:when test="${empty param.rol}"><c:set var="error" value="Selecciona el rol del usuario."/></c:when>
            <c:when test="${param.rol eq 'ESTUDIANTE' && empty param.codigo}"><c:set var="error" value="El código del estudiante es obligatorio."/></c:when>
        </c:choose>

        <c:if test="${empty error}">
            <sql:query dataSource="${ds}" var="qExis">
                SELECT id FROM usuarios WHERE email = ? AND NOT (id = ?)
                <sql:param value="${param.email}"/>
                <sql:param value="${param.id}"/>
            </sql:query>
            <c:choose>
                <c:when test="${qExis.rowCount gt 0}">
                    <c:set var="error" value="Ya existe otro usuario con ese correo electrónico."/>
                </c:when>
                <c:otherwise>
                    <c:choose>
                        <%-- Si escribió contraseña nueva, se actualiza; si no, se conserva --%>
                        <c:when test="${not empty param.password}">
                            <% request.setAttribute("hashPwd", pgHash(request.getParameter("password"))); %>
                            <sql:update dataSource="${ds}">
                                UPDATE usuarios
                                SET nombre = ?, email = ?, rol = ?, codigo = NULLIF(?, ''),
                                    password = ?
                                WHERE id = ?
                                <sql:param value="${param.nombre}"/>
                                <sql:param value="${param.email}"/>
                                <sql:param value="${param.rol}"/>
                                <sql:param value="${param.codigo}"/>
                                <sql:param value="${hashPwd}"/>
                                <sql:param value="${param.id}"/>
                            </sql:update>
                        </c:when>
                        <c:otherwise>
                            <sql:update dataSource="${ds}">
                                UPDATE usuarios
                                SET nombre = ?, email = ?, rol = ?, codigo = NULLIF(?, '')
                                WHERE id = ?
                                <sql:param value="${param.nombre}"/>
                                <sql:param value="${param.email}"/>
                                <sql:param value="${param.rol}"/>
                                <sql:param value="${param.codigo}"/>
                                <sql:param value="${param.id}"/>
                            </sql:update>
                        </c:otherwise>
                    </c:choose>
                    <c:redirect url="usuarios.jsp?exito=editado"/>
                </c:otherwise>
            </c:choose>
        </c:if>
    </c:if>

    <%-- ---------- ELIMINAR ---------- --%>
    <c:if test="${param.accion eq 'eliminar'}">
        <c:choose>
            <c:when test="${empty param.id}">
                <c:redirect url="usuarios.jsp"/>
            </c:when>
            <c:when test="${param.id eq yo.id}">
                <c:set var="error" value="No puedes eliminar la cuenta con la que estás ingresado."/>
            </c:when>
            <c:otherwise>
                <%-- Primero se verifican los datos dependientes (integridad referencial) --%>
                <sql:query dataSource="${ds}" var="qDep">
                    SELECT (SELECT COUNT(*) FROM anteproyectos WHERE estudiante_id = ? OR director_id = ? OR evaluador_id = ?)
                         + (SELECT COUNT(*) FROM ideas WHERE docente_id = ?)
                         + (SELECT COUNT(*) FROM calificaciones WHERE usuario_id = ?)
                         + (SELECT COUNT(*) FROM tramites WHERE estudiante_id = ? OR resuelto_por = ?) AS n
                    <sql:param value="${param.id}"/>
                    <sql:param value="${param.id}"/>
                    <sql:param value="${param.id}"/>
                    <sql:param value="${param.id}"/>
                    <sql:param value="${param.id}"/>
                    <sql:param value="${param.id}"/>
                    <sql:param value="${param.id}"/>
                </sql:query>
                <c:choose>
                    <c:when test="${qDep.rows[0].n gt 0}">
                        <c:set var="error" value="No se puede eliminar: el usuario tiene anteproyectos, ideas, calificaciones o trámites asociados."/>
                    </c:when>
                    <c:otherwise>
                        <sql:update dataSource="${ds}">
                            DELETE FROM notificaciones WHERE usuario_id = ?
                            <sql:param value="${param.id}"/>
                        </sql:update>
                        <sql:update dataSource="${ds}">
                            DELETE FROM usuarios WHERE id = ?
                            <sql:param value="${param.id}"/>
                        </sql:update>
                        <c:redirect url="usuarios.jsp?exito=eliminado"/>
                    </c:otherwise>
                </c:choose>
            </c:otherwise>
        </c:choose>
    </c:if>
</c:if>

<%-- ================= DATOS PARA EL FORMULARIO ================= --%>
<c:choose>
    <%-- Editar: valores del registro --%>
    <c:when test="${pageContext.request.method eq 'GET' && param.accion eq 'editar' && not empty param.id}">
        <sql:query dataSource="${ds}" var="qUsu">
            SELECT * FROM usuarios WHERE id = ?
            <sql:param value="${param.id}"/>
        </sql:query>
        <c:choose>
            <c:when test="${qUsu.rowCount eq 0}">
                <c:redirect url="usuarios.jsp"/>
            </c:when>
            <c:otherwise>
                <c:set var="modo" value="editar"/>
                <c:set var="fId" value="${qUsu.rows[0].id}"/>
                <c:set var="fNombre" value="${qUsu.rows[0].nombre}"/>
                <c:set var="fEmail" value="${qUsu.rows[0].email}"/>
                <c:set var="fRol" value="${qUsu.rows[0].rol}"/>
                <c:set var="fCodigo" value="${qUsu.rows[0].codigo}"/>
            </c:otherwise>
        </c:choose>
    </c:when>
    <%-- Falló un envío: conservar lo que escribió el usuario --%>
    <c:when test="${pageContext.request.method eq 'POST' && param.accion eq 'actualizar'}">
        <c:set var="modo" value="editar"/>
        <c:set var="fId" value="${param.id}"/>
        <c:set var="fNombre" value="${param.nombre}"/>
        <c:set var="fEmail" value="${param.email}"/>
        <c:set var="fRol" value="${param.rol}"/>
        <c:set var="fCodigo" value="${param.codigo}"/>
    </c:when>
    <%-- Nuevo usuario --%>
    <c:otherwise>
        <c:set var="modo" value="crear"/>
        <c:set var="fId" value="${param.id}"/>
        <c:set var="fNombre" value="${param.nombre}"/>
        <c:set var="fEmail" value="${param.email}"/>
        <c:set var="fRol" value="${param.rol}"/>
        <c:set var="fCodigo" value="${param.codigo}"/>
    </c:otherwise>
</c:choose>

<%-- Lista de usuarios (RF-06) --%>
<sql:query dataSource="${ds}" var="qLista">
    SELECT * FROM usuarios ORDER BY rol, nombre
</sql:query>

<%@ include file="common/header.jsp" %>

<h1>Gestión de usuarios</h1>
<p class="subtitulo">El administrador crea, consulta, edita y elimina usuarios (RF-04 a RF-08).</p>

<c:if test="${not empty error}">
    <div class="aviso aviso-error"><c:out value="${error}"/></div>
</c:if>
<c:if test="${param.exito eq 'creado'}">
    <div class="aviso aviso-ok">Usuario creado correctamente.</div>
</c:if>
<c:if test="${param.exito eq 'editado'}">
    <div class="aviso aviso-ok">Usuario actualizado correctamente.</div>
</c:if>
<c:if test="${param.exito eq 'eliminado'}">
    <div class="aviso aviso-ok">Usuario eliminado correctamente.</div>
</c:if>

<%-- ================= FORMULARIO CREAR / EDITAR ================= --%>
<div class="panel">
    <h2 style="margin-top:0">
        <c:choose>
            <c:when test="${modo eq 'editar'}">Editar usuario</c:when>
            <c:otherwise>Crear usuario</c:otherwise>
        </c:choose>
    </h2>

    <form method="post" action="usuarios.jsp">
        <input type="hidden" name="csrf_token" value="${csrfToken}">
        <input type="hidden" name="accion" value="${modo eq 'editar' ? 'actualizar' : 'crear'}">
        <c:if test="${modo eq 'editar'}">
            <input type="hidden" name="id" value="${fId}">
        </c:if>

        <div class="form-fila">
            <div>
                <label for="nombre">Nombre completo</label>
                <input type="text" id="nombre" name="nombre" required maxlength="100"
                       value="${fn:escapeXml(fNombre)}">
            </div>
            <div>
                <label for="email">Correo electrónico</label>
                <input type="email" id="email" name="email" required maxlength="120"
                       value="${fn:escapeXml(fEmail)}">
            </div>
        </div>

        <div class="form-fila">
            <div>
                <label for="password">
                    Contraseña
                    <c:if test="${modo eq 'editar'}">(dejar vacío para no cambiarla)</c:if>
                </label>
                <c:choose>
                    <c:when test="${modo eq 'crear'}">
                        <input type="password" id="password" name="password" required>
                    </c:when>
                    <c:otherwise>
                        <input type="password" id="password" name="password">
                    </c:otherwise>
                </c:choose>
            </div>
            <div>
                <label for="rol">Rol</label>
                <select id="rol" name="rol" required>
                    <option value="">-- Selecciona --</option>
                    <option value="ADMIN" ${fRol eq 'ADMIN' ? 'selected' : ''}>Administrador</option>
                    <option value="COORDINACION" ${fRol eq 'COORDINACION' ? 'selected' : ''}>Coordinación</option>
                    <option value="DIRECTOR" ${fRol eq 'DIRECTOR' ? 'selected' : ''}>Director</option>
                    <option value="EVALUADOR" ${fRol eq 'EVALUADOR' ? 'selected' : ''}>Evaluador</option>
                    <option value="ESTUDIANTE" ${fRol eq 'ESTUDIANTE' ? 'selected' : ''}>Estudiante</option>
                </select>
            </div>
            <div>
                <label for="codigo">Código de estudiante (si aplica)</label>
                <input type="text" id="codigo" name="codigo" maxlength="20"
                       value="${fn:escapeXml(fCodigo)}">
            </div>
        </div>

        <button class="btn ${modo eq 'editar' ? 'btn-verde' : ''}" type="submit">
            <c:choose>
                <c:when test="${modo eq 'editar'}">Guardar cambios</c:when>
                <c:otherwise>Crear usuario</c:otherwise>
            </c:choose>
        </button>
        <c:if test="${modo eq 'editar'}">
            <a class="btn btn-gris" href="usuarios.jsp">Cancelar</a>
        </c:if>
    </form>
</div>

<%-- ================= LISTA DE USUARIOS (RF-06) ================= --%>
<div class="panel">
    <h2 style="margin-top:0">Usuarios registrados (<c:out value="${qLista.rowCount}"/>)</h2>
    <table>
        <tr>
            <th>Nombre</th>
            <th>Correo</th>
            <th>Rol</th>
            <th>Código</th>
            <th>Acciones</th>
        </tr>
        <c:forEach items="${qLista.rows}" var="u">
            <tr>
                <td><c:out value="${u.nombre}"/></td>
                <td><c:out value="${u.email}"/></td>
                <td>
                    <c:choose>
                        <c:when test="${u.rol eq 'ADMIN'}">Administrador</c:when>
                        <c:when test="${u.rol eq 'COORDINACION'}">Coordinación</c:when>
                        <c:when test="${u.rol eq 'DIRECTOR'}">Director</c:when>
                        <c:when test="${u.rol eq 'EVALUADOR'}">Evaluador</c:when>
                        <c:otherwise>Estudiante</c:otherwise>
                    </c:choose>
                </td>
                <td><c:out value="${empty u.codigo ? '—' : u.codigo}"/></td>
                <td>
                    <a class="btn btn-mini btn-gris" href="usuarios.jsp?accion=editar&id=${u.id}">Editar</a>
                    <form method="post" action="usuarios.jsp" style="display:inline"
                          onsubmit="return confirm('¿Eliminar al usuario ${fn:escapeXml(u.nombre)}?')">
                        <input type="hidden" name="csrf_token" value="${csrfToken}">
                        <input type="hidden" name="accion" value="eliminar">
                        <input type="hidden" name="id" value="${u.id}">
                        <button class="btn btn-mini btn-rojo" type="submit">Eliminar</button>
                    </form>
                </td>
            </tr>
        </c:forEach>
    </table>
</div>

<%@ include file="common/footer.jsp" %>
