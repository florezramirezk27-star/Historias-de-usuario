<%-- =====================================================================
     verify_csrf.jsp - Validación del token CSRF en peticiones POST.
     Se incluye al inicio del bloque de procesamiento POST de cada página.
     El token se lee del Map "campos" que prepara config.jsp (funciona igual
     con formularios normales y multipart) o de la cabecera X-CSRF-Token.
     El token es estable durante la sesión (uso con varias pestañas) y se
     compara en tiempo constante.
     ===================================================================== --%>
<%@ page import="java.security.MessageDigest" %>
<%@ page import="java.util.Map" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%
    if ("POST".equalsIgnoreCase(request.getMethod())) {
        String token = null;
        Object campos = request.getAttribute("campos");
        if (campos instanceof Map) {
            Object t = ((Map<?, ?>) campos).get("csrf_token");
            if (t != null) token = t.toString();
        }
        if (token == null) {
            token = request.getHeader("X-CSRF-Token");
        }
        Object sesionToken = session.getAttribute("csrfToken");
        boolean ok = token != null && sesionToken != null
                && MessageDigest.isEqual(
                        token.getBytes("UTF-8"),
                        sesionToken.toString().getBytes("UTF-8"));
        if (!ok) {
            response.sendRedirect(response.encodeRedirectURL(
                    request.getContextPath() + "/403.jsp?error=csrf"));
            return;
        }
    }
%>
