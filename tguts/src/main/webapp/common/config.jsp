<%-- =====================================================================
     config.jsp - Configuración compartida por todas las páginas
     (codificación UTF-8, cabeceras de seguridad, fuente de datos y CSRF).
     Primer include de todas las páginas.
     ===================================================================== --%>
<%@ page pageEncoding="UTF-8" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>

<%-- Utilidades de seguridad (PBKDF2, subida de documentos, cabeceras) --%>
<%@ include file="seguridad.jsp" %>

<%-- Codificación y cabeceras de seguridad ANTES de leer parámetros --%>
<% request.setCharacterEncoding("UTF-8"); %>
<% pgCabeceras(response); %>

<%-- Campos del formulario como Map (soporta multipart/form-data). --%>
<% request.setAttribute("campos", pgCampos(request, application)); %>

<%-- Fuente de datos: pool de conexiones (HikariCP) creado por
     edu.uts.PoolInicializador al arrancar la app. Lee las variables de
     entorno o usa los valores de XAMPP por defecto. --%>
<sql:setDataSource var="ds" dataSource="${applicationScope.ds}"/>

<%-- CSRF token para formularios POST --%>
<%@ include file="csrf.jsp" %>

<%-- Variables de conveniencia --%>
<c:set var="yo" value="${sessionScope.usuario}"/>
<c:set var="rol" value="${yo.rol}"/>
