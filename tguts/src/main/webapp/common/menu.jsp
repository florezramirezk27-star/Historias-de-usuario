<%-- menu.jsp - Menú lateral según el rol del usuario (RF-03 / RNF-02) --%>
<%@ page pageEncoding="UTF-8" %>

<%-- Notificaciones sin leer (contador en el menú) --%>
<sql:query dataSource="${ds}" var="qNoLeidas">
    SELECT COUNT(*) AS n FROM notificaciones WHERE usuario_id = ? AND leido = 0
    <sql:param value="${yo.id}"/>
</sql:query>

<aside class="menu">
    <p class="menu-titulo">Módulos</p>
    <a href="home.jsp">Inicio</a>

    <c:if test="${rol eq 'ADMIN'}">
        <a href="usuarios.jsp">Gestión de usuarios</a>
    </c:if>

    <c:if test="${rol eq 'ADMIN' || rol eq 'COORDINACION' || rol eq 'DIRECTOR' || rol eq 'ESTUDIANTE'}">
        <a href="ideas.jsp">Banco de ideas</a>
    </c:if>

    <a href="anteproyectos.jsp">Anteproyectos</a>

    <c:if test="${rol eq 'ADMIN' || rol eq 'COORDINACION'}">
        <a href="coordinacion.jsp">Buscar estudiante</a>
        <a href="informes.jsp">Informes</a>
    </c:if>

    <c:if test="${rol eq 'ADMIN' || rol eq 'COORDINACION' || rol eq 'ESTUDIANTE'}">
        <a href="tramites.jsp">Trámites</a>
    </c:if>

    <a href="calendario.jsp">Calendario académico</a>
    <a href="formatos.jsp">Formatos de grado</a>
    <a href="notificaciones.jsp">
        Notificaciones
        <c:if test="${qNoLeidas.rows[0].n gt 0}">
            <span class="badge"><c:out value="${qNoLeidas.rows[0].n}"/></span>
        </c:if>
    </a>
</aside>
