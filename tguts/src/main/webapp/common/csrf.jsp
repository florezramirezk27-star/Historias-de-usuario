<%-- =====================================================================
     csrf.jsp - Protección CSRF para formularios POST importantes
     Uso:
       1. Incluir en páginas que renderizan formularios: <%@ include file="common/csrf.jsp" %>
       2. En el form: <input type="hidden" name="csrf_token" value="${csrfToken}">
       3. En el POST handler: <%@ include file="common/verify_csrf.jsp" %>
     ===================================================================== --%>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%
    if (session.getAttribute("csrfToken") == null) {
        String token = java.util.UUID.randomUUID().toString().replace("-", "").toUpperCase().substring(0, 32);
        session.setAttribute("csrfToken", token);
    }
%>
<c:set var="csrfToken" value="${sessionScope.csrfToken}"/>