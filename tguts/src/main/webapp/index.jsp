<%-- index.jsp - Punto de entrada: según la sesión va al panel o al login --%>
<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<fmt:requestEncoding value="UTF-8"/>
<c:choose>
    <c:when test="${not empty sessionScope.usuario}">
        <c:redirect url="home.jsp"/>
    </c:when>
    <c:otherwise>
        <c:redirect url="login.jsp"/>
    </c:otherwise>
</c:choose>
