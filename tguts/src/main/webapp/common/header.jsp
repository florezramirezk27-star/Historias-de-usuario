<%-- header.jsp - Cabecera de todas las páginas protegidas --%>
<%@ page pageEncoding="UTF-8" %>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Sistema de Trabajos de Grado UTS</title>
    <link rel="stylesheet" href="css/style.css?v=5">
</head>
<body>
<header class="topbar">
    <div class="marca">
        <img class="logo-topbar" src="img/images.png" alt="Logo UTS">
        <span>UTS · Sistema de Trabajos de Grado</span>
    </div>
    <div class="sesion">
        <span class="chip"><c:out value="${yo.nombre}"/></span>
        <span class="chip chip-rol"><c:out value="${sessionScope.rolNombre}"/></span>
        <a class="btn btn-rojo btn-mini" href="logout.jsp" onclick="return confirm('¿Seguro que quieres cerrar sesión?')">Cerrar sesión</a>
    </div>
</header>
<div class="layout">
    <%@ include file="/common/menu.jsp" %>
    <main class="contenido">
