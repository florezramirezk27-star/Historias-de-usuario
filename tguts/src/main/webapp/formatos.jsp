<%-- ==========================================================
     formatos.jsp - Formatos de grado (RF-33)
     Lo consultan: Coordinación, Estudiante, Director y Evaluador
     Administración/Coordinación registran la URL del documento
     del formato (PDF, Word, ODT, PowerPoint) en lugar de subir
     el archivo. Página 100% JSTL, sin scriptlets.
     ========================================================== --%>
<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ include file="common/config.jsp" %>
<%@ include file="common/guard.jsp" %>

<%-- Solo administración/coordinación pueden enviar POST (registrar URL) --%>
<c:if test="${pageContext.request.method eq 'POST' && rol ne 'ADMIN' && rol ne 'COORDINACION'}">
    <c:redirect url="403.jsp"/>
</c:if>

<%-- ===== Proceso del formulario (crear / actualizar URL del documento) ===== --%>
<c:if test="${pageContext.request.method eq 'POST'}">
    <%@ include file="common/verify_csrf.jsp" %>
    <c:choose>
        <c:when test="${param.accion eq 'crear'}">
            <c:choose>
                <c:when test="${empty param.nombre}">
                    <c:set var="error" value="El nombre del formato es obligatorio."/>
                </c:when>
                <c:when test="${empty param.url}">
                    <c:set var="error" value="Debes indicar la URL del documento del formato."/>
                </c:when>
                <c:when test="${not (fn:startsWith(param.url, 'http://') || fn:startsWith(param.url, 'https://')
                                      || (not fn:startsWith(param.url, '/') && not fn:contains(param.url, '..') && not fn:contains(param.url, ':')))}">
                    <c:set var="error" value="Indica una URL (http/https) o una ruta relativa dentro de la aplicación (p. ej. formatos/FDC-124-Anteproyecto.pdf)."/>
                </c:when>
                <c:otherwise>
                    <sql:update dataSource="${ds}">
                        INSERT INTO formatos (nombre, descripcion, url) VALUES (?, ?, ?)
                        <sql:param value="${param.nombre}"/>
                        <sql:param value="${empty param.descripcion ? '' : param.descripcion}"/>
                        <sql:param value="${param.url}"/>
                    </sql:update>
                    <c:redirect url="formatos.jsp?exito=creado"/>
                </c:otherwise>
            </c:choose>
        </c:when>

        <%-- Actualizar la URL de un formato existente --%>
        <c:when test="${param.accion eq 'editar'}">
            <c:choose>
                <c:when test="${empty param.id || empty param.url}">
                    <c:set var="error" value="Debes indicar la nueva URL del documento."/>
                </c:when>
                <c:when test="${not (fn:startsWith(param.url, 'http://') || fn:startsWith(param.url, 'https://')
                                      || (not fn:startsWith(param.url, '/') && not fn:contains(param.url, '..') && not fn:contains(param.url, ':')))}">
                    <c:set var="error" value="Indica una URL (http/https) o una ruta relativa dentro de la aplicación (p. ej. formatos/FDC-124-Anteproyecto.pdf)."/>
                </c:when>
                <c:otherwise>
                    <sql:update dataSource="${ds}">
                        UPDATE formatos SET url = ?, nombre = IF(? = '', nombre, ?) WHERE id = ?
                        <sql:param value="${param.url}"/>
                        <sql:param value="${empty param.nombre ? '' : param.nombre}"/>
                        <sql:param value="${empty param.nombre ? '' : param.nombre}"/>
                        <sql:param value="${param.id}"/>
                    </sql:update>
                    <c:redirect url="formatos.jsp?exito=actualizado"/>
                </c:otherwise>
            </c:choose>
        </c:when>
    </c:choose>
</c:if>

<sql:query dataSource="${ds}" var="qFormatos">
    SELECT * FROM formatos ORDER BY nombre
</sql:query>

<%@ include file="common/header.jsp" %>

<h1>Formatos de grado</h1>
<p class="subtitulo">Plantillas y formatos de apoyo del proceso de grado (RF-33).</p>
<div class="aviso aviso-info">
    Los documentos aquí registrados son <b>datos de demostración</b> (plantillas base),
    no formatos institucionales oficiales. Verifica con el comité de trabajos de grado
    antes de considerarlos vigentes.
</div>

<c:if test="${param.exito eq 'creado'}">
    <div class="aviso aviso-ok">Formato agregado con su enlace.</div>
