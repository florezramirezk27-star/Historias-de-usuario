<%-- =====================================================================
     seguridad.jsp - Utilidades de seguridad implementadas en JSP (sin clases
     .java nuevas). Se incluye SIEMPRE desde common/config.jsp, que es el
     primer include de todas las páginas.

     Contiene:
       * Hash y verificación de contraseñas con PBKDF2-HMAC-SHA256 (JDK),
         con migración del formato heredado SHA-256.
       * Procesamiento de formularios multipart (subida de documentos) con
         validación de extensión, contenido real (firma), tamaño y nombre.
       * Cabeceras de seguridad HTTP.
     ===================================================================== --%>
<%@ page import="java.io.File" %>
<%@ page import="java.io.InputStream" %>
<%@ page import="java.nio.charset.StandardCharsets" %>
<%@ page import="java.security.MessageDigest" %>
<%@ page import="java.security.SecureRandom" %>
<%@ page import="java.util.ArrayList" %>
<%@ page import="java.util.Arrays" %>
<%@ page import="java.util.Base64" %>
<%@ page import="java.util.HashMap" %>
<%@ page import="java.util.HashSet" %>
<%@ page import="java.util.List" %>
<%@ page import="java.util.Locale" %>
<%@ page import="java.util.Map" %>
<%@ page import="java.util.Set" %>
<%@ page import="java.util.UUID" %>
<%@ page import="javax.crypto.SecretKeyFactory" %>
<%@ page import="javax.crypto.spec.PBEKeySpec" %>
<%@ page import="javax.servlet.ServletContext" %>
<%@ page import="javax.servlet.http.HttpServletRequest" %>
<%@ page import="javax.servlet.http.HttpServletResponse" %>
<%@ page import="javax.sql.DataSource" %>
<%@ page import="org.apache.commons.fileupload.FileItem" %>
<%@ page import="org.apache.commons.fileupload.FileUploadBase" %>
<%@ page import="org.apache.commons.fileupload.disk.DiskFileItemFactory" %>
<%@ page import="org.apache.commons.fileupload.servlet.ServletFileUpload" %>

