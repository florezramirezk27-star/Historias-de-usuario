<%-- resolver.jsp - Resuelve el nombre y código de un usuario por su id.
     JSTL <sql:query> entrega las columnas con su NOMBRE REAL (getColumnName),
     por eso los alias tipo "AS estudiante_nombre" no se pueden usar en EL.
     Este include busca dentro de qUsuarios (id, nombre, codigo) el id indicado.
     Uso (justo ANTES de leer resNom/resCod):
        <c:set var="buscarId" value="${fila.usuario_id}"/>
        <%@ include file="common/resolver.jsp" %>
     Produce: resNom (nombre o vacío) y resCod (código o vacío). --%>
<%@ page pageEncoding="UTF-8" %>
<c:set var="resNom" value=""/>
<c:set var="resCod" value=""/>
<c:if test="${not empty buscarId}">
    <c:forEach items="${qUsuarios.rows}" var="u">
        <c:if test="${u.id eq buscarId}">
            <c:set var="resNom" value="${u.nombre}"/>
            <c:set var="resCod" value="${u.codigo}"/>
        </c:if>
    </c:forEach>
</c:if>