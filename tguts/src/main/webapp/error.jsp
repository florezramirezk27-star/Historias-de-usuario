<%-- error.jsp - Error interno (muestra el detalle para debug) --%>
<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" isErrorPage="true" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<fmt:requestEncoding value="UTF-8"/>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Error</title>
    <link rel="stylesheet" href="css/style.css">
</head>
<body>
<div class="login-cuerpo">
    <div class="login-caja">
        <h1>Ocurrió un error</h1>
        <p class="uts">El sistema no pudo completar la operación.</p>
        <div class="aviso aviso-error">
            <c:choose>
                <c:when test="${not empty pageContext.exception}">
                    <c:out value="${pageContext.exception.message}"/>
                </c:when>
                <c:otherwise>Revisa los datos enviados e inténtalo de nuevo.</c:otherwise>
            </c:choose>
        </div>
        <a class="btn" href="index.jsp">Volver al inicio</a>
    </div>
</div>
</body>
</html>