<%!
    // ------------------------------------------------------------------
    // Contraseñas (PBKDF2-HMAC-SHA256)
    // ------------------------------------------------------------------
    static final String PG_PREFIX = "pbkdf2_sha256";
    static final String PG_LEGACY_SALT = "|tguts-salt";
    static final int PG_MIN_PASSWORD = 8;
    static final int PG_SALT_BYTES = 16;
    static final int PG_KEY_BITS = 256;

    static int pgIteraciones() {
        String v = System.getenv("PBKDF2_ITERATIONS");
        if (v != null && !v.isEmpty()) {
            try {
                int n = Integer.parseInt(v.trim());
                if (n >= 50000) return n;
            } catch (NumberFormatException ignored) { }
        }
        return 120000;
    }

    static String pgHash(String password) {
        try {
            byte[] salt = new byte[PG_SALT_BYTES];
            new SecureRandom().nextBytes(salt);
            int iter = pgIteraciones();
            byte[] derived = pgPbkdf2(password, salt, iter, PG_KEY_BITS);
            return PG_PREFIX + "$" + iter + "$"
                    + Base64.getEncoder().encodeToString(salt) + "$"
                    + Base64.getEncoder().encodeToString(derived);
        } catch (Exception e) {
            throw new IllegalStateException("No se pudo calcular el hash", e);
        }
    }

    static boolean pgVerify(String password, String stored) {
        if (password == null || stored == null || stored.isEmpty()) return false;
        try {
            if (stored.startsWith(PG_PREFIX + "$")) {
                String[] p = stored.split("\\$");
                if (p.length != 4) return false;
                int iter = Integer.parseInt(p[1]);
                byte[] salt = Base64.getDecoder().decode(p[2]);
                byte[] expected = Base64.getDecoder().decode(p[3]);
                byte[] actual = pgPbkdf2(password, salt, iter, expected.length * 8);
                return MessageDigest.isEqual(expected, actual);
            }
            byte[] expected = stored.getBytes(StandardCharsets.US_ASCII);
            byte[] actual = pgLegacy(password).getBytes(StandardCharsets.US_ASCII);
            return MessageDigest.isEqual(expected, actual);
        } catch (Exception e) {
            return false;
        }
    }

    static boolean pgNecesitaMigrar(String stored) {
        return stored != null && !stored.isEmpty() && !stored.startsWith(PG_PREFIX + "$");
    }

    static boolean pgPasswordFuerte(String password) {
        return password != null && password.length() >= PG_MIN_PASSWORD;
    }

    static byte[] pgPbkdf2(String password, byte[] salt, int iterations, int keyBits) throws Exception {
        PBEKeySpec spec = new PBEKeySpec(password.toCharArray(), salt, iterations, keyBits);
        return SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).getEncoded();
    }

    static String pgLegacy(String password) throws Exception {
        MessageDigest md = MessageDigest.getInstance("SHA-256");
        byte[] d = md.digest((password + PG_LEGACY_SALT).getBytes(StandardCharsets.UTF_8));
        StringBuilder sb = new StringBuilder(d.length * 2);
        for (byte b : d) {
            sb.append(Character.forDigit((b >> 4) & 0xF, 16));
            sb.append(Character.forDigit(b & 0xF, 16));
        }
        return sb.toString();
    }

    // ------------------------------------------------------------------
    // Documentos subidos
    // ------------------------------------------------------------------
    static final long PG_MAX_BYTES = 20L * 1024 * 1024;
    static final Set<String> PG_EXTENSIONES = new HashSet<String>(
            Arrays.asList("pdf", "doc", "docx", "odt", "ppt", "pptx"));

    static File pgUploadDir(ServletContext app) {
        Object attr = app.getAttribute("uploadDir");
        if (attr instanceof File) return (File) attr;
        if (attr instanceof String) return new File((String) attr);
        File base = new File(System.getProperty("catalina.base", System.getProperty("java.io.tmpdir")), "tguts-uploads");
        if (!base.exists()) base.mkdirs();
        app.setAttribute("uploadDir", base);
        return base;
    }

    static boolean pgNombreSeguro(String nombre) {
        return nombre != null && nombre.matches("[A-Za-z0-9._-]{1,120}");
    }

    static String pgExtension(String nombre) {
        if (nombre == null) return "";
        int dot = nombre.lastIndexOf('.');
        if (dot < 0 || dot == nombre.length() - 1) return "";
        return nombre.substring(dot + 1).toLowerCase(Locale.ROOT);
    }

    static String pgTipoReal(FileItem item) {
        try (InputStream in = item.getInputStream()) {
            byte[] h = new byte[8];
            int read = in.read(h);
            if (read < 4) return null;
            if (h[0] == 0x25 && h[1] == 0x50 && h[2] == 0x44 && h[3] == 0x46) return "pdf";
            if (h[0] == 0x50 && h[1] == 0x4B && h[2] == 0x03 && h[3] == 0x04) return "zip";
            if (read >= 8
                    && (h[0] & 0xFF) == 0xD0 && (h[1] & 0xFF) == 0xCF
                    && (h[2] & 0xFF) == 0x11 && (h[3] & 0xFF) == 0xE0
                    && (h[4] & 0xFF) == 0xA1 && (h[5] & 0xFF) == 0xB1
                    && (h[6] & 0xFF) == 0x1A && (h[7] & 0xFF) == 0xE1) return "ole";
        } catch (Exception e) {
            return null;
        }
        return null;
    }

    static boolean pgTipoCompatible(String ext, String tipo) {
        if ("pdf".equals(ext)) return "pdf".equals(tipo);
        if ("docx".equals(ext) || "odt".equals(ext) || "pptx".equals(ext)) return "zip".equals(tipo);
        if ("doc".equals(ext) || "ppt".equals(ext)) return "ole".equals(tipo);
        return false;
    }

    static String pgGuardar(FileItem item, File destino) {
        String original = item.getName();
        if (original == null || original.trim().isEmpty()) {
            throw new IllegalArgumentException("No se recibió ningún archivo.");
        }
        original = original.replace('\\', '/');
        int slash = original.lastIndexOf('/');
        if (slash >= 0) original = original.substring(slash + 1);

        String ext = pgExtension(original);
        if (!PG_EXTENSIONES.contains(ext)) {
            throw new IllegalArgumentException("Tipo de archivo no permitido. Se aceptan PDF, DOC, DOCX, ODT, PPT y PPTX.");
        }
        if (item.getSize() <= 0) {
            throw new IllegalArgumentException("El archivo está vacío.");
        }
        if (item.getSize() > PG_MAX_BYTES) {
            throw new IllegalArgumentException("El archivo supera el tamaño máximo de 20 MB.");
        }
        String tipo = pgTipoReal(item);
        if (tipo == null || !pgTipoCompatible(ext, tipo)) {
            throw new IllegalArgumentException("El contenido del archivo no coincide con su extensión o no es un documento válido.");
        }
        if (!destino.exists() && !destino.mkdirs()) {
            throw new IllegalStateException("No se pudo crear la carpeta de documentos.");
        }
        File objetivo = new File(destino, UUID.randomUUID().toString().replace("-", "") + "." + ext);
        try {
            item.write(objetivo);
        } catch (Exception e) {
            throw new IllegalStateException("No se pudo guardar el archivo.", e);
        }
        return objetivo.getName();
    }

    /**
     * Devuelve los campos del formulario como Map<String,String> y, si la
     * petición es multipart, guarda el archivo subido y deja en la petición:
     * "archivo_subido" (nombre almacenado) o "archivo_error" (motivo).
     */
    static Map<String, String> pgCampos(HttpServletRequest req, ServletContext app) {
        Map<String, String> campos = new HashMap<String, String>();
        if (!ServletFileUpload.isMultipartContent(req)) {
            for (Map.Entry<String, String[]> e : req.getParameterMap().entrySet()) {
                if (e.getValue() != null && e.getValue().length > 0) campos.put(e.getKey(), e.getValue()[0]);
            }
            return campos;
        }
        DiskFileItemFactory factory = new DiskFileItemFactory();
        factory.setSizeThreshold(1024 * 1024);
        ServletFileUpload upload = new ServletFileUpload(factory);
        upload.setHeaderEncoding("UTF-8");
        upload.setFileSizeMax(PG_MAX_BYTES);
        upload.setSizeMax(PG_MAX_BYTES + (1024 * 1024));
        try {
            List<FileItem> items = upload.parseRequest(req);
            for (FileItem item : items) {
                if (item.isFormField()) {
                    campos.put(item.getFieldName(), item.getString("UTF-8"));
                } else if (item.getSize() > 0) {
                    try {
                        req.setAttribute("archivo_subido", pgGuardar(item, pgUploadDir(app)));
                    } catch (IllegalArgumentException ex) {
                        req.setAttribute("archivo_error", ex.getMessage());
                    }
                }
            }
        } catch (FileUploadBase.SizeLimitExceededException ex) {
            req.setAttribute("archivo_error", "El archivo o el formulario supera el tamaño máximo permitido (20 MB).");
        } catch (Exception ex) {
            req.setAttribute("archivo_error", "No se pudo procesar el formulario.");
        }
        return campos;
    }

    // ------------------------------------------------------------------
    // Cabeceras de seguridad
    // ------------------------------------------------------------------
    static void pgCabeceras(HttpServletResponse resp) {
        resp.setHeader("X-Content-Type-Options", "nosniff");
        resp.setHeader("X-Frame-Options", "DENY");
        resp.setHeader("Referrer-Policy", "same-origin");
        resp.setHeader("Content-Security-Policy",
                "default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; "
                + "script-src 'self' 'unsafe-inline'; object-src 'none'; frame-ancestors 'none'; base-uri 'self'");
    }

    static DataSource pgDs(ServletContext app) {
        Object ds = app.getAttribute("ds");
        return (ds instanceof DataSource) ? (DataSource) ds : null;
    }
%>
