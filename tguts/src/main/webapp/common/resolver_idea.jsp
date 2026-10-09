<%-- resolver_idea.jsp - Resuelve el título de una idea por su id.
     Uso (justo ANTES de leer resIdea):
        <c:set var="buscarIdeaId" value="${fila.idea_id}"/>
        <%@ include file="common/resolver_idea.jsp" %>
     Requiere que qIdeas tenga columnas id y titulo.
     Produce: resIdea (título o vacío). --%>
<%@ page pageEncoding="UTF-8" %>
<c:set var="resIdea" value=""/>
<c:if test="${not empty buscarIdeaId}">
    <c:forEach items="${qIdeas.rows}" var="idR">
        <c:if test="${idR.id eq buscarIdeaId}">
            <c:set var="resIdea" value="${idR.titulo}"/>
        </c:if>
    </c:forEach>
</c:if>