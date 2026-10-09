<%-- guard.jsp - Obliga a tener sesión iniciada (si no, al login) --%>
<%@ page pageEncoding="UTF-8" %>
<c:if test="${empty sessionScope.usuario}">
    <c:redirect url="login.jsp"/>
</c:if>
