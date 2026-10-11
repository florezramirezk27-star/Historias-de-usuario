<%-- =====================================================================
     descargar.jsp - Descarga controlada de documentos subidos.
     Los archivos se guardan FUERA de la carpeta pública de la web; solo se
     sirven a usuarios autenticados con permiso sobre el registro:
       ADMIN/COORDINACION: cualquiera
       ESTUDIANTE: solo los de su propio anteproyecto
       DIRECTOR: solo los anteproyectos que dirige
       EVALUADOR: solo los que evalúa
     Uso: descargar.jsp?f=<nombreAlmacenado>
     ===================================================================== --%>
<%@ page contentType="application/octet-stream" pageEncoding="UTF-8" %>
<%@ page import="java.io.File" %>
<%@ page import="java.io.FileInputStream" %>
<%@ page import="java.io.OutputStream" %>
<%@ page import="java.sql.Connection" %>
<%@ page import="java.sql.PreparedStatement" %>
<%@ page import="java.sql.ResultSet" %>
<%@ page import="java.util.Locale" %>
<%@ page import="java.util.Map" %>
<%@ page import="javax.sql.DataSource" %>
<%@ include file="common/config.jsp" %>
<%@ include file="common/guard.jsp" %>
<%
    String nombre = request.getParameter("f");
    if (!pgNombreSeguro(nombre)) {
        response.sendError(404);
        return;
    }

    File dir = pgUploadDir(application);
    File archivo = new File(dir, nombre);
    if (!archivo.getCanonicalPath().startsWith(dir.getCanonicalPath() + File.separator)
            || !archivo.isFile()) {
        response.sendError(404);
        return;
    }

    // Localizar el dueño del documento (anteproyecto o entrega final).
    Integer estudiante = null, director = null, evaluador = null;
    DataSource ds = pgDs(application);
    if (ds != null) {
        try (Connection con = ds.getConnection()) {
            String sqlAnt = "SELECT estudiante_id, director_id, evaluador_id FROM anteproyectos WHERE documento = ?";
            try (PreparedStatement ps = con.prepareStatement(sqlAnt)) {
                ps.setString(1, nombre);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        estudiante = rs.getInt("estudiante_id");
                        director = rs.getInt("director_id");
                        evaluador = rs.getInt("evaluador_id");
                    }
                }
            }
            if (estudiante == null) {
                String sqlEnt = "SELECT a.estudiante_id, a.director_id, a.evaluador_id "
                        + "FROM entrega_final e JOIN anteproyectos a ON a.id = e.anteproyecto_id "
                        + "WHERE e.documento = ?";
                try (PreparedStatement ps = con.prepareStatement(sqlEnt)) {
                    ps.setString(1, nombre);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) {
                            estudiante = rs.getInt("estudiante_id");
                            director = rs.getInt("director_id");
                            evaluador = rs.getInt("evaluador_id");
                        }
                    }
                }
            }
        } catch (Exception e) {
            response.sendError(500);
            return;
        }
    }
    if (estudiante == null) {
        response.sendError(404);
        return;
    }

    @SuppressWarnings("unchecked")
    Map<String, Object> usuario = (Map<String, Object>) session.getAttribute("usuario");
    String rolActual = String.valueOf(usuario.get("rol"));
    int idActual = ((Number) usuario.get("id")).intValue();
    boolean autorizado = "ADMIN".equals(rolActual) || "COORDINACION".equals(rolActual)
            || ("ESTUDIANTE".equals(rolActual) && estudiante == idActual)
            || ("DIRECTOR".equals(rolActual) && director != null && director == idActual)
            || ("EVALUADOR".equals(rolActual) && evaluador != null && evaluador == idActual);
    if (!autorizado) {
        response.sendError(403);
        return;
    }

    String ext = pgExtension(nombre);
    String tipo;
    switch (ext) {
        case "pdf":  tipo = "application/pdf"; break;
        case "doc":  tipo = "application/msword"; break;
        case "docx": tipo = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"; break;
        case "odt":  tipo = "application/vnd.oasis.opendocument.text"; break;
        case "ppt":  tipo = "application/vnd.ms-powerpoint"; break;
        case "pptx": tipo = "application/vnd.openxmlformats-officedocument.presentationml.presentation"; break;
        default:     tipo = "application/octet-stream";
    }
    String disposicion = ("pdf".equals(ext) ? "inline" : "attachment")
            + "; filename=\"" + nombre.replaceAll("[^A-Za-z0-9._-]", "_").toLowerCase(Locale.ROOT) + "\"";

    response.setContentType(tipo);
    response.setContentLengthLong(archivo.length());
    response.setHeader("Content-Disposition", disposicion);
    try (FileInputStream entrada = new FileInputStream(archivo);
         OutputStream salida = response.getOutputStream()) {
        byte[] buffer = new byte[8192];
        int leidos;
        while ((leidos = entrada.read(buffer)) != -1) {
            salida.write(buffer, 0, leidos);
        }
    }
%>
