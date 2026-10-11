<%-- logout.jsp - Cierra la sesión de forma segura (invalida la sesión) --%>
<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="javax.servlet.http.HttpSession" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%
    HttpSession sesion = request.getSession(false);
    if (sesion != null) {
        sesion.invalidate();
    }
%>
<c:redirect url="login.jsp?salida=1"/>