</c:if>
<c:if test="${param.exito eq 'actualizado'}">
    <div class="aviso aviso-ok">Documento del formato actualizado. El enlace ahora apunta a la nueva URL.</div>
</c:if>
<c:if test="${not empty error}">
    <div class="aviso aviso-error"><c:out value="${error}"/></div>
</c:if>

<c:if test="${rol eq 'ADMIN' || rol eq 'COORDINACION'}">
    <div class="panel">
        <h2 style="margin-top:0">Agregar formato con enlace al documento</h2>
        <form method="post" action="formatos.jsp">
            <input type="hidden" name="csrf_token" value="${csrfToken}">
            <input type="hidden" name="accion" value="crear">
            <label for="nombre">Nombre</label>
            <input type="text" id="nombre" name="nombre" required maxlength="150"
                   placeholder="Ej.: FDC-124 · Formato de anteproyecto (idea)">
            <label for="url">URL del documento</label>
            <div class="campo-url">
                <span class="icono-url" aria-hidden="true">
                    <svg xmlns="http://www.w3.org/2000/svg" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/></svg>
                </span>
                <input type="text" id="url" name="url" required
                       placeholder="https://drive.google.com/... o formatos/FDC-124-Anteproyecto.pdf">
            </div>
            <label for="descripcion">Descripción</label>
            <input type="text" id="descripcion" name="descripcion" maxlength="400">
            <button class="btn" type="submit">Agregar formato</button>
        </form>
    </div>
</c:if>

<div class="panel">
    <h2 style="margin-top:0">Formatos disponibles (<c:out value="${qFormatos.rowCount}"/>)</h2>
    <table>
        <tr>
            <th>Formato</th>
            <th>Descripción</th>
            <th>Archivo</th>
            <c:if test="${rol eq 'ADMIN' || rol eq 'COORDINACION'}">
                <th>Actualizar documento</th>
            </c:if>
        </tr>
        <c:forEach items="${qFormatos.rows}" var="f">
            <tr>
                <td><c:out value="${f.nombre}"/></td>
                <td><c:out value="${empty f.descripcion ? '—' : f.descripcion}"/></td>
                <td>
                    <c:choose>
                        <c:when test="${empty f.url || f.url eq '#'}">
                            <i>(sin documento)</i>
                        </c:when>
                        <c:when test="${fn:startsWith(f.url, 'http://') || fn:startsWith(f.url, 'https://')}">
                            <a class="enlace-doc" href="${fn:escapeXml(f.url)}" target="_blank" rel="noopener">Abrir formato</a>
                        </c:when>
                        <%-- Ruta relativa dentro de la aplicación (documentos base
                             de formatos, p. ej. formatos/FDC-124-Anteproyecto.pdf). --%>
                        <c:when test="${not fn:startsWith(f.url, '/') && not fn:contains(f.url, '..')}">
                            <c:url value="/${f.url}" var="fmtUrl"/>
                            <a class="enlace-doc" href="${fmtUrl}" target="_blank" rel="noopener">Abrir formato</a>
                        </c:when>
                        <c:otherwise>
                            <c:out value="${f.url}"/>
                        </c:otherwise>
                    </c:choose>
                </td>
                <c:if test="${rol eq 'ADMIN' || rol eq 'COORDINACION'}">
                    <td>
                        <form method="post" action="formatos.jsp"
                              style="margin:0; display:flex; gap:6px; align-items:center;">
                            <input type="hidden" name="csrf_token" value="${csrfToken}">
                            <input type="hidden" name="accion" value="editar">
                            <input type="hidden" name="id" value="${f.id}">
                            <div class="campo-url compacto">
                                <span class="icono-url" aria-hidden="true">
                                    <svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/></svg>
                                </span>
                                <input type="text" name="url" value="${fn:escapeXml(f.url)}"
                                       placeholder="https://... o formatos/FDC-124-Anteproyecto.pdf" required>
                            </div>
                            <button class="btn btn-mini btn-verde" type="submit"
                                    onclick="return confirm('¿Reemplazar el documento de este formato?')">Guardar</button>
                        </form>
                    </td>
                </c:if>
            </tr>
        </c:forEach>
    </table>
    <c:if test="${empty qFormatos.rows}">
        <p>No hay formatos registrados.</p>
    </c:if>
</div>

<%@ include file="common/footer.jsp" %>