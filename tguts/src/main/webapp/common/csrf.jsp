<%-- =====================================================================
     csrf.jsp - Generación del token CSRF de la sesión.
     Uso:
       1. Se incluye desde common/config.jsp en todas las páginas.
       2. En el form: <input type="hidden" name="csrf_token" value="${csrfToken}">
       3. La validación la hace common/verify_csrf.jsp, que se incluye al
          inicio del bloque de procesamiento de cada petición POST.
     El token es estable durante la sesión (no se rota en cada POST) para no
     romper el uso de varias pestañas; se renueva al autenticarse.
     ===================================================================== --%>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%
    if (session.getAttribute("csrfToken") == null) {
        byte[] bytes = new byte[32];
        new java.security.SecureRandom().nextBytes(bytes);
        StringBuilder token = new StringBuilder(bytes.length * 2);
        for (byte b : bytes) {
            token.append(Character.forDigit((b >> 4) & 0xF, 16));
            token.append(Character.forDigit(b & 0xF, 16));
        }
        session.setAttribute("csrfToken", token.toString());
    }
%>
<c:set var="csrfToken" value="${sessionScope.csrfToken}"/>
