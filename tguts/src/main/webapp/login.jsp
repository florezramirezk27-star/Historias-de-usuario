<%-- ==========================================================
     login.jsp - Autenticación (RF-01, RF-02, RF-03)
     - Contraseñas verificadas con PBKDF2-HMAC-SHA256 (common/seguridad.jsp).
     - Migración automática de hashes SHA-256 heredados.
     - Rotación del identificador de sesión al iniciar sesión.
     - Protección CSRF en el propio formulario de login.
     ========================================================== --%>
<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.sql.Connection" %>
<%@ page import="java.sql.PreparedStatement" %>
<%@ page import="java.sql.ResultSet" %>
<%@ page import="java.util.HashMap" %>
<%@ page import="java.util.Map" %>
<%@ page import="javax.servlet.http.HttpSession" %>
<%@ page import="javax.sql.DataSource" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ include file="common/config.jsp" %>
<%@ include file="common/verify_csrf.jsp" %>

<%-- Si ya tiene sesión, que vaya al panel --%>
<c:if test="${not empty sessionScope.usuario}">
    <c:redirect url="home.jsp"/>
</c:if>

<%-- ===== Proceso de inicio de sesión ===== --%>
<%
    if ("POST".equalsIgnoreCase(request.getMethod())) {
        String errorLogin = null;
        Integer intentos = (Integer) session.getAttribute("intentosLogin");
        int fallos = (intentos == null) ? 0 : intentos;

        if (fallos >= 10) {
            errorLogin = "Demasiados intentos fallidos. Espera unos minutos e inténtalo de nuevo.";
        } else {
            String email = request.getParameter("email");
            String password = request.getParameter("password");
            if (email == null || email.trim().isEmpty() || password == null || password.isEmpty()) {
                errorLogin = "Ingresa tu correo y contraseña.";
            } else {
                DataSource ds = (DataSource) application.getAttribute("ds");
                boolean ok = false;
                boolean migrar = false;
                Integer id = null;
                String nombre = null, rol = null, codigo = null, correo = null;
                try (Connection con = ds.getConnection();
                     PreparedStatement ps = con.prepareStatement(
                             "SELECT id, nombre, email, password, rol, codigo FROM usuarios "
                             + "WHERE email = ? AND activo = 1")) {
                    ps.setString(1, email.trim());
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) {
                            String stored = rs.getString("password");
                            if (pgVerify(password, stored)) {
                                ok = true;
                                migrar = pgNecesitaMigrar(stored);
                                id = rs.getInt("id");
                                nombre = rs.getString("nombre");
                                rol = rs.getString("rol");
                                codigo = rs.getString("codigo");
                                correo = rs.getString("email");
                            }
                        }
                    }
                    // Migración transparente del hash heredado a PBKDF2.
                    if (ok && migrar) {
                        try (PreparedStatement up = con.prepareStatement(
                                "UPDATE usuarios SET password = ? WHERE id = ?")) {
                            up.setString(1, pgHash(password));
                            up.setInt(2, id);
                            up.executeUpdate();
                        }
                    }
                } catch (Exception ex) {
                    errorLogin = "No se pudo conectar con la base de datos.";
                }

                if (ok) {
                    String nombreRol = "Estudiante";
                    if ("ADMIN".equals(rol)) nombreRol = "Administrador";
                    else if ("COORDINACION".equals(rol)) nombreRol = "Coordinación";
                    else if ("DIRECTOR".equals(rol)) nombreRol = "Director";
                    else if ("EVALUADOR".equals(rol)) nombreRol = "Evaluador";

                    // Rotación de sesión: se descarta la sesión anónima y se crea
                    // una nueva para evitar fijación de sesión.
                    HttpSession vieja = request.getSession(false);
                    if (vieja != null) {
                        vieja.invalidate();
                    }
                    HttpSession nueva = request.getSession(true);
                    Map<String, Object> u = new HashMap<String, Object>();
                    u.put("id", id);
                    u.put("nombre", nombre);
                    u.put("email", correo);
                    u.put("rol", rol);
                    u.put("codigo", codigo);
                    nueva.setAttribute("usuario", u);
                    nueva.setAttribute("rolNombre", nombreRol);
                    // Token CSRF nuevo para la sesión autenticada.
                    nueva.setAttribute("csrfToken", null);

                    response.sendRedirect(response.encodeRedirectURL(request.getContextPath() + "/home.jsp"));
                    return;
                } else if (errorLogin == null) {
                    session.setAttribute("intentosLogin", fallos + 1);
                    errorLogin = "Credenciales inválidas. Verifica el correo y la contraseña.";
                }
            }
        }
        request.setAttribute("errorLogin", errorLogin);
    }
%>

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
        <p class="uts">Universitaria Tecnológica de Santander (UTS) · Sistema de información</p>

        <c:if test="${not empty errorLogin}">
            <div class="aviso aviso-error"><c:out value="${errorLogin}"/></div>
        </c:if>
        <c:if test="${param.salida eq '1'}">
            <div class="aviso aviso-info">Sesión cerrada correctamente.</div>
        </c:if>

        <form method="post" action="login.jsp" autocomplete="off">
            <input type="hidden" name="csrf_token" value="${csrfToken}">
            <label for="email">Correo electrónico</label>
            <input type="email" id="email" name="email" required autofocus autocomplete="off"
                   value="${fn:escapeXml(param.email)}">

            <label for="password">Contraseña</label>
            <input type="password" id="password" name="password" required autocomplete="new-password">

            <button class="btn" type="submit">Iniciar sesión</button>
        </form>

        <div class="credenciales">
            <b>Cuentas de demostración (no son usuarios reales)</b><br>
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
