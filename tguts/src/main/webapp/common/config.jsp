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

<%-- Fuente de datos: pool de conexiones (HikariCP) creado por
     edu.uts.PoolInicializador al arrancar la app. Lee las variables de
     entorno o usa los valores de XAMPP por defecto. --%>
<sql:setDataSource var="ds" dataSource="${applicationScope.ds}"/>

<%-- CSRF token para formularios POST --%>
<%@ include file="csrf.jsp" %>

<%-- Variables de conveniencia --%>
<c:set var="yo" value="${sessionScope.usuario}"/>
<c:set var="rol" value="${yo.rol}"/>
