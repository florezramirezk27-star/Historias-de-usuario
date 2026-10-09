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

<%-- Fuente de datos: XAMPP (MariaDB/MySQL) - base de datos db_tgd_uts --%>
<sql:setDataSource var="ds"
    driver="com.mysql.cj.jdbc.Driver"
    url="jdbc:mysql://localhost:3306/db_tgd_uts?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC"
    user="root"
    password=""/>

<%-- CSRF token para formularios POST --%>
<%@ include file="csrf.jsp" %>

<%-- Variables de conveniencia --%>
<c:set var="yo" value="${sessionScope.usuario}"/>
<c:set var="rol" value="${yo.rol}"/>
