#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
e2e_core.py - Casos de prueba end-to-end del Sistema de Trabajos de Grado UTS
(JSP + JSTL sobre Tomcat/MariaDB).

Este módulo contiene TODOS los casos de prueba. No se ejecuta directamente:
se invoca a través de un "envoltorio" que inyecta la forma de consultar la
base de datos y la URL de la aplicación:

    pruebas/e2e_local.py   -> XAMPP local  (http://localhost:8080/tguts)
    pruebas/e2e_tguts.py   -> Docker       (http://localhost:18080/tguts)

Metodología
-----------
* Se ejercita la aplicación a través de HTTP, como lo haría una persona
  (navegador): formularios GET/POST reales, con su token CSRF.
* Cada caso comprueba el resultado observable (código de respuesta, URL final,
  texto de la página) Y, cuando aplica, el estado real en la base de datos.
* Las pruebas usan cuentas propias con sufijo "@e2e.uts.edu.co" creadas por la
  propia interfaz de administración, de modo que los datos de demostración
  del manual (GUION.md) no se alteran.
* Al terminar se borran los datos creados por la prueba y se comprueba que la
  base de datos queda exactamente como estaba antes (mismo número de filas en
  todas las tablas).
"""
import http.cookiejar
import re
import time
import urllib.error
import urllib.parse
import urllib.request

BASE = "http://localhost:8080/tguts"
RUN = str(int(time.time()))

results = []


# =====================================================================
# Utilidades de red
# =====================================================================
class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class Session:
    """Navegador mínimo con cookies (una sesión = una persona)."""

    def __init__(self):
        self.jar = http.cookiejar.CookieJar()
        handler = urllib.request.HTTPCookieProcessor(self.jar)
        self.opener = urllib.request.build_opener(handler)
        self.nofollow = urllib.request.build_opener(handler, _NoRedirect())
        self.token = None

    def request(self, method, path, data=None, follow=True):
        if not path.startswith("http"):
            path = BASE + path
        body = urllib.parse.urlencode(data).encode() if data else None
        req = urllib.request.Request(path, data=body, method=method)
        opener = self.opener if follow else self.nofollow
        try:
            resp = opener.open(req, timeout=30)
            status = resp.status
            final = resp.geturl()
            text = resp.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            status = e.code
            final = e.geturl()
            text = e.read().decode("utf-8", "replace")
        return status, final, text

    def get(self, path, follow=True):
        return self.request("GET", path, follow=follow)

    def post(self, path, data, follow=True):
        return self.request("POST", path, data, follow=follow)

    # -- Token CSRF ---------------------------------------------------
    # El token es estable durante la sesión (common/csrf.jsp) y se renueva al
    # autenticarse (login.jsp). Como algunas pantallas no muestran formulario
    # (por ejemplo, el estudiante que ya tiene anteproyecto), se guarda el
    # último token válido de la sesión y se reutiliza.
    def csrf(self, html=None):
        if html:
            m = re.search(r'name="csrf_token"\s+value="([^"]+)"', html)
            if m:
                self.token = m.group(1)
                return self.token
        if self.token:
            return self.token
        # Último recurso: notificaciones.jsp siempre trae el formulario.
        _, _, html = self.get("/notificaciones.jsp")
        m = re.search(r'name="csrf_token"\s+value="([^"]+)"', html)
        if m:
            self.token = m.group(1)
            return self.token
        raise TestError("No se encontro el token csrf_token en la pagina")


class TestError(Exception):
    """Fallo de aserción de un caso de prueba."""


def check(cond, msg):
    if not cond:
        raise TestError(msg)


def login(email, password):
    """Inicia sesion; devuelve (sesion, ok, cuerpo_html, url_final)."""
    s = Session()
    _, _, html = s.get("/login.jsp")
    token = s.csrf(html)
    status, final, body = s.post(
        "/login.jsp", {"csrf_token": token, "email": email, "password": password})
    ok = "/home.jsp" in final
    if ok:
        # Tras autenticarse el token cambia: se toma el de la sesión nueva.
        _, _, html = s.get("/notificaciones.jsp")
        s.csrf(html)
    return s, ok, body, final


def record(nombre, ok, evidencia):
    results.append((nombre, ok, evidencia))
    print(("APROBADO" if ok else "FALLO  ") + " | " + nombre + " | " + evidencia)


def case(nombre, fn):
    """Ejecuta un caso aislado: un error inesperado se registra como FALLO."""
    try:
        evidencia = fn()
        record(nombre, True, evidencia if evidencia else "ok")
    except TestError as e:
        record(nombre, False, str(e))
    except Exception as e:  # noqa: BLE001 - el fallo no debe abortar la suite
        record(nombre, False, "error inesperado %s: %s" % (type(e).__name__, e))


# =====================================================================
# Utilidades de análisis del HTML
# =====================================================================
def th_headers(html):
    """Encabezados <th> de la PRIMERA tabla de la pagina."""
    m = re.search(r"<table[^>]*>(.*?)</table>", html, re.S | re.I)
    if not m:
        return []
    return [re.sub(r"<[^>]+>", " ", t).split()
            for t in re.findall(r"<th[^>]*>(.*?)</th>", m.group(1), re.S | re.I)]


def th_flat(html):
    out = []
    for partes in th_headers(html):
        out.append(" ".join(partes).strip())
    return out


def table_rows(html):
    """Filas <tr> de la primera tabla (la segunda celda vacía se descarta)."""
    m = re.search(r"<table[^>]*>(.*?)</table>", html, re.S | re.I)
    if not m:
        return []
    filas = []
    for tr in re.findall(r"<tr[^>]*>(.*?)</tr>", m.group(1), re.S | re.I):
        celdas = [re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", td)).strip()
                  for td in re.findall(r"<td[^>]*>(.*?)</td>", tr, re.S | re.I)]
        if celdas:
            filas.append(celdas)
    return filas


def es_403(final):
    return "/403.jsp" in final


def es_csrf(final):
    return "403.jsp?error=csrf" in final


def sin_acentos(texto):
    tabla = {"á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u",
             "Á": "a", "É": "e", "Í": "i", "Ó": "o", "Ú": "u",
             "ñ": "n", "Ñ": "n"}
    return "".join(tabla.get(c, c) for c in texto)


# =====================================================================
# Escenario: preparación de la base de datos
# =====================================================================
# Todas las cuentas de prueba usan el prefijo "e2e-" en el correo, de modo que
# el patrón de limpieza nunca puede tocar los datos de demostración.
PREFIJO_CORREO = "e2e-"

TABLAS = ("usuarios", "ideas", "anteproyectos", "entrega_final", "sustentacion",
          "calificaciones", "notificaciones", "calendario", "formatos", "tramites")

SQL_REINICIO = [
    # 1. Notificaciones: las de los usuarios de prueba y las que mencionan
    #    títulos o nombres de prueba (las que reciben usuarios del sistema).
    "DELETE FROM notificaciones WHERE usuario_id IN "
    "(SELECT id FROM usuarios WHERE email LIKE 'e2e-%@uts.edu.co')",
    "DELETE FROM notificaciones WHERE mensaje LIKE '%E2E %'",
    # 2. Historial de calificaciones.
    "DELETE FROM calificaciones WHERE usuario_id IN "
    "(SELECT id FROM usuarios WHERE email LIKE 'e2e-%@uts.edu.co')",
    "DELETE FROM calificaciones WHERE anteproyecto_id IN "
    "(SELECT a.id FROM anteproyectos a JOIN usuarios u ON u.id = a.estudiante_id "
    "WHERE u.email LIKE 'e2e-%@uts.edu.co')",
    # 3. Entrega del documento final.
    "DELETE FROM entrega_final WHERE anteproyecto_id IN "
    "(SELECT a.id FROM anteproyectos a JOIN usuarios u ON u.id = a.estudiante_id "
    "WHERE u.email LIKE 'e2e-%@uts.edu.co')",
    "DELETE FROM entrega_final WHERE revisado_por IN "
    "(SELECT id FROM usuarios WHERE email LIKE 'e2e-%@uts.edu.co')",
    # 4. Sustentación.
    "DELETE FROM sustentacion WHERE anteproyecto_id IN "
    "(SELECT a.id FROM anteproyectos a JOIN usuarios u ON u.id = a.estudiante_id "
    "WHERE u.email LIKE 'e2e-%@uts.edu.co')",
    # 5. Anteproyectos.
    "DELETE FROM anteproyectos WHERE estudiante_id IN "
    "(SELECT id FROM usuarios WHERE email LIKE 'e2e-%@uts.edu.co')",
    "DELETE FROM anteproyectos WHERE director_id IN "
    "(SELECT id FROM usuarios WHERE email LIKE 'e2e-%@uts.edu.co')",
    "DELETE FROM anteproyectos WHERE evaluador_id IN "
    "(SELECT id FROM usuarios WHERE email LIKE 'e2e-%@uts.edu.co')",
    # 6. Trámites.
    "DELETE FROM tramites WHERE estudiante_id IN "
    "(SELECT id FROM usuarios WHERE email LIKE 'e2e-%@uts.edu.co')",
    "DELETE FROM tramites WHERE resuelto_por IN "
    "(SELECT id FROM usuarios WHERE email LIKE 'e2e-%@uts.edu.co')",
    # 7. Ideas publicadas por los docentes de prueba.
    "DELETE FROM ideas WHERE docente_id IN "
    "(SELECT id FROM usuarios WHERE email LIKE 'e2e-%@uts.edu.co')",
    "DELETE FROM ideas WHERE titulo LIKE 'E2E %'",
    # 8. Calendario y formatos.
    "DELETE FROM calendario WHERE titulo LIKE 'E2E %'",
    "DELETE FROM formatos WHERE nombre LIKE 'E2E %'",
    # 9. Cuentas de prueba.
    "DELETE FROM usuarios WHERE email LIKE 'e2e-%@uts.edu.co'",
]


def ejecutar_todo(db, sql):
    """Ejecuta varios sentencias SQL (el cliente MySQL las acepta separadas por ';')."""
    for sentencia in sql:
        db(sentencia)


def fingerprint(db):
    """Huella de la base de datos: número de filas de cada tabla."""
    partes = []
    for tabla in TABLAS:
        partes.append("%s=%s" % (tabla, db("SELECT COUNT(*) FROM %s;" % tabla)))
    return " ".join(partes)


# =====================================================================
# Casos de prueba
# =====================================================================
def run(db, base=None):
    global BASE, RUN
    if base:
        BASE = base
    RUN = str(int(time.time()))

    print("=" * 100)
    print("PRUEBAS END-TO-END - Sistema de Trabajos de Grado UTS (JSP + JSTL)")
    print("=" * 100)
    print("Aplicacion : " + BASE)
    print("Fecha/hora : " + time.strftime("%Y-%m-%d %H:%M:%S"))
    print("=" * 100)

    # ---------------------------------------------------------------
    # Preparacion: se limpia lo que dejo una ejecucion anterior
    # ---------------------------------------------------------------
    ejecutar_todo(db, SQL_REINICIO)
    firma_inicial = fingerprint(db)
    print("Estado inicial de la base de datos: " + firma_inicial)

    # ---------------------------------------------------------------
    # A. Acceso, sesion y seguridad
    # ---------------------------------------------------------------
    print("\n--- BLOQUE A: acceso, sesion y seguridad -------------------------")

    def a01():
        cuentas = [("admin@uts.edu.co", "admin123"),
                   ("coord@uts.edu.co", "coord123"),
                   ("director@uts.edu.co", "director123"),
                   ("evaluador@uts.edu.co", "evaluador123"),
                   ("estudiante@uts.edu.co", "estudiante123")]
        detalle = []
        ok = True
        for email, pwd in cuentas:
            _, correcto, _, final = login(email, pwd)
            if not correcto:
                ok = False
                detalle.append(email + " -> " + final)
        check(ok, "Cuentas que no entraron: " + "; ".join(detalle))
        return "las 5 cuentas demo (admin, coordinacion, director, evaluador, estudiante) " \
               "ingresaron a home.jsp"

    case("A-01 Login: las 5 cuentas de demostracion acceden al sistema", a01)

    def a02():
        _, ok, body, final = login("admin@uts.edu.co", "clave-incorrecta")
        check(not ok, "una contrasena incorrecta permitio el ingreso")
        check("login.jsp" in final, "la respuesta no volvio al formulario de login: " + final)
        check("nv" in body or "ncorrect" in body.lower(),
              "no se mostro el aviso de credenciales invalidas")
        return "rechazo la contrasena incorrecta y mostro el aviso en login.jsp"

    case("A-02 Login: se rechaza una credencial invalida", a02)

    def a03():
        s = Session()
        status, final, _ = s.get("/usuarios.jsp")
        check("login.jsp" in final, "sin sesion no redirigio al login: " + final)
        return "peticion sin sesion redirigida a login.jsp (HTTP %d)" % status

    case("A-03 Guard: sin sesion no se puede entrar a un modulo protegido", a03)

    def a04():
        admin, _, _, _ = login("admin@uts.edu.co", "admin123")
        status, final, _ = admin.post("/usuarios.jsp",
                                       {"accion": "crear", "nombre": "Sin token",
                                        "email": "sin.token@uts.edu.co",
                                        "password": "clave12345", "rol": "ESTUDIANTE",
                                        "codigo": "999999"})
        check(es_csrf(final), "un POST sin token CSRF no fue bloqueado: " + final)
        check(db("SELECT COUNT(*) FROM usuarios WHERE email='sin.token@uts.edu.co';") == "0",
              "el usuario se creo pese a faltar el token CSRF")
        return "redireccion a 403.jsp?error=csrf y ningun registro creado"

    case("A-04 CSRF: un POST sin token es rechazado", a04)

    def a05():
        admin, _, _, _ = login("admin@uts.edu.co", "admin123")
        _, _, html = admin.get("/usuarios.jsp")
        status, final, _ = admin.post("/usuarios.jsp",
                                       {"csrf_token": "token-falso-123", "accion": "crear",
                                        "nombre": "Token falso", "email": "falso@uts.edu.co",
                                        "password": "clave12345", "rol": "ESTUDIANTE",
                                        "codigo": "999998"})
        check(es_csrf(final), "un token CSRF invalido no fue bloqueado: " + final)
        return "redireccion a 403.jsp?error=csrf con token incorrecto"

    case("A-05 CSRF: un token invalido es rechazado", a05)

    def a06():
        est, _, _, _ = login("estudiante@uts.edu.co", "estudiante123")
        status, final, _ = est.get("/usuarios.jsp")
        check(es_403(final), "el estudiante accedio a la gestion de usuarios: " + final)
        return "HTTP %d, redireccion a 403.jsp" % status

    case("A-06 Roles: el estudiante no entra a la gestion de usuarios", a06)

    def a07():
        dr, _, _, _ = login("director@uts.edu.co", "director123")
        status, final, _ = dr.get("/informes.jsp")
        check(es_403(final), "el director accedio a los informes: " + final)
        return "HTTP %d, redireccion a 403.jsp" % status

    case("A-07 Roles: el director no entra a los informes", a07)

    def a08():
        ev, _, _, _ = login("evaluador@uts.edu.co", "evaluador123")
        status, final, _ = ev.get("/ideas.jsp")
        check(es_403(final), "el evaluador accedio al banco de ideas: " + final)
        return "HTTP %d, redireccion a 403.jsp" % status

    case("A-08 Roles: el evaluador no entra al banco de ideas", a08)

    def a09():
        coord, _, _, _ = login("coord@uts.edu.co", "coord123")
        status, final, _ = coord.get("/usuarios.jsp")
        check(es_403(final), "la coordinacion accedio a la gestion de usuarios: " + final)
        return "HTTP %d, redireccion a 403.jsp" % status

    case("A-09 Roles: la coordinacion no entra a la gestion de usuarios", a09)

    def a10():
        est, _, _, _ = login("estudiante@uts.edu.co", "estudiante123")
        status, final, _ = est.get("/coordinacion.jsp")
        check(es_403(final), "el estudiante accedio al modulo de coordinacion: " + final)
        return "HTTP %d, redireccion a 403.jsp" % status

    case("A-10 Roles: el estudiante no entra al modulo de coordinacion", a10)

    def a11():
        est, _, _, _ = login("estudiante@uts.edu.co", "estudiante123")
        status, final, _ = est.get("/logout.jsp")
        check("login.jsp" in final, "el cierre de sesion no volvio al login: " + final)
        _, final2, _ = est.get("/usuarios.jsp")
        check("login.jsp" in final2, "tras cerrar sesion aun se podia entrar: " + final2)
        return "la sesion se cerro y la pagina protegida volvio a exigir login"

    case("A-11 Sesion: cerrar sesion invalida el acceso", a11)

    def a12():
        est, ok_login, html, _ = login("estudiante@uts.edu.co", "estudiante123")
        check(ok_login, "el estudiante no pudo iniciar sesion")
        check("Banco de ideas" in html, "el estudiante no ve el banco de ideas en el menu")
        check("Gestión de usuarios" not in html, "el estudiante ve la gestion de usuarios")
        check("Informes" not in html, "el estudiante ve los informes en el menu")
        check("Buscar estudiante" not in html, "el estudiante ve la busqueda de estudiantes")
        admin, ok_admin, html_admin, _ = login("admin@uts.edu.co", "admin123")
        check(ok_admin, "el administrador no pudo iniciar sesion")
        check("Gestión de usuarios" in html_admin, "el administrador no ve la gestion de usuarios")
        check("Informes" in html_admin, "el administrador no ve los informes en el menu")
        check("Banco de ideas" in html_admin, "el administrador no ve el banco de ideas")
        return "el menu lateral se construye segun el rol (RF-03 / RNF-02)"

    case("A-12 Menu: cada rol ve solo los modulos que le corresponden", a12)

    # ---------------------------------------------------------------
    # B. Administracion de usuarios (CRUD) - RF-04 a RF-08
    # ---------------------------------------------------------------
    print("\n--- BLOQUE B: administracion de usuarios (CRUD) ------------------")

    admin, _, _, _ = login("admin@uts.edu.co", "admin123")

    def crear_usuario(nombre, email, password, rol, codigo=""):
        _, _, html = admin.get("/usuarios.jsp")
        token = admin.csrf(html)
        return admin.post("/usuarios.jsp", {
            "csrf_token": token, "accion": "crear", "nombre": nombre, "email": email,
            "password": password, "rol": rol, "codigo": codigo})

    def crear_idea(rol_sesion, titulo, descripcion, docente=None):
        """Registra una idea en el banco de ideas con la sesion indicada."""
        _, _, html = rol_sesion.get("/ideas.jsp")
        token = rol_sesion.csrf(html)
        datos = {"csrf_token": token, "accion": "crear", "titulo": titulo,
                 "descripcion": descripcion}
        if docente is not None:
            datos["docente"] = docente
        return rol_sesion.post("/ideas.jsp", datos)

    def b01():
        status, final, body = crear_usuario(
            "Director E2E Uno", "e2e-director1@uts.edu.co", "e2edirector2026", "DIRECTOR")
        fila = db("SELECT rol FROM usuarios WHERE email='e2e-director1@uts.edu.co';")
        check(fila == "DIRECTOR", "el usuario no se registro con rol DIRECTOR: " + repr(fila))
        check("exito=creado" in final or "Usuario creado correctamente" in body,
              "no se mostro la confirmacion de creacion: " + final)
        return "usuario creado por el administrador (id=%s)" % db(
            "SELECT id FROM usuarios WHERE email='e2e-director1@uts.edu.co';")

    case("B-01 Usuarios: el administrador crea un director", b01)

    def b02():
        _, ok, _, final = login("e2e-director1@uts.edu.co", "e2edirector2026")
        check(ok, "el usuario creado no pudo iniciar sesion: " + final)
        return "el usuario creado por el administrador inicio sesion correctamente"

    case("B-02 Usuarios: la cuenta creada puede iniciar sesion", b02)

    crear_usuario("Director E2E Dos", "e2e-director2@uts.edu.co", "e2edirector2026", "DIRECTOR")
    crear_usuario("Evaluador E2E", "e2e-evaluador@uts.edu.co", "e2eevaluador2026", "EVALUADOR")
    crear_usuario("Coordinacion E2E", "e2e-coordinacion@uts.edu.co", "e2ecoordinacion2026", "COORDINACION")
    crear_usuario("Estudiante E2E Uno", "e2e-estudiante1@uts.edu.co", "e2eestudiante2026", "ESTUDIANTE", "900001")
    crear_usuario("Estudiante E2E Dos", "e2e-estudiante2@uts.edu.co", "e2eestudiante2026", "ESTUDIANTE", "900002")
    crear_usuario("Estudiante E2E Tres", "e2e-estudiante3@uts.edu.co", "e2eestudiante2026", "ESTUDIANTE", "900003")
    crear_usuario("Estudiante E2E Cuatro", "e2e-estudiante4@uts.edu.co", "e2eestudiante2026", "ESTUDIANTE", "900004")

    dir_id = db("SELECT id FROM usuarios WHERE email='e2e-director1@uts.edu.co';")
    dir2_id = db("SELECT id FROM usuarios WHERE email='e2e-director2@uts.edu.co';")
    eval_id = db("SELECT id FROM usuarios WHERE email='e2e-evaluador@uts.edu.co';")
    coord_id = db("SELECT id FROM usuarios WHERE email='e2e-coordinacion@uts.edu.co';")
    est_id = db("SELECT id FROM usuarios WHERE email='e2e-estudiante1@uts.edu.co';")
    est2_id = db("SELECT id FROM usuarios WHERE email='e2e-estudiante2@uts.edu.co';")
    est3_id = db("SELECT id FROM usuarios WHERE email='e2e-estudiante3@uts.edu.co';")
    est4_id = db("SELECT id FROM usuarios WHERE email='e2e-estudiante4@uts.edu.co';")

    def b03():
        _, _, html = admin.get("/usuarios.jsp")
        token = admin.csrf(html)
        admin.post("/usuarios.jsp", {
            "csrf_token": token, "accion": "actualizar", "id": est2_id,
            "nombre": "Estudiante E2E Dos Editado", "email": "e2e-estudiante2@uts.edu.co",
            "password": "", "rol": "ESTUDIANTE", "codigo": "900002"})
        nombre = db("SELECT nombre FROM usuarios WHERE id=%s;" % est2_id)
        codigo = db("SELECT codigo FROM usuarios WHERE id=%s;" % est2_id)
        check("Editado" in nombre, "el nombre no se actualizo: " + repr(nombre))
        check(codigo == "900002", "el codigo no se conservo: " + repr(codigo))
        return "nombre actualizado a '%s' conservando el codigo %s" % (nombre, codigo)

    case("B-03 Usuarios: el administrador edita un usuario", b03)

    def b04():
        _, _, html = admin.get("/usuarios.jsp")
        token = admin.csrf(html)
        _, final, body = admin.post("/usuarios.jsp", {
            "csrf_token": token, "accion": "crear", "nombre": "Duplicado",
            "email": "e2e-director1@uts.edu.co", "password": "e2eduplicado2026",
            "rol": "DIRECTOR", "codigo": ""})
        check("Ya existe un usuario con ese correo" in body,
              "no se aviso del correo duplicado")
        check(db("SELECT COUNT(*) FROM usuarios WHERE email='e2e-director1@uts.edu.co';") == "1",
              "se creo un usuario duplicado")
        return "el correo duplicado fue rechazado con el aviso correspondiente"

    case("B-04 Usuarios: se rechaza un correo ya registrado", b04)

    def b05():
        _, _, html = admin.get("/usuarios.jsp")
        token = admin.csrf(html)
        _, final, body = admin.post("/usuarios.jsp", {
            "csrf_token": token, "accion": "crear", "nombre": "Corto",
            "email": "e2e-corto@uts.edu.co", "password": "12345",
            "rol": "DIRECTOR", "codigo": ""})
        check("al menos 8 caracteres" in body, "no se aviso del largo minimo de la contrasena")
        check(db("SELECT COUNT(*) FROM usuarios WHERE email='e2e-corto@uts.edu.co';") == "0",
              "se creo el usuario con contrasena corta")
        return "la contrasena de menos de 8 caracteres fue rechazada"

    case("B-05 Usuarios: se valida el largo minimo de la contrasena", b05)

    def b06():
        _, _, html = admin.get("/usuarios.jsp")
        token = admin.csrf(html)
        _, final, body = admin.post("/usuarios.jsp", {
            "csrf_token": token, "accion": "crear", "nombre": "Sin codigo",
            "email": "e2e-sincodigo@uts.edu.co", "password": "e2eestudiante2026",
            "rol": "ESTUDIANTE", "codigo": ""})
        check("c" in body and "estudiante" in body.lower(),
              "no se aviso del codigo obligatorio del estudiante")
        check(db("SELECT COUNT(*) FROM usuarios WHERE email='e2e-sincodigo@uts.edu.co';") == "0",
              "se creo el estudiante sin codigo")
        return "el estudiante sin codigo fue rechazado"

    case("B-06 Usuarios: el estudiante exige codigo de matricula", b06)

    def b07():
        crear_usuario("Temporal E2E", "e2e-temporal@uts.edu.co", "e2etemporal2026", "DIRECTOR")
        tmp_id = db("SELECT id FROM usuarios WHERE email='e2e-temporal@uts.edu.co';")
        check(tmp_id != "", "no se pudo crear el usuario temporal")
        _, _, html = admin.get("/usuarios.jsp")
        token = admin.csrf(html)
        _, final, _ = admin.post("/usuarios.jsp",
                                  {"csrf_token": token, "accion": "eliminar", "id": tmp_id})
        check(db("SELECT COUNT(*) FROM usuarios WHERE id=%s;" % tmp_id) == "0",
              "el usuario no se elimino")
        check("exito=eliminado" in final, "no se mostro la confirmacion de eliminacion: " + final)
        return "usuario temporal creado y eliminado correctamente"

    case("B-07 Usuarios: se elimina un usuario sin dependencias", b07)

    def b08():
        # El estudiante de prueba se registra un anteproyecto; con ese dato
        # asociado el administrador NO debe poder eliminar la cuenta.
        est3_ses, _, _, _ = login("e2e-estudiante3@uts.edu.co", "e2eestudiante2026")
        idea_id = db("SELECT id FROM ideas WHERE titulo LIKE 'E2E idea de integridad%' LIMIT 1;")
        if idea_id == "":
            titulo = "E2E idea de integridad " + RUN
            crear_idea(admin, titulo, "idea para probar la integridad referencial", docente=dir_id)
            idea_id = db("SELECT id FROM ideas WHERE titulo='%s';" % titulo)
        _, _, html = est3_ses.get("/ideas.jsp")
        token = est3_ses.csrf(html)
        est3_ses.post("/ideas.jsp", {"csrf_token": token, "accion": "seleccionar", "id": idea_id})
        check(db("SELECT COUNT(*) FROM anteproyectos WHERE estudiante_id=%s;" % est3_id) == "1",
              "no se pudo crear el anteproyecto que da la dependencia")
        _, _, html = admin.get("/usuarios.jsp")
        token = admin.csrf(html)
        _, final, body = admin.post("/usuarios.jsp",
                                    {"csrf_token": token, "accion": "eliminar", "id": est3_id})
        check("No se puede eliminar" in body, "no se mostro el aviso de integridad referencial")
        check(db("SELECT COUNT(*) FROM usuarios WHERE id=%s;" % est3_id) == "1",
              "el usuario con dependencias fue eliminado")
        return "el administrador no pudo eliminar a un estudiante con anteproyecto asociado"

    case("B-08 Usuarios: no se elimina a quien tiene datos asociados", b08)

    def b09():
        admin_id = db("SELECT id FROM usuarios WHERE email='admin@uts.edu.co';")
        _, _, html = admin.get("/usuarios.jsp")
        token = admin.csrf(html)
        _, final, body = admin.post("/usuarios.jsp",
                                    {"csrf_token": token, "accion": "eliminar", "id": admin_id})
        check("No puedes eliminar la cuenta con la que est" in body,
              "no se aviso que no se puede eliminar la propia cuenta")
        check(db("SELECT COUNT(*) FROM usuarios WHERE id=%s;" % admin_id) == "1",
              "la cuenta propia fue eliminada")
        return "el administrador no pudo eliminar su propia cuenta"

    case("B-09 Usuarios: no se puede eliminar la cuenta propia", b09)

    # ---------------------------------------------------------------
    # C. Banco de ideas (CRUD) - RF-09 a RF-13, RF-25
    # ---------------------------------------------------------------
    print("\n--- BLOQUE C: banco de ideas (CRUD) ----------------------------")

    dir_ses, _, _, _ = login("e2e-director1@uts.edu.co", "e2edirector2026")

    def c01():
        titulo = "E2E idea publicada por el director " + RUN
        crear_idea(dir_ses, titulo, "idea de prueba del director")
        fila = db("SELECT docente_id FROM ideas WHERE titulo='%s';" % titulo)
        check(fila == dir_id, "la idea no quedo a nombre del director: " + repr(fila))
        return "la idea se registro con docente_id=%s (el director)" % fila

    case("C-01 Ideas: el director publica una idea a su nombre", c01)

    def c02():
        titulo = "E2E idea publicada por la administracion " + RUN
        crear_idea(admin, titulo, "idea de prueba de la administracion", docente=eval_id)
        fila = db("SELECT docente_id FROM ideas WHERE titulo='%s';" % titulo)
        check(fila == eval_id, "la idea no quedo con el docente elegido: " + repr(fila))
        return "la administracion publico la idea asignando al docente id=%s" % fila

    case("C-02 Ideas: la administracion publica indicando el docente", c02)

    def c03():
        titulo = "E2E idea docente invalido " + RUN
        _, _, body = crear_idea(admin, titulo, "debe fallar", docente=coord_id)
        check("no es un Docente v" in body, "no se aviso que el usuario no es docente")
        check(db("SELECT COUNT(*) FROM ideas WHERE titulo='%s';" % titulo) == "0",
              "la idea con docente invalido se registro")
        return "se rechazo asignar como docente a un usuario que no es Director/Evaluador"

    case("C-03 Ideas: se valida que el docente sea Director o Evaluador", c03)

    def c04():
        titulo = "E2E idea para editar " + RUN
        crear_idea(admin, titulo, "idea que se va a editar", docente=eval_id)
        idea_id = db("SELECT id FROM ideas WHERE titulo='%s';" % titulo)
        _, _, html = admin.get("/ideas.jsp?accion=editar&id=" + idea_id)
        token = admin.csrf(html)
        admin.post("/ideas.jsp", {"csrf_token": token, "accion": "actualizar", "id": idea_id,
                                  "titulo": titulo + " (editada)", "descripcion": "editada",
                                  "docente": dir_id})
        docente = db("SELECT docente_id FROM ideas WHERE id=%s;" % idea_id)
        titulo_final = db("SELECT titulo FROM ideas WHERE id=%s;" % idea_id)
        check(docente == dir_id, "el docente no se actualizo: " + repr(docente))
        check("editada" in titulo_final, "el titulo no se actualizo")
        return "la idea se edito y cambio de docente (id=%s -> id=%s)" % (eval_id, docente)

    case("C-04 Ideas: la administracion edita la idea y cambia el docente", c04)

    def c05():
        titulo = "E2E idea para cerrar " + RUN
        crear_idea(admin, titulo, "idea que se va a cerrar", docente=dir_id)
        idea_id = db("SELECT id FROM ideas WHERE titulo='%s';" % titulo)
        _, _, html = admin.get("/ideas.jsp")
        token = admin.csrf(html)
        admin.post("/ideas.jsp", {"csrf_token": token, "accion": "cerrar", "id": idea_id})
        estado = db("SELECT estado FROM ideas WHERE id=%s;" % idea_id)
        check(estado == "CERRADA", "la idea no se cerro: " + repr(estado))
        est_ses, _, _, _ = login("e2e-estudiante4@uts.edu.co", "e2eestudiante2026")
        _, _, html_est = est_ses.get("/ideas.jsp")
        check(titulo not in html_est, "la idea cerrada sigue apareciendo al estudiante")
        return "la idea quedo en estado CERRADA y dejo de ofrecerse a los estudiantes"

    case("C-05 Ideas: cerrar una idea la retira de la bolsa del estudiante", c05)

    def c06():
        titulo = "E2E idea para eliminar " + RUN
        crear_idea(admin, titulo, "idea que se va a eliminar", docente=dir_id)
        idea_id = db("SELECT id FROM ideas WHERE titulo='%s';" % titulo)
        _, _, html = admin.get("/ideas.jsp")
        token = admin.csrf(html)
        admin.post("/ideas.jsp", {"csrf_token": token, "accion": "eliminar", "id": idea_id})
        check(db("SELECT COUNT(*) FROM ideas WHERE id=%s;" % idea_id) == "0",
              "la idea no se elimino")
        return "la idea se elimino del banco de ideas"

    case("C-06 Ideas: la administracion elimina una idea", c06)

    def c07():
        est_ses, _, _, _ = login("e2e-estudiante4@uts.edu.co", "e2eestudiante2026")
        _, _, html = est_ses.get("/ideas.jsp")
        token = est_ses.csrf(html)
        _, final, _ = est_ses.post("/ideas.jsp", {
            "csrf_token": token, "accion": "crear", "titulo": "E2E idea de estudiante " + RUN,
            "descripcion": "no debe crearse"})
        check(es_403(final), "el estudiante pudo publicar una idea: " + final)
        check(db("SELECT COUNT(*) FROM ideas WHERE titulo='E2E idea de estudiante %s';" % RUN) == "0",
              "la idea del estudiante se registro")
        return "redireccion a 403.jsp: el estudiante no publica ideas"

    case("C-07 Ideas: el estudiante no puede publicar ideas", c07)

    # ---------------------------------------------------------------
    # D. Anteproyecto del estudiante (CRUD) - RF-11 a RF-16
    # ---------------------------------------------------------------
    print("\n--- BLOQUE D: anteproyecto del estudiante (CRUD) ----------------")

    def crear_idea_para(nombre_base):
        titulo = "E2E " + nombre_base + " " + RUN
        crear_idea(admin, titulo, "idea de la prueba " + nombre_base, docente=dir_id)
        return db("SELECT id FROM ideas WHERE titulo='%s';" % titulo)

    def seleccionar(est_ses, idea_id):
        _, _, html = est_ses.get("/ideas.jsp")
        token = est_ses.csrf(html)
        return est_ses.post("/ideas.jsp", {"csrf_token": token, "accion": "seleccionar",
                                           "id": idea_id})

    def d01():
        idea_id = crear_idea_para("idea del flujo A")
        est_ses, _, _, _ = login("e2e-estudiante1@uts.edu.co", "e2eestudiante2026")
        _, final, _ = seleccionar(est_ses, idea_id)
        ant_id = db("SELECT id FROM anteproyectos WHERE estudiante_id=%s;" % est_id)
        estado = db("SELECT estado FROM anteproyectos WHERE id=%s;" % ant_id)
        estado_idea = db("SELECT estado FROM ideas WHERE id=%s;" % idea_id)
        check(ant_id != "", "no se creo el anteproyecto")
        check(estado == "BORRADOR", "el anteproyecto no quedo en BORRADOR: " + repr(estado))
        check(estado_idea == "SELECCIONADA", "la idea no quedo SELECCIONADA: " + repr(estado_idea))
        return "anteproyecto id=%s en BORRADOR; la idea paso a SELECCIONADA" % ant_id

    case("D-01 Anteproyecto: el estudiante selecciona una idea y se registra su anteproyecto", d01)

    ant_a_id = db("SELECT id FROM anteproyectos WHERE estudiante_id=%s;" % est_id)

    def d02():
        idea2 = crear_idea_para("idea secundaria del flujo A")
        est_ses, _, _, _ = login("e2e-estudiante1@uts.edu.co", "e2eestudiante2026")
        _, final, _ = seleccionar(est_ses, idea2)
        check("error=tiene" in final, "no se aviso que ya tiene un anteproyecto: " + final)
        estado2 = db("SELECT estado FROM ideas WHERE id=%s;" % idea2)
        check(estado2 == "PUBLICADA", "la segunda idea quedo en " + repr(estado2))
        return "la segunda seleccion se rechazo con el aviso 'Ya tienes un anteproyecto registrado'"

    case("D-02 Anteproyecto: no se puede seleccionar una segunda idea", d02)

    def d03():
        idea_cerrada = crear_idea_para("idea cerrada")
        db("UPDATE ideas SET estado='CERRADA' WHERE id=%s;" % idea_cerrada)
        est_ses, _, _, _ = login("e2e-estudiante2@uts.edu.co", "e2eestudiante2026")
        _, final, _ = seleccionar(est_ses, idea_cerrada)
        check("error=noexiste" in final, "no se aviso que la idea no esta disponible: " + final)
        check(db("SELECT COUNT(*) FROM anteproyectos WHERE estudiante_id=%s;" % est2_id) == "0",
              "se creo un anteproyecto a partir de una idea cerrada")
        return "la seleccion de una idea cerrada fue rechazada"

    case("D-03 Anteproyecto: no se puede seleccionar una idea cerrada", d03)

    def d04():
        est_ses, _, _, _ = login("e2e-estudiante1@uts.edu.co", "e2eestudiante2026")
        _, _, html = est_ses.get("/anteproyecto_form.jsp?id=" + ant_a_id)
        token = est_ses.csrf(html)
        _, final, _ = est_ses.post("/anteproyecto_form.jsp?id=" + ant_a_id, {
            "csrf_token": token, "titulo": "E2E Anteproyecto " + RUN,
            "director": dir_id, "documento": "https://drive.google.com/e2e/anteproyecto.pdf"})
        estado = db("SELECT estado FROM anteproyectos WHERE id=%s;" % ant_a_id)
        documento = db("SELECT documento FROM anteproyectos WHERE id=%s;" % ant_a_id)
        check(estado == "ENVIADO", "el anteproyecto no paso a ENVIADO: " + repr(estado))
        check("drive.google.com" in documento, "no se guardo el enlace del documento")
        return "el anteproyecto paso a ENVIADO con director id=%s y enlace del documento" % dir_id

    case("D-04 Anteproyecto: el estudiante completa y envia su anteproyecto", d04)

    def d05():
        est_ses, _, _, _ = login("e2e-estudiante2@uts.edu.co", "e2eestudiante2026")
        idea_b = crear_idea_para("idea del flujo B")
        seleccionar(est_ses, idea_b)
        ant_b = db("SELECT id FROM anteproyectos WHERE estudiante_id=%s;" % est2_id)
        check(ant_b != "", "no se creo el anteproyecto del flujo B")
        _, _, html = est_ses.get("/anteproyecto_form.jsp?id=" + ant_b)
        token = est_ses.csrf(html)
        _, _, body = est_ses.post("/anteproyecto_form.jsp?id=" + ant_b, {
            "csrf_token": token, "titulo": "E2E Anteproyecto B " + RUN,
            "director": coord_id, "documento": "https://drive.google.com/e2e/b.pdf"})
        check("Director v" in body, "no se aviso que el director no es valido")
        estado = db("SELECT estado FROM anteproyectos WHERE id=%s;" % ant_b)
        check(estado == "BORRADOR", "el anteproyecto cambio de estado: " + repr(estado))
        return "el servidor rechazo a la coordinacion como director (estado %s)" % estado

    case("D-05 Anteproyecto: el director debe tener rol DIRECTOR activo", d05)

    def d06():
        est_ses, _, _, _ = login("e2e-estudiante2@uts.edu.co", "e2eestudiante2026")
        ant_b = db("SELECT id FROM anteproyectos WHERE estudiante_id=%s;" % est2_id)
        _, _, html = est_ses.get("/anteproyecto_form.jsp?id=" + ant_b)
        token = est_ses.csrf(html)
        _, _, body = est_ses.post("/anteproyecto_form.jsp?id=" + ant_b, {
            "csrf_token": token, "titulo": "E2E Anteproyecto B " + RUN,
            "director": dir_id, "documento": "ftp://servidor/archivo.pdf"})
        check("http:// o https://" in body, "no se aviso que la URL es invalida")
        estado = db("SELECT estado FROM anteproyectos WHERE id=%s;" % ant_b)
        check(estado == "BORRADOR", "el anteproyecto cambio de estado: " + repr(estado))
        return "se rechazo una URL de documento que no es http/https"

    case("D-06 Anteproyecto: la URL del documento debe ser http o https", d06)

    def d07():
        # Reutiliza el anteproyecto en borrador creado en B-08: al eliminarlo
        # la idea debe volver a la bolsa de ideas.
        est_ses, _, _, _ = login("e2e-estudiante3@uts.edu.co", "e2eestudiante2026")
        ant_c = db("SELECT id FROM anteproyectos WHERE estudiante_id=%s;" % est3_id)
        check(ant_c != "", "no se encontro el anteproyecto de prueba")
        idea_c = db("SELECT idea_id FROM anteproyectos WHERE id=%s;" % ant_c)
        _, _, html = est_ses.get("/anteproyecto_ver.jsp?id=" + ant_c)
        token = est_ses.csrf(html)
        _, final, _ = est_ses.post("/anteproyecto_ver.jsp?id=" + ant_c,
                                    {"csrf_token": token, "accion": "eliminar_anteproyecto"})
        check(db("SELECT COUNT(*) FROM anteproyectos WHERE id=%s;" % ant_c) == "0",
              "el anteproyecto en borrador no se elimino")
        estado_idea = db("SELECT estado FROM ideas WHERE id=%s;" % idea_c)
        check(estado_idea == "PUBLICADA", "la idea no volvio a PUBLICADA: " + repr(estado_idea))
        return "el anteproyecto en BORRADOR se elimino y la idea quedo disponible otra vez"

    case("D-07 Anteproyecto: se elimina un borrador y la idea vuelve a la bolsa", d07)

    def d08():
        est_ses, _, _, _ = login("e2e-estudiante1@uts.edu.co", "e2eestudiante2026")
        _, _, html = est_ses.get("/anteproyecto_ver.jsp?id=" + ant_a_id)
        token = est_ses.csrf(html)
        _, final, _ = est_ses.post("/anteproyecto_ver.jsp?id=" + ant_a_id,
                                    {"csrf_token": token, "accion": "eliminar_anteproyecto"})
        check("error=estado" in final, "no se aviso que la operacion no esta permitida: " + final)
        check(db("SELECT COUNT(*) FROM anteproyectos WHERE id=%s;" % ant_a_id) == "1",
              "el anteproyecto enviado se elimino")
        return "un anteproyecto ya enviado no se puede eliminar"

    case("D-08 Anteproyecto: un anteproyecto enviado no se puede eliminar", d08)

    def d09():
        est2_ses, _, _, _ = login("e2e-estudiante2@uts.edu.co", "e2eestudiante2026")
        status, final, _ = est2_ses.get("/anteproyecto_ver.jsp?id=" + ant_a_id)
        check(es_403(final), "el estudiante vio el anteproyecto de otro: " + final)
        return "HTTP %d, redireccion a 403.jsp" % status

    case("D-09 Anteproyecto: un estudiante no ve el anteproyecto de otro", d09)

    def d10():
        # El estudiante 2 envia su anteproyecto (flujo B) para que el director
        # pueda rechazarlo con observaciones.
        est_ses, _, _, _ = login("e2e-estudiante2@uts.edu.co", "e2eestudiante2026")
        ant_b = db("SELECT id FROM anteproyectos WHERE estudiante_id=%s;" % est2_id)
        _, _, html = est_ses.get("/anteproyecto_form.jsp?id=" + ant_b)
        token = est_ses.csrf(html)
        est_ses.post("/anteproyecto_form.jsp?id=" + ant_b, {
            "csrf_token": token, "titulo": "E2E Anteproyecto B " + RUN,
            "director": dir_id, "documento": "https://drive.google.com/e2e/b.pdf"})
        estado = db("SELECT estado FROM anteproyectos WHERE id=%s;" % ant_b)
        check(estado == "ENVIADO", "el anteproyecto B no quedo ENVIADO: " + repr(estado))
        return "anteproyecto id=%s enviado por el estudiante de prueba" % ant_b

    case("D-10 Anteproyecto: el estudiante envia el anteproyecto del flujo B", d10)

    ant_b_id = db("SELECT id FROM anteproyectos WHERE estudiante_id=%s;" % est2_id)

    # ---------------------------------------------------------------
    # E. Direccion del anteproyecto - RF-18 a RF-20, RF-35
    # ---------------------------------------------------------------
    print("\n--- BLOQUE E: direccion del anteproyecto ------------------------")

    def e01():
        dr, _, _, _ = login("e2e-director1@uts.edu.co", "e2edirector2026")
        _, _, html = dr.get("/anteproyecto_ver.jsp?id=" + ant_a_id)
        token = dr.csrf(html)
        dr.post("/anteproyecto_ver.jsp?id=" + ant_a_id, {
            "csrf_token": token, "accion": "calificar", "calificacion": "4.5",
            "observacion": "calificacion de prueba"})
        cal = db("SELECT calificacion_director FROM anteproyectos WHERE id=%s;" % ant_a_id)
        hist = db("SELECT COUNT(*) FROM calificaciones WHERE anteproyecto_id=%s "
                  "AND rol_calificador='DIRECTOR';" % ant_a_id)
        check(cal == "4.5", "la calificacion no se guardo: " + repr(cal))
        check(hist == "1", "no se registro el historial de calificaciones: " + repr(hist))
        return "calificacion_director=%s y 1 registro en el historial de calificaciones" % cal

    case("E-01 Director: califica el anteproyecto y se guarda el historial", e01)

    def e02():
        dr, _, _, _ = login("e2e-director1@uts.edu.co", "e2edirector2026")
        _, _, html = dr.get("/anteproyecto_ver.jsp?id=" + ant_a_id)
        token = dr.csrf(html)
        dr.post("/anteproyecto_ver.jsp?id=" + ant_a_id,
                {"csrf_token": token, "accion": "eliminar_calificacion"})
        cal = db("SELECT calificacion_director FROM anteproyectos WHERE id=%s;" % ant_a_id)
        hist = db("SELECT COUNT(*) FROM calificaciones WHERE anteproyecto_id=%s "
                  "AND rol_calificador='DIRECTOR';" % ant_a_id)
        check(cal == "NULL", "la calificacion no se borro: " + repr(cal))
        check(hist == "0", "el historial no se borro: " + repr(hist))
        return "la calificacion y su registro historico quedaron en NULL / 0 filas"

    case("E-02 Director: elimina su calificacion y el historial queda consistente", e02)

    def e03():
        dr, _, _, _ = login("e2e-director1@uts.edu.co", "e2edirector2026")
        _, _, html = dr.get("/anteproyecto_ver.jsp?id=" + ant_a_id)
        token = dr.csrf(html)
        _, final, _ = dr.post("/anteproyecto_ver.jsp?id=" + ant_a_id, {
            "csrf_token": token, "accion": "calificar", "calificacion": "9",
            "observacion": "fuera de rango"})
        check("error=malcalificacion" in final, "no se aviso el rango invalido: " + final)
        cal = db("SELECT calificacion_director FROM anteproyectos WHERE id=%s;" % ant_a_id)
        check(cal == "NULL", "la calificacion invalida se guardo: " + repr(cal))
        return "la calificacion fuera del rango 0-5 fue rechazada y no se guardo"

    case("E-03 Director: se valida el rango de la calificacion (0 a 5)", e03)

    def e04():
        dr, _, _, _ = login("e2e-director1@uts.edu.co", "e2edirector2026")
        _, _, html = dr.get("/anteproyecto_ver.jsp?id=" + ant_a_id)
        token = dr.csrf(html)
        _, final, _ = dr.post("/anteproyecto_ver.jsp?id=" + ant_a_id,
                               {"csrf_token": token, "accion": "aprobar"})
        check("error=nocalifica" in final, "no se aviso que falta calificar: " + final)
        estado = db("SELECT estado FROM anteproyectos WHERE id=%s;" % ant_a_id)
        check(estado == "ENVIADO", "el anteproyecto avanzo sin calificacion: " + repr(estado))
        return "la aprobacion se bloqueo (error=nocalifica); el estado sigue en ENVIADO"

    case("E-04 Director: no se puede aprobar sin calificar antes", e04)

    def e05():
        dr, _, _, _ = login("e2e-director1@uts.edu.co", "e2edirector2026")
        _, _, html = dr.get("/anteproyecto_ver.jsp?id=" + ant_a_id)
        token = dr.csrf(html)
        dr.post("/anteproyecto_ver.jsp?id=" + ant_a_id, {
            "csrf_token": token, "accion": "calificar", "calificacion": "4.0",
            "observacion": "listo para el evaluador"})
        _, _, html = dr.get("/anteproyecto_ver.jsp?id=" + ant_a_id)
        token = dr.csrf(html)
        _, final, _ = dr.post("/anteproyecto_ver.jsp?id=" + ant_a_id,
                               {"csrf_token": token, "accion": "aprobar"})
        estado = db("SELECT estado FROM anteproyectos WHERE id=%s;" % ant_a_id)
        evaluador = db("SELECT evaluador_id FROM anteproyectos WHERE id=%s;" % ant_a_id)
        check(estado == "APROBADO_DIRECTOR", "el estado no avanzo: " + repr(estado))
        check(evaluador != "NULL", "no se asigno ningun evaluador")
        return "estado=%s y evaluador asignado automaticamente (id=%s)" % (estado, evaluador)

    case("E-05 Director: aprueba el anteproyecto y el trabajo pasa al evaluador", e05)

    def e06():
        dr, _, _, _ = login("e2e-director1@uts.edu.co", "e2edirector2026")
        _, _, html = dr.get("/anteproyecto_ver.jsp?id=" + ant_b_id)
        token = dr.csrf(html)
        dr.post("/anteproyecto_ver.jsp?id=" + ant_b_id, {
            "csrf_token": token, "accion": "calificar", "calificacion": "3.0",
            "observacion": "calificacion preliminar"})
        _, _, html = dr.get("/anteproyecto_ver.jsp?id=" + ant_b_id)
        token = dr.csrf(html)
        _, final, _ = dr.post("/anteproyecto_ver.jsp?id=" + ant_b_id, {
            "csrf_token": token, "accion": "rechazar",
            "observacion": "falta la bibliografia"})
        estado = db("SELECT estado FROM anteproyectos WHERE id=%s;" % ant_b_id)
        obs = db("SELECT observacion_director FROM anteproyectos WHERE id=%s;" % ant_b_id)
        check(estado == "RECHAZADO", "el anteproyecto no fue rechazado: " + repr(estado))
        check("bibliografia" in obs, "no se guardo la observacion del rechazo: " + repr(obs))
        notif = db("SELECT COUNT(*) FROM notificaciones WHERE usuario_id=%s "
                   "AND evento='ANTEPROYECTO_RECHAZADO';" % est2_id)
        check(notif != "0", "el estudiante no fue notificado del rechazo")
        return "estado=%s con la observacion del director guardada y estudiante notificado" % estado

    case("E-06 Director: puede rechazar el anteproyecto con observaciones", e06)

    def e07():
        est2_ses, _, _, _ = login("e2e-estudiante2@uts.edu.co", "e2eestudiante2026")
        _, _, html = est2_ses.get("/anteproyecto_ver.jsp?id=" + ant_b_id)
        check("Rechazado" in html, "el estudiante no ve el estado rechazado")
        check("bibliografia" in html.lower(),
              "el estudiante no ve las observaciones del rechazo")
        check("Completar y enviar" in html,
              "el estudiante no ve la opcion de corregir y reenviar el anteproyecto")
        _, _, html_form = est2_ses.get("/anteproyecto_form.jsp?id=" + ant_b_id)
        check("Tu anteproyecto fue rechazado" in html_form,
              "el estudiante no ve el aviso de anteproyecto rechazado")
        return "el estudiante ve el estado, las observaciones y puede corregir y reenviar"

    case("E-07 Anteproyecto: el estudiante ve el rechazo y puede corregirlo", e07)

    # ---------------------------------------------------------------
    # F. Coordinacion: busqueda y ficha - RF-27, RF-28
    # ---------------------------------------------------------------
    print("\n--- BLOQUE F: coordinacion (busqueda y ficha) -------------------")

    coord_ses, _, _, _ = login("e2e-coordinacion@uts.edu.co", "e2ecoordinacion2026")

    def f01():
        _, _, html = coord_ses.get("/coordinacion.jsp?q=" + urllib.parse.quote("Estudiante E2E"))
        filas = table_rows(html)
        codigos = [f[1] for f in filas if len(f) > 1]
        check("900001" in codigos, "la busqueda por nombre no devolvio el codigo 900001: %s" % codigos)
        return "la busqueda por nombre devolvio %d estudiantes (incluye el codigo 900001)" % len(filas)

    case("F-01 Coordinacion: busqueda de estudiante por nombre", f01)

    def f02():
        _, _, html = coord_ses.get("/coordinacion.jsp?q=900002")
        filas = table_rows(html)
        check(len(filas) == 1, "la busqueda por codigo devolvio %d filas" % len(filas))
        check(filas[0][0] == "Estudiante E2E Dos Editado",
              "la fila devuelta no es la esperada: %s" % filas[0])
        return "la busqueda por codigo devolvio exactamente 1 fila: %s" % (filas[0][:2],)

    case("F-02 Coordinacion: busqueda de estudiante por codigo", f02)

    def f03():
        _, _, html = coord_ses.get("/coordinacion.jsp?q=" +
                                   urllib.parse.quote("e2e-estudiante4@uts.edu.co"))
        filas = table_rows(html)
        check(len(filas) == 1, "la busqueda por correo devolvio %d filas" % len(filas))
        check("900004" in filas[0][1], "la fila devuelta no corresponde al correo buscado")
        return "la busqueda por correo devolvio exactamente 1 fila (codigo 900004)"

    case("F-03 Coordinacion: busqueda de estudiante por correo", f03)

    def f04():
        _, _, html = coord_ses.get("/coordinacion.jsp?q=NoExisteEsteEstudiante999")
        check("No se encontraron estudiantes" in html, "no se mostro el aviso de sin resultados")
        check(len(table_rows(html)) == 0, "la busqueda sin coincidencias devolvio filas")
        return "la busqueda sin coincidencias muestra 'No se encontraron estudiantes con ese dato'"

    case("F-04 Coordinacion: la busqueda sin coincidencias informa que no hay resultados", f04)

    def f05():
        _, _, html = coord_ses.get("/coordinacion.jsp?accion=ficha&id=" + est_id)
        check("900001" in html, "la ficha no muestra el codigo del estudiante")
        check("Director E2E Uno" in html, "la ficha no muestra el nombre del director")
        check("E2E Anteproyecto" in html, "la ficha no muestra el titulo del anteproyecto")
        check("Por asignar" in html or "Evaluador E2E" in html,
              "la ficha no muestra el evaluador")
        return "la ficha muestra codigo 900001, anteproyecto, director y evaluador"

    case("F-05 Coordinacion: la ficha muestra los datos del proyecto y del equipo evaluador", f05)

    # ---------------------------------------------------------------
    # G. Coordinacion: asignacion de director y evaluador - RF-26
    # ---------------------------------------------------------------
    print("\n--- BLOQUE G: coordinacion (asignacion) --------------------------")

    def g01():
        # El evaluador solo puede asignarse cuando el director ya aprobo (RF-26).
        _, _, html = coord_ses.get("/coordinacion.jsp?accion=ficha&id=" + est_id)
        token = coord_ses.csrf(html)
        _, final, _ = coord_ses.post("/coordinacion.jsp", {
            "csrf_token": token, "accion": "asignar", "anteproyecto_id": ant_a_id,
            "estudiante_id": est_id, "director": dir_id, "evaluador": eval_id})
        evaluador = db("SELECT evaluador_id FROM anteproyectos WHERE id=%s;" % ant_a_id)
        check(evaluador == eval_id, "el evaluador no quedo asignado: " + repr(evaluador))
        check("exito=asignado" in final, "no se mostro la confirmacion: " + final)
        return "evaluador asignado (id=%s) sobre un anteproyecto aprobado por el director" % evaluador

    case("G-01 Coordinacion: asigna el evaluador de un anteproyecto aprobado", g01)

    def g02():
        # Segundo anteproyecto para las pruebas de reasignacion.
        est4_ses, _, _, _ = login("e2e-estudiante4@uts.edu.co", "e2eestudiante2026")
        idea_d = crear_idea_para("idea del flujo D")
        seleccionar(est4_ses, idea_d)
        ant_d = db("SELECT id FROM anteproyectos WHERE estudiante_id=%s;" % est4_id)
        check(ant_d != "", "no se creo el anteproyecto de apoyo")
        _, _, html = est4_ses.get("/anteproyecto_form.jsp?id=" + ant_d)
        token = est4_ses.csrf(html)
        est4_ses.post("/anteproyecto_form.jsp?id=" + ant_d, {
            "csrf_token": token, "titulo": "E2E Anteproyecto D " + RUN,
            "director": dir_id, "documento": "https://drive.google.com/e2e/d.pdf"})
        dr, _, _, _ = login("e2e-director1@uts.edu.co", "e2edirector2026")
        _, _, html = dr.get("/anteproyecto_ver.jsp?id=" + ant_d)
        token = dr.csrf(html)
        dr.post("/anteproyecto_ver.jsp?id=" + ant_d, {
            "csrf_token": token, "accion": "calificar", "calificacion": "4.0",
            "observacion": "ok"})
        _, _, html = dr.get("/anteproyecto_ver.jsp?id=" + ant_d)
        token = dr.csrf(html)
        dr.post("/anteproyecto_ver.jsp?id=" + ant_d, {"csrf_token": token, "accion": "aprobar"})
        estado = db("SELECT estado FROM anteproyectos WHERE id=%s;" % ant_d)
        check(estado == "APROBADO_DIRECTOR", "el anteproyecto D no quedo aprobado: " + repr(estado))
        return "anteproyecto id=%s aprobado por el director" % ant_d

    case("G-02 Coordinacion: anteproyecto de apoyo para las pruebas de asignacion", g02)

    ant_d_id = db("SELECT id FROM anteproyectos WHERE estudiante_id=%s;" % est4_id)

    def g03():
        _, _, html = coord_ses.get("/coordinacion.jsp?accion=ficha&id=" + est4_id)
        token = coord_ses.csrf(html)
        _, final, _ = coord_ses.post("/coordinacion.jsp", {
            "csrf_token": token, "accion": "asignar", "anteproyecto_id": ant_d_id,
            "estudiante_id": est4_id, "director": dir2_id, "evaluador": ""})
        director = db("SELECT director_id FROM anteproyectos WHERE id=%s;" % ant_d_id)
        check(director == dir2_id, "el director no fue reasignado: " + repr(director))
        check("exito=asignado" in final, "no se mostro la confirmacion: " + final)
        return "el director fue cambiado a id=%s sobre el anteproyecto ya aprobado" % director

    case("G-03 Coordinacion: agrega/cambia el director de un anteproyecto aprobado", g03)

    def g04():
        _, _, html = coord_ses.get("/coordinacion.jsp?accion=ficha&id=" + est2_id)
        token = coord_ses.csrf(html)
        _, final, _ = coord_ses.post("/coordinacion.jsp", {
            "csrf_token": token, "accion": "asignar", "anteproyecto_id": ant_b_id,
            "estudiante_id": est2_id, "director": dir_id, "evaluador": eval_id})
        check("error=evaluador_fuera_flujo" in final,
              "no se aviso que el evaluador se asigna tras la aprobacion del director: " + final)
        evaluador = db("SELECT evaluador_id FROM anteproyectos WHERE id=%s;" % ant_b_id)
        check(evaluador == "NULL", "se asigno el evaluador fuera de flujo: " + repr(evaluador))
        return "la asignacion del evaluador fue rechazada por estar fuera del flujo"

    case("G-04 Coordinacion: el evaluador solo se asigna tras la aprobacion del director", g04)

    def g05():
        _, _, html = coord_ses.get("/coordinacion.jsp?accion=ficha&id=" + est4_id)
        token = coord_ses.csrf(html)
        _, final, _ = coord_ses.post("/coordinacion.jsp", {
            "csrf_token": token, "accion": "asignar", "anteproyecto_id": ant_d_id,
            "estudiante_id": est4_id, "director": coord_id, "evaluador": ""})
        check("error=director_invalido" in final,
              "no se aviso que el usuario no es un Director valido: " + final)
        director = db("SELECT director_id FROM anteproyectos WHERE id=%s;" % ant_d_id)
        check(director == dir2_id, "se asigno un director invalido: " + repr(director))
        return "se rechazo asignar como director a un usuario que no tiene ese rol"

    case("G-05 Coordinacion: se valida que el director asignado tenga rol DIRECTOR", g05)

    # ---------------------------------------------------------------
    # H. Evaluacion del anteproyecto - RF-22 a RF-24, RF-35
    # ---------------------------------------------------------------
    print("\n--- BLOQUE H: evaluacion del anteproyecto -----------------------")

    def h01():
        ev, _, _, _ = login("e2e-evaluador@uts.edu.co", "e2eevaluador2026")
        _, _, html = ev.get("/anteproyecto_ver.jsp?id=" + ant_a_id)
        token = ev.csrf(html)
        ev.post("/anteproyecto_ver.jsp?id=" + ant_a_id, {
            "csrf_token": token, "accion": "calificar_eval", "calificacion": "4.2",
            "observacion": "revision del evaluador"})
        cal = db("SELECT calificacion_evaluador FROM anteproyectos WHERE id=%s;" % ant_a_id)
        hist = db("SELECT COUNT(*) FROM calificaciones WHERE anteproyecto_id=%s "
                  "AND rol_calificador='EVALUADOR';" % ant_a_id)
        check(cal == "4.2", "la calificacion del evaluador no se guardo: " + repr(cal))
        check(hist == "1", "no se registro el historial del evaluador: " + repr(hist))
        return "calificacion_evaluador=%s con 1 registro en el historial" % cal

    case("H-01 Evaluador: califica el anteproyecto", h01)

    def h02():
        ev, _, _, _ = login("e2e-evaluador@uts.edu.co", "e2eevaluador2026")
        _, _, html = ev.get("/anteproyecto_ver.jsp?id=" + ant_a_id)
        token = ev.csrf(html)
        ev.post("/anteproyecto_ver.jsp?id=" + ant_a_id,
                {"csrf_token": token, "accion": "eliminar_calificacion"})
        cal = db("SELECT calificacion_evaluador FROM anteproyectos WHERE id=%s;" % ant_a_id)
        hist = db("SELECT COUNT(*) FROM calificaciones WHERE anteproyecto_id=%s "
                  "AND rol_calificador='EVALUADOR';" % ant_a_id)
        check(cal == "NULL", "la calificacion del evaluador no se borro: " + repr(cal))
        check(hist == "0", "el historial del evaluador no se borro: " + repr(hist))
        return "la calificacion y el historial del evaluador quedaron en NULL / 0 filas"

    case("H-02 Evaluador: elimina su calificacion", h02)

    def h03():
        ev, _, _, _ = login("e2e-evaluador@uts.edu.co", "e2eevaluador2026")
        _, _, html = ev.get("/anteproyecto_ver.jsp?id=" + ant_a_id)
        token = ev.csrf(html)
        _, final, _ = ev.post("/anteproyecto_ver.jsp?id=" + ant_a_id,
                               {"csrf_token": token, "accion": "evaluar"})
        check("error=evalnocalifica" in final, "no se aviso que falta calificar: " + final)
        estado = db("SELECT estado FROM anteproyectos WHERE id=%s;" % ant_a_id)
        check(estado == "APROBADO_DIRECTOR", "el anteproyecto avanzo sin calificacion: " + repr(estado))
        return "la aprobacion del evaluador se bloqueo (error=evalnocalifica)"

    case("H-03 Evaluador: no se puede aprobar sin calificar antes", h03)

    def h04():
        ev, _, _, _ = login("e2e-evaluador@uts.edu.co", "e2eevaluador2026")
        _, _, html = ev.get("/anteproyecto_ver.jsp?id=" + ant_a_id)
        token = ev.csrf(html)
        ev.post("/anteproyecto_ver.jsp?id=" + ant_a_id, {
            "csrf_token": token, "accion": "calificar_eval", "calificacion": "4.5",
            "observacion": "aprobado"})
        _, _, html = ev.get("/anteproyecto_ver.jsp?id=" + ant_a_id)
        token = ev.csrf(html)
        _, final, _ = ev.post("/anteproyecto_ver.jsp?id=" + ant_a_id,
                               {"csrf_token": token, "accion": "evaluar"})
        estado = db("SELECT estado FROM anteproyectos WHERE id=%s;" % ant_a_id)
        notif = db("SELECT COUNT(*) FROM notificaciones WHERE usuario_id=%s "
                   "AND evento='ANTEPROYECTO_APROBADO_EVALUADOR';" % est_id)
        check(estado == "APROBADO_EVALUADOR", "el estado no avanzo: " + repr(estado))
        check(notif != "0", "no se notifico al estudiante")
        return "estado=%s y el estudiante recibio la notificacion (%s aviso)" % (estado, notif)

    case("H-04 Evaluador: aprueba el anteproyecto y el estudiante es notificado", h04)

    # ---------------------------------------------------------------
    # I. Informes de estado - RF-29, RF-30, RF-31
    # ---------------------------------------------------------------
    print("\n--- BLOQUE I: informes de estado -------------------------------")

    def i01():
        _, _, html = coord_ses.get("/informes.jsp?tipo=estudiantes")
        enc = th_flat(html)
        esperado = ["Estudiante", "Código", "Anteproyecto", "Director", "Evaluador",
                    "Estado", "Calif. dir.", "Calif. eval."]
        check(enc == esperado, "las columnas del informe por estudiante no coinciden: %s" % enc)
        return "columnas verificadas: %s" % " | ".join(enc)

    case("I-01 Informes: el informe por estudiante tiene las columnas esperadas", i01)

    def i02():
        _, _, html = coord_ses.get("/informes.jsp?tipo=directores")
        enc = th_flat(html)
        esperado = ["Director", "Total", "Pendientes (en revisión)", "En evaluación",
                    "Aprobados", "Rechazados", "Entrega final", "Revisión final",
                    "Sustentación", "Finalizados"]
        check(enc == esperado, "las columnas del informe por director no coinciden: %s" % enc)
        return "columnas verificadas: %s" % " | ".join(enc)

    case("I-02 Informes: el informe por director tiene las columnas esperadas", i02)

    def i03():
        _, _, html = coord_ses.get("/informes.jsp?tipo=evaluadores")
        enc = th_flat(html)
        esperado = ["Evaluador", "Total asignados", "Pendientes por aprobar", "Aprobados",
                    "Rechazados", "Entrega final", "Revisión final", "Sustentación",
                    "Finalizados"]
        check(enc == esperado, "las columnas del informe por evaluador no coinciden: %s" % enc)
        return "columnas verificadas: %s" % " | ".join(enc)

    case("I-03 Informes: el informe por evaluador tiene las columnas esperadas", i03)

    def i04():
        _, _, html = coord_ses.get("/informes.jsp?tipo=estudiantes")
        filas = table_rows(html)
        fila = [f for f in filas if len(f) > 2 and "900001" in f[1]]
        check(fila, "el estudiante de prueba no aparece en el informe por estudiante")
        f = fila[0]
        check("E2E Anteproyecto " + RUN in f[2], "el titulo del anteproyecto no coincide: %s" % f[2])
        check("Director E2E Uno" in f[3], "el director no aparece en el informe: %s" % f[3])
        check("Evaluador E2E" in f[4], "el evaluador no aparece en el informe: %s" % f[4])
        check("4" in f[6], "la calificacion del director no aparece: %s" % f[6])
        check("4.5" in f[7], "la calificacion del evaluador no aparece: %s" % f[7])
        return "el informe muestra el anteproyecto %s con director, evaluador y notas" % f[2]

    case("I-04 Informes: el informe refleja el estado real del proyecto", i04)

    # ---------------------------------------------------------------
    # J. Entrega del documento final y sustentacion - RF-25 a RF-36
    # ---------------------------------------------------------------
    print("\n--- BLOQUE J: entrega final, revision y sustentacion ------------")

    def j01():
        # La URL del documento final se valida antes de registrar la entrega.
        est_ses, _, _, _ = login("e2e-estudiante1@uts.edu.co", "e2eestudiante2026")
        _, _, html = est_ses.get("/entrega_final.jsp?id=" + ant_a_id)
        token = est_ses.csrf(html)
        _, _, body = est_ses.post("/entrega_final.jsp?id=" + ant_a_id, {
            "csrf_token": token, "accion": "crear", "titulo": "E2E Segundo documento " + RUN,
            "documento": "ftp://servidor/otro.pdf"})
        check("debe comenzar por http:// o https://" in body,
              "no se aviso que la URL es invalida: %s" % body[:200])
        check(db("SELECT COUNT(*) FROM entrega_final WHERE anteproyecto_id=%s;" % ant_a_id) == "0",
              "se registro una entrega con una URL invalida")
        return "se rechazo una URL de documento final que no es http/https"

    case("J-01 Entrega final: se valida la URL del documento final", j01)

    def j02():
        est_ses, _, _, _ = login("e2e-estudiante1@uts.edu.co", "e2eestudiante2026")
        _, _, html = est_ses.get("/anteproyecto_ver.jsp?id=" + ant_a_id)
        check("entrega_final.jsp?id=" + ant_a_id in html,
              "el estudiante no ve el enlace de entrega del documento final")
        _, _, html = est_ses.get("/entrega_final.jsp?id=" + ant_a_id)
        token = est_ses.csrf(html)
        _, final, _ = est_ses.post("/entrega_final.jsp?id=" + ant_a_id, {
            "csrf_token": token, "accion": "crear", "titulo": "E2E Documento Final " + RUN,
            "documento": "https://drive.google.com/e2e/documento-final.pdf"})
        estado = db("SELECT estado FROM anteproyectos WHERE id=%s;" % ant_a_id)
        entrega = db("SELECT estado FROM entrega_final WHERE anteproyecto_id=%s;" % ant_a_id)
        check(estado == "ENTREGA_DOCUMENTO_FINAL", "el anteproyecto no avanzo: " + repr(estado))
        check(entrega == "ENTREGADO", "la entrega no quedo ENTREGADA: " + repr(entrega))
        return "anteproyecto=%s, entrega=%s" % (estado, entrega)

    case("J-02 Entrega final: el estudiante entrega el documento final", j02)

    def j03():
        # El estudiante conserva el acceso a su entrega y al enlace del documento.
        est_ses, _, _, _ = login("e2e-estudiante1@uts.edu.co", "e2eestudiante2026")
        _, _, html = est_ses.get("/anteproyecto_ver.jsp?id=" + ant_a_id)
        check("entrega_final.jsp?id=" + ant_a_id in html,
              "el estudiante perdio el enlace a su entrega")
        _, _, html = est_ses.get("/entrega_final.jsp?id=" + ant_a_id)
        check("Documento entregado" in html, "el estudiante no ve su entrega registrada")
        check("documento-final.pdf" in html, "el estudiante no ve el enlace del documento")
        return "el estudiante sigue viendo su entrega y el enlace permanece activo"

    case("J-03 Entrega final: el estudiante conserva el acceso a su entrega", j03)

    def j04():
        est_ses, _, _, _ = login("e2e-estudiante1@uts.edu.co", "e2eestudiante2026")
        _, _, html = est_ses.get("/entrega_final.jsp?id=" + ant_a_id)
        token = est_ses.csrf(html)
        _, _, body = est_ses.post("/entrega_final.jsp?id=" + ant_a_id, {
            "csrf_token": token, "accion": "crear", "titulo": "E2E Duplicada " + RUN,
            "documento": "https://drive.google.com/e2e/duplicado.pdf"})
        check("no est" in body and "permitida" in body,
              "no se aviso que la entrega no esta permitida: %s" % body[:200])
        check(db("SELECT COUNT(*) FROM entrega_final WHERE anteproyecto_id=%s;" % ant_a_id) == "1",
              "se registro una segunda entrega")
        return "la segunda entrega del mismo anteproyecto fue rechazada"

    case("J-04 Entrega final: no se puede entregar el documento dos veces", j04)

    def j05():
        _, _, html = coord_ses.get("/entrega_final.jsp?id=" + ant_a_id)
        token = coord_ses.csrf(html)
        entrega_id = db("SELECT id FROM entrega_final WHERE anteproyecto_id=%s;" % ant_a_id)
        _, final, _ = coord_ses.post("/entrega_final.jsp?id=" + ant_a_id, {
            "csrf_token": token, "accion": "revisar", "entrega_id": entrega_id,
            "estado_nuevo": "OBSERVADO", "observaciones": "faltan los anexos"})
        estado = db("SELECT estado FROM entrega_final WHERE anteproyecto_id=%s;" % ant_a_id)
        obs = db("SELECT observaciones FROM entrega_final WHERE anteproyecto_id=%s;" % ant_a_id)
        rev = db("SELECT revisado_por FROM entrega_final WHERE anteproyecto_id=%s;" % ant_a_id)
        check(estado == "OBSERVADO", "la entrega no quedo OBSERVADA: " + repr(estado))
        check("anexos" in obs, "no se guardaron las observaciones")
        check(rev == coord_id, "no se registro quien reviso: " + repr(rev))
        return "entrega=%s, revisado_por=%s, observaciones guardadas" % (estado, rev)

    case("J-05 Entrega final: el revisor marca la entrega como OBSERVADA", j05)

    def j06():
        est_ses, _, _, _ = login("e2e-estudiante1@uts.edu.co", "e2eestudiante2026")
        _, _, html = est_ses.get("/entrega_final.jsp?id=" + ant_a_id)
        check("Corregir y reenviar documento" in html,
              "el estudiante no ve el formulario de correccion")
        token = est_ses.csrf(html)
        _, final, _ = est_ses.post("/entrega_final.jsp?id=" + ant_a_id, {
            "csrf_token": token, "accion": "corregir", "titulo": "E2E Documento Final " + RUN,
            "documento": "https://drive.google.com/e2e/documento-final-v2.pdf"})
        estado = db("SELECT estado FROM entrega_final WHERE anteproyecto_id=%s;" % ant_a_id)
        doc = db("SELECT documento FROM entrega_final WHERE anteproyecto_id=%s;" % ant_a_id)
        check(estado == "ENTREGADO", "la correccion no quedo ENTREGADA: " + repr(estado))
        check("v2" in doc, "no se guardo el nuevo enlace: " + repr(doc))
        return "la correccion quedo ENTREGADA con el nuevo enlace del documento"

    case("J-06 Entrega final: el estudiante ve la correccion y la reenvia", j06)

    def j07():
        _, _, html = coord_ses.get("/entrega_final.jsp?id=" + ant_a_id)
        token = coord_ses.csrf(html)
        entrega_id = db("SELECT id FROM entrega_final WHERE anteproyecto_id=%s;" % ant_a_id)
        _, final, _ = coord_ses.post("/entrega_final.jsp?id=" + ant_a_id, {
            "csrf_token": token, "accion": "revisar", "entrega_id": entrega_id,
            "estado_nuevo": "APROBADO", "observaciones": "documento completo"})
        estado = db("SELECT estado FROM anteproyectos WHERE id=%s;" % ant_a_id)
        entrega = db("SELECT estado FROM entrega_final WHERE anteproyecto_id=%s;" % ant_a_id)
        check(estado == "REVISIÓN_FINAL", "el anteproyecto no paso a Revision Final: " + repr(estado))
        check(entrega == "APROBADO", "la entrega no quedo APROBADA: " + repr(entrega))
        return "anteproyecto=%s, entrega=%s" % (estado, entrega)

    case("J-07 Entrega final: al aprobar el documento el trabajo pasa a Revision Final", j07)

    def j08():
        # Correccion verificada: observar desde Revision Final devuelve el
        # trabajo a "Entrega Documento Final" para que el estudiante pueda
        # corregir; antes el trabajo quedaba bloqueado en Revision Final.
        _, _, html = coord_ses.get("/entrega_final.jsp?id=" + ant_a_id)
        token = coord_ses.csrf(html)
        entrega_id = db("SELECT id FROM entrega_final WHERE anteproyecto_id=%s;" % ant_a_id)
        _, final, _ = coord_ses.post("/entrega_final.jsp?id=" + ant_a_id, {
            "csrf_token": token, "accion": "revisar", "entrega_id": entrega_id,
            "estado_nuevo": "OBSERVADO", "observaciones": "ajuste de figuras"})
        estado = db("SELECT estado FROM anteproyectos WHERE id=%s;" % ant_a_id)
        entrega = db("SELECT estado FROM entrega_final WHERE anteproyecto_id=%s;" % ant_a_id)
        check(estado == "ENTREGA_DOCUMENTO_FINAL",
              "el trabajo quedo bloqueado en %s y el estudiante no podria corregir" % repr(estado))
        check(entrega == "OBSERVADO", "la entrega no quedo OBSERVADA: " + repr(entrega))
        est_ses, _, _, _ = login("e2e-estudiante1@uts.edu.co", "e2eestudiante2026")
        _, _, html_est = est_ses.get("/entrega_final.jsp?id=" + ant_a_id)
        check("Corregir y reenviar documento" in html_est,
              "el estudiante sigue sin ver el formulario de correccion")
        return "el trabajo volvio a ENTREGA_DOCUMENTO_FINAL y el estudiante ve la correccion"

    case("J-08 Correccion: observar desde Revision Final devuelve el trabajo a correccion", j08)

    def j09():
        est_ses, _, _, _ = login("e2e-estudiante1@uts.edu.co", "e2eestudiante2026")
        _, _, html = est_ses.get("/entrega_final.jsp?id=" + ant_a_id)
        token = est_ses.csrf(html)
        _, final, _ = est_ses.post("/entrega_final.jsp?id=" + ant_a_id, {
            "csrf_token": token, "accion": "corregir", "titulo": "E2E Documento Final " + RUN,
            "documento": "https://drive.google.com/e2e/documento-final-v3.pdf"})
        entrega = db("SELECT estado FROM entrega_final WHERE anteproyecto_id=%s;" % ant_a_id)
        estado = db("SELECT estado FROM anteproyectos WHERE id=%s;" % ant_a_id)
        check(entrega == "ENTREGADO", "la correccion no quedo ENTREGADA: " + repr(entrega))
        check(estado == "ENTREGA_DOCUMENTO_FINAL", "el estado del anteproyecto cambio: " + repr(estado))
        return "la correccion quedo ENTREGADA y el anteproyecto en ENTREGA_DOCUMENTO_FINAL"

    case("J-09 Entrega final: el estudiante reenvia la correccion y el trabajo vuelve a revision", j09)

    def j10():
        _, _, html = coord_ses.get("/entrega_final.jsp?id=" + ant_a_id)
        token = coord_ses.csrf(html)
        entrega_id = db("SELECT id FROM entrega_final WHERE anteproyecto_id=%s;" % ant_a_id)
        _, final, _ = coord_ses.post("/entrega_final.jsp?id=" + ant_a_id, {
            "csrf_token": token, "accion": "revisar", "entrega_id": entrega_id,
            "estado_nuevo": "APROBADO", "observaciones": "documento definitivo"})
        estado = db("SELECT estado FROM anteproyectos WHERE id=%s;" % ant_a_id)
        check(estado == "REVISIÓN_FINAL", "el anteproyecto no quedo en Revision Final: " + repr(estado))
        return "el documento quedo aprobado y el trabajo paso a REVISIÓN_FINAL"

    case("J-10 Entrega final: segunda aprobacion del documento corregido", j10)

    def j11():
        _, _, html = coord_ses.get("/sustentacion.jsp?id=" + ant_a_id)
        token = coord_ses.csrf(html)
        _, final, _ = coord_ses.post("/sustentacion.jsp?id=" + ant_a_id, {
            "csrf_token": token, "accion": "programar", "fecha": "2026-12-05",
            "hora": "10:00", "lugar": "Auditorio Principal"})
        estado = db("SELECT estado FROM anteproyectos WHERE id=%s;" % ant_a_id)
        lugar = db("SELECT lugar FROM sustentacion WHERE anteproyecto_id=%s;" % ant_a_id)
        check(estado == "SUSTENTACIÓN", "el trabajo no paso a Sustentacion: " + repr(estado))
        check(lugar == "Auditorio Principal", "no se guardo el lugar: " + repr(lugar))
        return "sustentacion programada en %s; el estado paso a SUSTENTACIÓN" % lugar

    case("J-11 Sustentacion: la coordinacion programa el acto de sustentacion", j11)

    def j12():
        _, _, html = coord_ses.get("/entrega_final.jsp?id=" + ant_a_id)
        token = coord_ses.csrf(html)
        entrega_id = db("SELECT id FROM entrega_final WHERE anteproyecto_id=%s;" % ant_a_id)
        _, _, body = coord_ses.post("/entrega_final.jsp?id=" + ant_a_id, {
            "csrf_token": token, "accion": "revisar", "entrega_id": entrega_id,
            "estado_nuevo": "OBSERVADO", "observaciones": "no deberia aplicar"})
        check("solo está disponible en los estados" in body,
              "no se mostro el aviso de revision bloqueada: %s" % body[:300])
        estado_ent = db("SELECT estado FROM entrega_final WHERE anteproyecto_id=%s;" % ant_a_id)
        check(estado_ent == "APROBADO", "la entrega cambio de estado: " + repr(estado_ent))
        return "la revision fue bloqueada en el estado SUSTENTACIÓN (entrega sigue APROBADO)"

    case("J-12 Correccion: la revision se bloquea cuando el documento ya esta cerrado", j12)

    def j13():
        _, _, html = coord_ses.get("/entrega_final.jsp?id=" + ant_a_id)
        check("Guardar revisión" not in html, "el formulario de revision sigue visible")
        check("El documento final ya está cerrado" in html,
              "no se mostro el aviso de documento cerrado")
        return "el formulario de revision se oculta y se informa que el documento esta cerrado"

    case("J-13 Correccion: el formulario de revision se oculta en estados cerrados", j13)

    def j14():
        dr, _, _, _ = login("e2e-director1@uts.edu.co", "e2edirector2026")
        _, _, html = dr.get("/sustentacion.jsp?id=" + ant_a_id)
        token = dr.csrf(html)
        sust_id = db("SELECT id FROM sustentacion WHERE anteproyecto_id=%s;" % ant_a_id)
        _, final, _ = dr.post("/sustentacion.jsp?id=" + ant_a_id, {
            "csrf_token": token, "accion": "resultado", "sust_id": sust_id,
            "resultado": "APROBADO", "observaciones": "sustentacion aprobada"})
        estado = db("SELECT estado FROM anteproyectos WHERE id=%s;" % ant_a_id)
        resultado = db("SELECT resultado FROM sustentacion WHERE anteproyecto_id=%s;" % ant_a_id)
        check(estado == "FINALIZADO", "el trabajo no quedo FINALIZADO: " + repr(estado))
        check(resultado == "APROBADO", "el resultado no se registro: " + repr(resultado))
        return "estado=%s, resultado de la sustentacion=%s" % (estado, resultado)

    case("J-14 Sustentacion: el director registra el resultado y el trabajo se finaliza", j14)

    def j15():
        est_ses, _, _, _ = login("e2e-estudiante1@uts.edu.co", "e2eestudiante2026")
        _, _, html = est_ses.get("/sustentacion.jsp?id=" + ant_a_id)
        check("Auditorio Principal" in html, "el estudiante no ve el lugar de la sustentacion")
        check("APROBADO" in html, "el estudiante no ve el resultado de la sustentacion")
        _, _, html_v = est_ses.get("/anteproyecto_ver.jsp?id=" + ant_a_id)
        check("¡Proceso completado!" in html_v or "finalizado" in html_v.lower(),
              "el estudiante no ve el cierre del proceso")
        return "el estudiante consulta la fecha, el lugar y el resultado de su sustentacion"

    case("J-15 Sustentacion: el estudiante consulta el resultado de su sustentacion", j15)

    def j16():
        _, _, html = coord_ses.get("/entrega_final.jsp?id=" + ant_a_id)
        token = coord_ses.csrf(html)
        entrega_id = db("SELECT id FROM entrega_final WHERE anteproyecto_id=%s;" % ant_a_id)
        _, _, body = coord_ses.post("/entrega_final.jsp?id=" + ant_a_id, {
            "csrf_token": token, "accion": "revisar", "entrega_id": entrega_id,
            "estado_nuevo": "OBSERVADO", "observaciones": "tarde demais"})
        check("solo está disponible en los estados" in body,
              "no se mostro el aviso de revision bloqueada: %s" % body[:300])
        estado_ent = db("SELECT estado FROM entrega_final WHERE anteproyecto_id=%s;" % ant_a_id)
        check(estado_ent == "APROBADO", "la entrega cambio de estado: " + repr(estado_ent))
        return "la revision quedo bloqueada en el estado FINALIZADO (entrega sigue APROBADO)"

    case("J-16 Correccion: la revision se bloquea en el estado FINALIZADO", j16)

    def j17():
        # La calificacion del evaluador se conserva y es consultable por el estudiante.
        est_ses, _, _, _ = login("e2e-estudiante1@uts.edu.co", "e2eestudiante2026")
        _, _, html = est_ses.get("/anteproyecto_ver.jsp?id=" + ant_a_id)
        check("4" in html and "/ 5" in html, "el estudiante no ve las calificaciones")
        check("Calificaciones" in html, "el estudiante no ve el bloque de calificaciones")
        return "el estudiante consulta las calificaciones del director y del evaluador"

    case("J-17 Consulta: el estudiante ve las calificaciones de su anteproyecto", j17)

    # ---------------------------------------------------------------
    # K. Calendario academico (CRUD) - RF-32
    # ---------------------------------------------------------------
    print("\n--- BLOQUE K: calendario academico (CRUD) -----------------------")

    def k01():
        _, _, html = coord_ses.get("/calendario.jsp")
        token = coord_ses.csrf(html)
        _, final, _ = coord_ses.post("/calendario.jsp", {
            "csrf_token": token, "accion": "crear", "titulo": "E2E evento " + RUN,
            "descripcion": "evento de prueba", "fecha_inicio": "2026-11-01",
            "fecha_fin": "2026-11-05", "tipo": "HITO"})
        ev_id = db("SELECT id FROM calendario WHERE titulo='E2E evento %s';" % RUN)
        check(ev_id != "", "el evento no se registro")
        check("exito=creado" in final, "no se mostro la confirmacion: " + final)
        return "evento creado con id=%s (01/11/2026 al 05/11/2026, tipo Hito)" % ev_id

    case("K-01 Calendario: se registra un evento", k01)

    def k02():
        ev_id = db("SELECT id FROM calendario WHERE titulo='E2E evento %s';" % RUN)
        _, _, html = coord_ses.get("/calendario.jsp?accion=editar&id=" + ev_id)
        check("E2E evento " + RUN in html, "el formulario de edicion no se prelleno")
        check('value="2026-11-01"' in html, "la fecha de inicio no se prelleno")
        token = coord_ses.csrf(html)
        _, final, _ = coord_ses.post("/calendario.jsp", {
            "csrf_token": token, "accion": "editar", "id": ev_id,
            "titulo": "E2E evento editado " + RUN, "descripcion": "editado",
            "fecha_inicio": "2026-11-02", "fecha_fin": "2026-11-06", "tipo": "ENTREGA"})
        titulo = db("SELECT titulo FROM calendario WHERE id=%s;" % ev_id)
        tipo = db("SELECT tipo FROM calendario WHERE id=%s;" % ev_id)
        check("editado" in titulo, "el titulo no se actualizo: " + repr(titulo))
        check(tipo == "ENTREGA", "el tipo no se actualizo: " + repr(tipo))
        return "el evento quedo con titulo '%s' y tipo %s" % (titulo, tipo)

    case("K-02 Calendario: se edita un evento existente", k02)

    def k03():
        ev_id = db("SELECT id FROM calendario WHERE titulo LIKE 'E2E evento editado %s';" % RUN)
        _, _, html = coord_ses.get("/calendario.jsp")
        token = coord_ses.csrf(html)
        _, final, _ = coord_ses.post("/calendario.jsp", {
            "csrf_token": token, "accion": "eliminar", "id": ev_id})
        check(db("SELECT COUNT(*) FROM calendario WHERE id=%s;" % ev_id) == "0",
              "el evento no se elimino")
        check("exito=eliminado" in final, "no se mostro la confirmacion: " + final)
        return "el evento se elimino del calendario"

    case("K-03 Calendario: se elimina un evento", k03)

    def k04():
        est_ses, _, _, _ = login("e2e-estudiante1@uts.edu.co", "e2eestudiante2026")
        _, _, html = est_ses.get("/calendario.jsp")
        token = est_ses.csrf(html)
        _, final, _ = est_ses.post("/calendario.jsp", {
            "csrf_token": token, "accion": "crear", "titulo": "E2E evento no autorizado " + RUN,
            "descripcion": "no debe crearse", "fecha_inicio": "2026-11-10", "tipo": "HITO"})
        check(es_403(final), "el estudiante pudo crear un evento: " + final)
        check(db("SELECT COUNT(*) FROM calendario WHERE titulo LIKE 'E2E evento no autorizado%';") == "0",
              "el evento del estudiante se registro")
        return "redireccion a 403.jsp: el estudiante no administra el calendario"

    case("K-04 Calendario: el estudiante no puede registrar eventos", k04)

    def k05():
        est_ses, _, _, _ = login("e2e-estudiante1@uts.edu.co", "e2eestudiante2026")
        status, final, html = est_ses.get("/calendario.jsp")
        check(status == 200 and "Calendario" in html,
              "el estudiante no pudo consultar el calendario")
        enc = th_flat(html)
        check(enc[:5] == ["Fecha", "Hasta", "Tipo", "Título", "Descripción"],
              "las columnas del calendario no coinciden: %s" % enc)
        check(len(enc) == 5, "el estudiante ve la columna de acciones: %s" % enc)
        return "el estudiante consulta el calendario (%s)" % " | ".join(enc)

    case("K-05 Calendario: cualquier usuario autenticado puede consultarlo", k05)

    # ---------------------------------------------------------------
    # L. Formatos de grado (CRUD) - RF-33
    # ---------------------------------------------------------------
    print("\n--- BLOQUE L: formatos de grado (CRUD) -------------------------")

    def l01():
        _, _, html = coord_ses.get("/formatos.jsp")
        check("FDC-124-Anteproyecto.pdf" in html, "no esta el formato FDC-124")
        m = re.search(r'href="([^"]*FDC-124-Anteproyecto\.pdf)"', html)
        check(m is not None, "no se genero el enlace al PDF del formato")
        href = m.group(1)
        check(href.startswith("/tguts/formatos/"), "la ruta relativa no se resolvio: " + href)
        status, _, _ = coord_ses.get("/formatos/FDC-124-Anteproyecto.pdf")
        check(status == 200, "el PDF base no es accesible (HTTP %d)" % status)
        return "el formato con ruta local genera el enlace %s y el PDF responde HTTP 200" % href

    case("L-01 Formatos: el formato con ruta local produce un enlace relativo valido", l01)

    def l02():
        _, _, html = coord_ses.get("/formatos.jsp")
        token = coord_ses.csrf(html)
        _, final, _ = coord_ses.post("/formatos.jsp", {
            "csrf_token": token, "accion": "crear", "nombre": "E2E formato " + RUN,
            "descripcion": "formato de prueba",
            "url": "https://drive.google.com/e2e/formato.pdf"})
        fid = db("SELECT id FROM formatos WHERE nombre='E2E formato %s';" % RUN)
        check(fid != "", "el formato no se registro")
        check("exito=creado" in final, "no se mostro la confirmacion: " + final)
        return "formato creado con id=%s y enlace externo" % fid

    case("L-02 Formatos: se registra un formato con enlace externo", l02)

    def l03():
        fid = db("SELECT id FROM formatos WHERE nombre='E2E formato %s';" % RUN)
        _, _, html = coord_ses.get("/formatos.jsp")
        token = coord_ses.csrf(html)
        _, final, _ = coord_ses.post("/formatos.jsp", {
            "csrf_token": token, "accion": "editar", "id": fid,
            "nombre": "E2E formato " + RUN, "url": "https://drive.google.com/e2e/formato-v2.pdf"})
        url = db("SELECT url FROM formatos WHERE id=%s;" % fid)
        check("v2" in url, "la URL no se actualizo: " + repr(url))
        check("exito=actualizado" in final, "no se mostro la confirmacion: " + final)
        return "la URL del formato quedo actualizada a %s" % url

    case("L-03 Formatos: se actualiza el enlace del documento de un formato", l03)

    def l04():
        fid = db("SELECT id FROM formatos WHERE nombre='E2E formato %s';" % RUN)
        _, _, html = coord_ses.get("/formatos.jsp")
        token = coord_ses.csrf(html)
        _, final, _ = coord_ses.post("/formatos.jsp", {
            "csrf_token": token, "accion": "eliminar", "id": fid})
        check(db("SELECT COUNT(*) FROM formatos WHERE id=%s;" % fid) == "0",
              "el formato no se elimino")
        check("exito=eliminado" in final, "no se mostro la confirmacion: " + final)
        return "el formato se elimino del sistema"

    case("L-04 Formatos: se elimina un formato", l04)

    def l05():
        # Seguridad: el valor de la URL viene de la base de datos y se inserta
        # en el atributo href; debe aparecer escapado, nunca crudo.
        payload = 'formatos/x.pdf"><script>alert(1)</script>'
        _, _, html = coord_ses.get("/formatos.jsp")
        token = coord_ses.csrf(html)
        _, final, _ = coord_ses.post("/formatos.jsp", {
            "csrf_token": token, "accion": "crear", "nombre": "E2E formato xss " + RUN,
            "descripcion": "prueba de escape", "url": payload})
        check("exito=creado" in final, "el formato con la carga util no se registro: " + final)
        fid = db("SELECT id FROM formatos WHERE nombre='E2E formato xss %s';" % RUN)
        check(fid != "", "el formato con la carga util no quedo en la base de datos")
        _, _, html = coord_ses.get("/formatos.jsp")
        check("<script>alert(1)</script>" not in html,
              "el HTML contiene la carga util sin escapar")
        check("&quot;" in html or "%22" in html or "&#034;" in html or "&#34;" in html,
              "el HTML no contiene el caracter especial escapado")
        check("</a>" in html, "el enlace no se cerro correctamente")
        # Limpieza del formato de prueba.
        _, _, html = coord_ses.get("/formatos.jsp")
        token = coord_ses.csrf(html)
        coord_ses.post("/formatos.jsp", {"csrf_token": token, "accion": "eliminar", "id": fid})
        return "la URL con comillas y etiqueta <script> se mostro escapada, sin romper el HTML"

    case("L-05 Formatos: la URL del formato se escapa antes de Armourarse en el HTML", l05)

    def l06():
        est_ses, _, _, _ = login("e2e-estudiante1@uts.edu.co", "e2eestudiante2026")
        status, final, html = est_ses.get("/formatos.jsp")
        check(status == 200, "el estudiante no pudo consultar los formatos")
        check("FDC-124" in html and "FDC-125" in html, "no se listan los formatos base")
        check("Agregar formato" not in html, "el estudiante ve el formulario de alta de formatos")
        return "el estudiante consulta los formatos sin formulario de administracion"

    case("L-06 Formatos: el estudiante consulta los formatos sin poder administrarlos", l06)

    # ---------------------------------------------------------------
    # M. Tramites - RF-38 a RF-40
    # ---------------------------------------------------------------
    print("\n--- BLOQUE M: tramites -----------------------------------------")

    def id_tramite_de_prueba():
        """Id del tramite creado por la prueba (el '%' del LIKE se concatena
        para no confusing con el operador de formato de Python)."""
        return db("SELECT id FROM tramites WHERE estudiante_id=" + est2_id
                  + " AND tipo='PRORROGA' AND detalle LIKE '%" + RUN + "';")

    def m01():
        est_ses, _, _, _ = login("e2e-estudiante2@uts.edu.co", "e2eestudiante2026")
        _, _, html = est_ses.get("/tramites.jsp")
        token = est_ses.csrf(html)
        _, final, _ = est_ses.post("/tramites.jsp", {
            "csrf_token": token, "accion": "solicitar", "tipo": "PRORROGA",
            "detalle": "Solicitud de prorroga de prueba " + RUN})
        check("exito=solicitado" in final, "no se mostro la confirmacion: " + final)
        tid = id_tramite_de_prueba()
        estado = db("SELECT estado FROM tramites WHERE id=%s;" % tid)
        notif = db("SELECT COUNT(*) FROM notificaciones WHERE evento='TRAMITE_SOLICITADO';")
        check(tid != "", "el tramite no se registro")
        check(estado == "PENDIENTE", "el tramite no quedo PENDIENTE: " + repr(estado))
        check(notif != "0", "no se notifico a la coordinacion")
        return "tramite id=%s en estado PENDIENTE y coordinacion notificada" % tid

    case("M-01 Tramites: el estudiante solicita un tramite", m01)

    def m02():
        tid = id_tramite_de_prueba()
        _, _, html = coord_ses.get("/tramites.jsp")
        token = coord_ses.csrf(html)
        _, final, _ = coord_ses.post("/tramites.jsp", {
            "csrf_token": token, "accion": "responder", "id": tid,
            "resultado": "APROBADO", "respuesta": "Prorroga aprobada por prueba automatica"})
        check("exito=resuelto" in final, "no se mostro la confirmacion: " + final)
        estado = db("SELECT estado FROM tramites WHERE id=%s;" % tid)
        respuesta = db("SELECT respuesta FROM tramites WHERE id=%s;" % tid)
        resuelto = db("SELECT resuelto_por FROM tramites WHERE id=%s;" % tid)
        check(estado == "APROBADO", "el tramite no quedo APROBADO: " + repr(estado))
        check("aprobada" in respuesta, "no se guardo la respuesta")
        check(resuelto == coord_id, "no se registro quien resolvio: " + repr(resuelto))
        return "tramite APROBADO, resuelto por id=%s con respuesta registrada" % resuelto

    case("M-02 Tramites: la coordinacion resuelve el tramite", m02)

    def m03():
        tid = id_tramite_de_prueba()
        _, _, html = coord_ses.get("/tramites.jsp")
        token = coord_ses.csrf(html)
        _, final, _ = coord_ses.post("/tramites.jsp", {
            "csrf_token": token, "accion": "responder", "id": tid,
            "resultado": "RECHAZADO", "respuesta": "segundo intento"})
        check("error=ya_resuelto" in final, "no se aviso que ya estaba resuelto: " + final)
        estado = db("SELECT estado FROM tramites WHERE id=%s;" % tid)
        check(estado == "APROBADO", "el estado del tramite cambio: " + repr(estado))
        return "un tramite ya resuelto no se puede volver a responder"

    case("M-03 Tramites: un tramite resuelto no se puede resolver otra vez", m03)

    def m04():
        est_ses, _, _, _ = login("e2e-estudiante2@uts.edu.co", "e2eestudiante2026")
        _, _, html = est_ses.get("/tramites.jsp")
        check("Solicitud de prorroga de prueba " + RUN in html,
              "el estudiante no ve su propio tramite")
        est3_ses, _, _, _ = login("e2e-estudiante3@uts.edu.co", "e2eestudiante2026")
        _, _, html3 = est3_ses.get("/tramites.jsp")
        check("Solicitud de prorroga de prueba " + RUN not in html3,
              "un estudiante vio el tramite de otro")
        return "cada estudiante ve solo sus tramites"

    case("M-04 Tramites: el estudiante solo ve sus propias solicitudes", m04)

    # ---------------------------------------------------------------
    # N. Notificaciones - RF-37
    # ---------------------------------------------------------------
    print("\n--- BLOQUE N: notificaciones -----------------------------------")

    def n01():
        eventos = db("SELECT COUNT(DISTINCT evento) FROM notificaciones;")
        total = db("SELECT COUNT(*) FROM notificaciones;")
        check(total != "0", "no hay notificaciones registradas")
        return "%s notificaciones registradas con %s eventos distintos" % (total, eventos)

    case("N-01 Notificaciones: el sistema registra los avisos de cada evento", n01)

    def n02():
        est_ses, _, _, _ = login("e2e-estudiante1@uts.edu.co", "e2eestudiante2026")
        _, _, html = est_ses.get("/notificaciones.jsp")
        check("Revisión del documento final" in html,
              "el estudiante no ve el aviso de revision del documento final")
        check("aprobado por el evaluador" in html,
              "no aparece la notificacion de aprobacion del evaluador")
        check("Sustentación programada" in html,
              "no aparece la notificacion de la sustentacion programada")
        return "el estudiante ve en su bandeja los avisos del proceso"

    case("N-02 Notificaciones: el estudiante consulta su bandeja de avisos", n02)

    def n03():
        # La entrega del documento final notifica al director.
        n = db("SELECT COUNT(*) FROM notificaciones WHERE evento='ENTREGA_FINAL';")
        check(n != "0", "no se notifico la entrega del documento final")
        return "la entrega del documento final genero %s notificacion(es) al director" % n

    case("N-03 Notificaciones: la entrega del documento final notifica al director", n03)

    # ---------------------------------------------------------------
    # O. Limpieza final: la base de datos vuelve al estado previo
    # ---------------------------------------------------------------
    print("\n--- BLOQUE O: limpieza de los datos de prueba ------------------")

    def o01():
        ejecutar_todo(db, SQL_REINICIO)
        sobras = db("SELECT COUNT(*) FROM usuarios WHERE email LIKE 'e2e-%@uts.edu.co';")
        ideas = db("SELECT COUNT(*) FROM ideas WHERE titulo LIKE 'E2E %';")
        ants = db("SELECT COUNT(*) FROM anteproyectos WHERE titulo LIKE 'E2E %';")
        check(sobras == "0" and ideas == "0" and ants == "0",
              "quedaron datos de prueba: usuarios=%s ideas=%s anteproyectos=%s"
              % (sobras, ideas, ants))
        firma_final = fingerprint(db)
        check(firma_final == firma_inicial,
              "la base de datos quedo distinta:\n  antes : %s\n  despues: %s"
              % (firma_inicial, firma_final))
        return "la base de datos quedo exactamente como estaba (%s)" % firma_final

    case("O-01 Limpieza: la base de datos queda como estaba antes de la prueba", o01)

    # ---------------------------------------------------------------
    # Resumen
    # ---------------------------------------------------------------
    total = len(results)
    aprobados = sum(1 for _, ok, _ in results if ok)
    print("\n" + "=" * 100)
    print("RESUMEN: %d/%d APROBADOS" % (aprobados, total))
    if aprobados != total:
        print("\nCasos con FALLO:")
        for nombre, ok, evidencia in results:
            if not ok:
                print("  - " + nombre + " :: " + evidencia)
    print("=" * 100)
    return results


if __name__ == "__main__":
    print("Este modulo no se ejecuta directamente. Use pruebas/e2e_local.py "
          "(XAMPP) o pruebas/e2e_tguts.py (Docker).")
    sys.exit(2)
