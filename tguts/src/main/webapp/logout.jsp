<%-- logout.jsp - Cierra la sesión --%>
<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<fmt:requestEncoding value="UTF-8"/>
<c:remove var="usuario" scope="session"/>
<c:remove var="rolNombre" scope="session"/>
<c:redirect url="login.jsp?salida=1"/>
