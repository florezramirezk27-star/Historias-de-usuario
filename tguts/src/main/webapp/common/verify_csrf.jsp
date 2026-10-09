<%-- =====================================================================
     verify_csrf.jsp - Validación del token CSRF en POST
     Incluir AL INICIO del bloque de procesamiento POST.
     Usa scriptlet para detener ejecución real en caso de error CSRF.
     ===================================================================== --%>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%
    // Validar CSRF en POST - debe ir antes de cualquier procesamiento
    if ("POST".equalsIgnoreCase(request.getMethod())) {
        String tokenParam = request.getParameter("csrf_token");
        String tokenAttr  = (String) request.getAttribute("f_csrf_token");
        String token = (tokenParam != null) ? tokenParam : tokenAttr;
        String sessionToken = (String) session.getAttribute("csrfToken");
        
        if (token == null || sessionToken == null || !token.equals(sessionToken)) {
            response.sendRedirect(response.encodeRedirectURL(request.getContextPath() + "/403.jsp?error=" + (token == null ? "csrf_missing" : "csrf_invalid")));
            return; // DETENER EJECUCIÓN
        }
        
        // Token válido: rotar
        String newToken = java.util.UUID.randomUUID().toString().replace("-", "").toUpperCase().substring(0, 32);
        session.setAttribute("csrfToken", newToken);
    }
%>