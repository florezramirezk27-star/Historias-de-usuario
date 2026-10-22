<%-- 403.jsp - Acceso denegado (RNF-02 / RNF-03: control de acceso por rol) --%>
<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<fmt:requestEncoding value="UTF-8"/>

<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Acceso denegado</title>
    <link rel="stylesheet" href="css/style.css?v=6">
</head>
<body>
<div class="login-cuerpo">
    <div class="login-caja">
        <h1>403 · Acceso denegado</h1>
        <p class="uts">No tienes permiso para entrar a esta sección.</p>
        <div class="aviso aviso-error">
            <c:choose>
                <c:when test="${not empty sessionScope.usuario}">
                    Estás ingresado como
                    <b><c:out value="${sessionScope.usuario.nombre}"/></b>
                    (rol <b><c:out value="${sessionScope.rolNombre}"/></b>),
                    y esta página pertenece a otro rol.
                </c:when>
                <c:otherwise>
                    Inicia sesión para continuar.
                </c:otherwise>
            </c:choose>
        </div>
        <c:choose>
            <c:when test="${not empty sessionScope.usuario}">
                <a class="btn" href="home.jsp">Volver a mi panel</a>
            </c:when>
            <c:otherwise>
                <a class="btn" href="login.jsp">Ir al login</a>
            </c:otherwise>
        </c:choose>
    </div>
</div>
</body>
</html>
