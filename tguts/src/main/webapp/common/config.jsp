<%-- =====================================================================
     config.jsp - Configuración compartida por todas las páginas
     (codificación UTF-8, fuente de datos XAMPP, CSRF token)
     ===================================================================== --%>
<%@ page pageEncoding="UTF-8" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>

<%-- Debe ir antes de leer cualquier parámetro del formulario --%>
<fmt:requestEncoding value="UTF-8"/>

<%-- Fuente de datos.
     En la nube (Render) se toman de variables de entorno;
     en local (XAMPP) se usan los valores por defecto. --%>
<%
    String dbHost = System.getenv("DB_HOST");
    if (dbHost == null || dbHost.isEmpty()) dbHost = "localhost";
    String dbPort = System.getenv("DB_PORT");
    if (dbPort == null || dbPort.isEmpty()) dbPort = "3306";
    String dbName = System.getenv("DB_NAME");
    if (dbName == null || dbName.isEmpty()) dbName = "db_tgd_uts";
    String dbUser = System.getenv("DB_USER");
    if (dbUser == null || dbUser.isEmpty()) dbUser = "root";
    String dbPass = System.getenv("DB_PASSWORD");
    if (dbPass == null) dbPass = "";

    pageContext.setAttribute("dsUrl",
        "jdbc:mysql://" + dbHost + ":" + dbPort + "/" + dbName
        + "?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC");
    pageContext.setAttribute("dsUser", dbUser);
    pageContext.setAttribute("dsPass", dbPass);
%>

<sql:setDataSource var="ds"
    driver="com.mysql.cj.jdbc.Driver"
    url="${dsUrl}"
    user="${dsUser}"
    password="${dsPass}"/>

<%-- CSRF token para formularios POST --%>
<%@ include file="csrf.jsp" %>

<%-- Variables de conveniencia --%>
<c:set var="yo" value="${sessionScope.usuario}"/>
<c:set var="rol" value="${yo.rol}"/>
