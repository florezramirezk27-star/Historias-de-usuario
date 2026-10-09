<%-- ==========================================================
     login.jsp - Autenticación (RF-01, RF-02, RF-03)
     ========================================================== --%>
<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ include file="common/config.jsp" %>

<%-- Si ya tiene sesión, que vaya al panel --%>
<c:if test="${not empty sessionScope.usuario}">
    <c:redirect url="home.jsp"/>
</c:if>

<%-- Proceso de inicio de sesión --%>
<c:if test="${pageContext.request.method eq 'POST'}">
    <sql:query dataSource="${ds}" var="qLogin">
        SELECT * FROM usuarios
        WHERE email = ? AND password = SHA2(CONCAT(?, '|tguts-salt'), 256) AND activo = 1
        <sql:param value="${param.email}"/>
        <sql:param value="${param.password}"/>
    </sql:query>

    <c:choose>
        <c:when test="${qLogin.rowCount eq 1}">
            <c:set var="u" value="${qLogin.rows[0]}"/>
            <c:set var="usuario" value="${u}" scope="session"/>

            <%-- Nombre visible del rol (para la barra superior) --%>
            <c:choose>
                <c:when test="${u.rol eq 'ADMIN'}"><c:set var="rolNombre" value="Administrador" scope="session"/></c:when>
                <c:when test="${u.rol eq 'COORDINACION'}"><c:set var="rolNombre" value="Coordinación" scope="session"/></c:when>
                <c:when test="${u.rol eq 'DIRECTOR'}"><c:set var="rolNombre" value="Director" scope="session"/></c:when>
                <c:when test="${u.rol eq 'EVALUADOR'}"><c:set var="rolNombre" value="Evaluador" scope="session"/></c:when>
                <c:otherwise><c:set var="rolNombre" value="Estudiante" scope="session"/></c:otherwise>
            </c:choose>

            <c:redirect url="home.jsp"/>
        </c:when>
        <c:otherwise>
            <c:set var="errorLogin" value="Credenciales inválidas. Verifica el correo y la contraseña."/>
        </c:otherwise>
    </c:choose>
</c:if>

<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Iniciar sesión · Trabajos de Grado UTS</title>
    <link rel="stylesheet" href="css/style.css?v=5">
</head>
<body>
<div class="login-cuerpo">
    <div class="login-caja">
        <img class="login-logo" src="img/images.png" alt="Logo UTS">
        <h1>Trabajos de Grado</h1>
        <p class="uts">Universidad UTS · Sistema de información</p>

        <c:if test="${not empty errorLogin}">
            <div class="aviso aviso-error"><c:out value="${errorLogin}"/></div>
        </c:if>
        <c:if test="${param.salida eq '1'}">
            <div class="aviso aviso-info">Sesión cerrada correctamente.</div>
        </c:if>

        <form method="post" action="login.jsp" autocomplete="off">
            <label for="email">Correo electrónico</label>
            <input type="email" id="email" name="email" required autofocus autocomplete="off"
                   value="${fn:escapeXml(param.email)}">

            <label for="password">Contraseña</label>
            <input type="password" id="password" name="password" required autocomplete="new-password">

            <button class="btn" type="submit">Iniciar sesión</button>
        </form>

        <div class="credenciales">
            <b>Cuentas de prueba</b><br>
            Admin: admin@uts.edu.co / admin123<br>
            Coordinación: coord@uts.edu.co / coord123<br>
            Director: director@uts.edu.co / director123<br>
            Evaluador: evaluador@uts.edu.co / evaluador123<br>
            Estudiante: estudiante@uts.edu.co / estudiante123
        </div>
    </div>
</div>
</body>
</html>
