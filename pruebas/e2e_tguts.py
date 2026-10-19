#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Pruebas end-to-end reales del Sistema de Trabajos de Grado UTS (JSP + JSTL).

No usa dependencias externas (solo la libreria estandar de Python). Se ejecuta
contra una instancia real de Tomcat 9 + MySQL 8 levantada con Docker.

Uso:
    python pruebas/e2e_tguts.py [base_url] [--mysql-container NOMBRE]

Por defecto:  base_url = http://localhost:18080
              contenedor MySQL = tguts-mysql

Cada caso imprime APROBADO/FALLO con la evidencia observada: codigo HTTP, URL
final (tras redirecciones), fragmento de HTML y/o valor consultado en la base de
datos. urllib sigue redirecciones automaticamente, por lo que la URL final se
obtiene con response.geturl(); no se "inventa" ningun resultado.
"""
import http.cookiejar
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

BASE = "http://localhost:18080"
MYSQL = "tguts-mysql"

results = []


def db(sql):
    """Ejecuta SQL en el contenedor MySQL y devuelve la salida (TSV, -N -B)."""
    out = subprocess.run(
        ["docker", "exec", MYSQL, "mysql", "-uroot", "-prootpw", "-N", "-B",
         "db_tgd_uts", "-e", sql],
        capture_output=True, text=True)
    return (out.stdout or "").strip().splitlines()[0].strip() if out.stdout else ""


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None  # no seguir redirecciones


class Session:
    def __init__(self):
        self.jar = http.cookiejar.CookieJar()
        handler = urllib.request.HTTPCookieProcessor(self.jar)
        self.opener = urllib.request.build_opener(handler)
        self.nofollow = urllib.request.build_opener(handler, _NoRedirect())

    def request(self, method, path, data=None, follow=True):
        if not path.startswith("http"):
            path = BASE + path
        body = urllib.parse.urlencode(data).encode() if data else None
        req = urllib.request.Request(path, data=body, method=method)
        opener = self.opener if follow else self.nofollow
        try:
            resp = opener.open(req, timeout=20)
            status, final, text = resp.status, resp.geturl(), resp.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            status, final, text = e.code, e.geturl(), e.read().decode("utf-8", "replace")
        return status, final, text

    def get(self, path, follow=True):
        return self.request("GET", path, follow=follow)

    def post(self, path, data, follow=True):
        return self.request("POST", path, data, follow=follow)


def csrf(html):
    m = re.search(r'name="csrf_token"\s+value="([^"]+)"', html)
    if not m:
        raise AssertionError("No se encontro csrf_token en la pagina")
    return m.group(1)


def login(email, password):
    s = Session()
    _, _, html = s.get("/login.jsp")
    token = csrf(html)
    status, final, body = s.post(
        "/login.jsp", {"csrf_token": token, "email": email, "password": password})
    ok = "/home.jsp" in final
    return s, ok, body, final


def record(nombre, ok, evidencia):
    results.append((nombre, ok, evidencia))
    print(("APROBADO" if ok else "FALLO  ") + " | " + nombre + " | " + evidencia)


def main():
    global BASE, MYSQL
    args = list(sys.argv[1:])
    if "--mysql-container" in args:
        i = args.index("--mysql-container")
        MYSQL = args[i + 1]
        del args[i:i + 2]
    if args:
        BASE = args[0]
    print("Base URL:", BASE, "| MySQL:", MYSQL)

    # ---------------- 1) Login de las 5 cuentas demo + credencial invalida ----
    cuentas = [
        ("admin@uts.edu.co", "admin123"),
        ("coord@uts.edu.co", "coord123"),
        ("director@uts.edu.co", "director123"),
        ("evaluador@uts.edu.co", "evaluador123"),
        ("estudiante@uts.edu.co", "estudiante123"),
        ("estudiante2@uts.edu.co", "estudiante123"),
    ]
    logins_ok = True
    det = []
    for email, pwd in cuentas:
        _, ok, _, final = login(email, pwd)
        if not ok:
            logins_ok = False
            det.append(email + "=" + final)
    s, ok, body, final = login("admin@uts.edu.co", "clave-mala")
    invalido_ok = (not ok) and ("Credenciales inválidas" in body or "Credenciales inv" in body)
    record("Login 5 cuentas demo", logins_ok,
           "todas redirigen a home.jsp" if logins_ok else "; ".join(det))
    record("Login rechaza credencial invalida", invalido_ok,
           "se queda en login.jsp con aviso" if invalido_ok else "no se mostro el aviso")

    # ---------------- 2) Formatos: enlaces de rutas locales ----------------
    admin, ok, _, _ = login("admin@uts.edu.co", "admin123")
    st_fmt, _, html = admin.get("/formatos.jsp")
    enlace_local = re.search(r'href="[^"]*FDC-124-Anteproyecto\.pdf[^"]*"', html) is not None
    record("Formatos: ruta local se convierte en enlace", st_fmt == 200 and enlace_local,
           "HTTP=%d; href al PDF base presente=%s" % (st_fmt, enlace_local))
    st_pdf, _, _ = admin.get("/formatos/FDC-124-Anteproyecto.pdf", follow=False)
    record("Formatos: PDF base accesible", st_pdf == 200, "HTTP %d al abrir el PDF" % st_pdf)

    # ---------------- 3) Ideas: roles del docente y guardado al editar -------
    eval_id = db("SELECT id FROM usuarios WHERE email='evaluador@uts.edu.co';")
    coord_id = db("SELECT id FROM usuarios WHERE email='coord@uts.edu.co';")
    dir_id = db("SELECT id FROM usuarios WHERE email='director@uts.edu.co';")

    _, _, html_ideas = admin.get("/ideas.jsp")
    opt_eval = ('<option value="%s"' % eval_id) in html_ideas
    opt_coord = ('<option value="%s"' % coord_id) in html_ideas
    record("Ideas: formulario ofrece docentes Director/Evaluador", opt_eval and not opt_coord,
           "opción Evaluador presente=%s, opción Coordinación presente=%s" % (opt_eval, opt_coord))

    token = csrf(html_ideas)
    import time
    unique_titulo = "IDEA-E2E-%d" % int(time.time())
    admin.post("/ideas.jsp", {"csrf_token": token, "accion": "crear",
                              "titulo": unique_titulo, "descripcion": "prueba",
                              "docente": eval_id})
    idea_id = db("SELECT id FROM ideas WHERE titulo='%s';" % unique_titulo)
    doc_creada = db("SELECT docente_id FROM ideas WHERE id=%s;" % idea_id)
    _, _, html_ed = admin.get("/ideas.jsp?accion=editar&id=" + idea_id)
    token = csrf(html_ed)
    admin.post("/ideas.jsp", {"csrf_token": token, "accion": "actualizar", "id": idea_id,
                              "titulo": unique_titulo, "descripcion": "editada", "docente": dir_id})
    doc_tras_editar = db("SELECT docente_id FROM ideas WHERE id=%s;" % idea_id)
    record("Ideas: el docente seleccionado se guarda al editar",
           doc_creada == eval_id and doc_tras_editar == dir_id,
           "docente_id al crear=%s, al editar=%s (esperado %s)" % (doc_creada, doc_tras_editar, dir_id))

    # ---------------- 4) Formulario del estudiante: valida director ----------
    # Limpiamos anteproyecto previo de estudiante2 si existe
    db("DELETE FROM anteproyectos WHERE estudiante_id=(SELECT id FROM usuarios WHERE email='estudiante2@uts.edu.co');")
    db("UPDATE ideas SET estado='PUBLICADA' WHERE titulo LIKE 'IDEA-E2E-FORM-%';")
    # Creamos una idea dedicada para estudiante2 y la seleccionamos
    admin, _, _, _ = login("admin@uts.edu.co", "admin123")
    _, _, html_ideas2 = admin.get("/ideas.jsp")
    token = csrf(html_ideas2)
    import time
    unique_titulo2 = "IDEA-E2E-FORM-%d" % int(time.time())
    admin.post("/ideas.jsp", {"csrf_token": token, "accion": "crear",
                              "titulo": unique_titulo2, "descripcion": "para test formulario",
                              "docente": eval_id})
    idea_id2 = db("SELECT id FROM ideas WHERE titulo='%s';" % unique_titulo2)

    est, _, _, _ = login("estudiante2@uts.edu.co", "estudiante123")
    _, _, html_bolsa = est.get("/ideas.jsp")
    token = csrf(html_bolsa)
    est.post("/ideas.jsp", {"csrf_token": token, "accion": "seleccionar", "id": idea_id2})
    ant_id = db("SELECT id FROM anteproyectos WHERE estudiante_id="
                "(SELECT id FROM usuarios WHERE email='estudiante2@uts.edu.co');")
    # Intento con coordinacion (no es director) -> debe rechazarse en servidor
    _, _, html_form = est.get("/anteproyecto_form.jsp?id=" + ant_id)
    token = csrf(html_form)
    _, _, html_bad = est.post(
        "/anteproyecto_form.jsp?id=" + ant_id,
        {"csrf_token": token, "titulo": "ANT-E2E", "director": coord_id,
         "documento": "https://example.com/a.pdf"})
    estado_tras_invalido = db("SELECT estado FROM anteproyectos WHERE id=%s;" % ant_id)
    record("Estudiante: rechaza director sin rol/activo",
           ("Director válido" in html_bad) and estado_tras_invalido == "BORRADOR",
           "estado=%s, mensaje de validación presente=%s" % (
               estado_tras_invalido, "Director válido" in html_bad))
    # Envio correcto
    _, _, html_form = est.get("/anteproyecto_form.jsp?id=" + ant_id)
    token = csrf(html_form)
    est.post("/anteproyecto_form.jsp?id=" + ant_id,
             {"csrf_token": token, "titulo": "ANT-E2E", "director": dir_id,
              "documento": "https://example.com/a.pdf"})
    estado_enviado = db("SELECT estado FROM anteproyectos WHERE id=%s;" % ant_id)
    record("Estudiante: envia anteproyecto con director valido", estado_enviado == "ENVIADO",
           "estado=%s" % estado_enviado)

    # El anteproyecto de estudiante2 (con director correcto) se usa para el resto del flujo
    ant_id = db("SELECT id FROM anteproyectos WHERE estudiante_id="
                "(SELECT id FROM usuarios WHERE email='estudiante2@uts.edu.co');")

    # ---------------- 5) Director: califica y ELIMINA calificacion ----------
    dr, _, _, _ = login("director@uts.edu.co", "director123")
    _, _, html_v = dr.get("/anteproyecto_ver.jsp?id=" + ant_id)
    token = csrf(html_v)
    dr.post("/anteproyecto_ver.jsp?id=" + ant_id,
            {"csrf_token": token, "accion": "calificar", "calificacion": "4.5",
             "observacion": "ok"})
    cal_creada = db("SELECT calificacion_director FROM anteproyectos WHERE id=%s;" % ant_id)
    hist_creado = db("SELECT COUNT(*) FROM calificaciones WHERE anteproyecto_id=%s "
                     "AND rol_calificador='DIRECTOR';" % ant_id)
    record("Director: guarda calificacion", cal_creada == "4.5" and hist_creado == "1",
           "calificacion_director=%s, filas historial=%s" % (cal_creada, hist_creado))

    _, _, html_v = dr.get("/anteproyecto_ver.jsp?id=" + ant_id)
    token = csrf(html_v)
    st_del, final_del, _ = dr.post(
        "/anteproyecto_ver.jsp?id=" + ant_id, {"csrf_token": token, "accion": "eliminar_calificacion"})
    cal_tras_del = db("SELECT calificacion_director FROM anteproyectos WHERE id=%s;" % ant_id)
    hist_tras_del = db("SELECT COUNT(*) FROM calificaciones WHERE anteproyecto_id=%s "
                       "AND rol_calificador='DIRECTOR';" % ant_id)
    record("Director: ELIMINA calificacion (transaccion con datasource)",
           st_del == 200 and cal_tras_del == "NULL" and hist_tras_del == "0",
           "HTTP=%d, calificacion=%s, historial=%s" % (st_del, cal_tras_del, hist_tras_del))

    # ---------------- 6) Director aprueba -> APROBADO_DIRECTOR --------------
    _, _, html_v = dr.get("/anteproyecto_ver.jsp?id=" + ant_id)
    token = csrf(html_v)
    dr.post("/anteproyecto_ver.jsp?id=" + ant_id, {"csrf_token": token, "accion": "calificar",
                                                   "calificacion": "4.0", "observacion": "ok"})
    _, _, html_v = dr.get("/anteproyecto_ver.jsp?id=" + ant_id)
    token = csrf(html_v)
    dr.post("/anteproyecto_ver.jsp?id=" + ant_id, {"csrf_token": token, "accion": "aprobar"})
    estado_apr_dir = db("SELECT estado FROM anteproyectos WHERE id=%s;" % ant_id)
    record("Director: aprueba anteproyecto", estado_apr_dir == "APROBADO_DIRECTOR",
           "estado=%s" % estado_apr_dir)

    # ---------------- 7) Evaluador: califica, elimina y aprueba -------------
    ev, _, _, _ = login("evaluador@uts.edu.co", "evaluador123")
    _, _, html_ev = ev.get("/anteproyecto_ver.jsp?id=" + ant_id)
    token = csrf(html_ev)
    ev.post("/anteproyecto_ver.jsp?id=" + ant_id, {"csrf_token": token,
            "accion": "calificar_eval", "calificacion": "3.5", "observacion": "revisar"})
    cal_ev = db("SELECT calificacion_evaluador FROM anteproyectos WHERE id=%s;" % ant_id)
    _, _, html_ev = ev.get("/anteproyecto_ver.jsp?id=" + ant_id)
    token = csrf(html_ev)
    st_de, _, _ = ev.post("/anteproyecto_ver.jsp?id=" + ant_id,
                          {"csrf_token": token, "accion": "eliminar_calificacion"})
    cal_ev_del = db("SELECT calificacion_evaluador FROM anteproyectos WHERE id=%s;" % ant_id)
    record("Evaluador: elimina calificacion (transaccion con datasource)",
           st_de == 200 and cal_ev == "3.5" and cal_ev_del == "NULL",
           "guardada=%s, tras eliminar=%s" % (cal_ev, cal_ev_del))
    _, _, html_ev = ev.get("/anteproyecto_ver.jsp?id=" + ant_id)
    token = csrf(html_ev)
    ev.post("/anteproyecto_ver.jsp?id=" + ant_id, {"csrf_token": token, "accion": "calificar_eval",
            "calificacion": "4.0", "observacion": "ok"})
    _, _, html_ev = ev.get("/anteproyecto_ver.jsp?id=" + ant_id)
    token = csrf(html_ev)
    ev.post("/anteproyecto_ver.jsp?id=" + ant_id, {"csrf_token": token, "accion": "evaluar"})
    estado_apr_eval = db("SELECT estado FROM anteproyectos WHERE id=%s;" % ant_id)
    record("Evaluador: aprueba anteproyecto", estado_apr_eval == "APROBADO_EVALUADOR",
           "estado=%s" % estado_apr_eval)

    # ---------------- 8) Coordinacion asigna director a APROBADO ------------
    _, _, html_u = admin.get("/usuarios.jsp")
    token = csrf(html_u)
    admin.post("/usuarios.jsp", {"csrf_token": token, "accion": "crear", "nombre": "Director Dos",
               "email": "director2@uts.edu.co", "password": "director2123", "rol": "DIRECTOR",
               "codigo": ""})
    dir2 = db("SELECT id FROM usuarios WHERE email='director2@uts.edu.co';")
    est_id = db("SELECT id FROM usuarios WHERE email='estudiante2@uts.edu.co';")
    eval_actual = db("SELECT evaluador_id FROM anteproyectos WHERE id=%s;" % ant_id)
    coord, _, _, _ = login("coord@uts.edu.co", "coord123")
    _, _, html_f = coord.get("/coordinacion.jsp?accion=ficha&id=" + est_id)
    token = csrf(html_f)
    coord.post("/coordinacion.jsp", {"csrf_token": token, "accion": "asignar",
                                     "anteproyecto_id": ant_id, "estudiante_id": est_id,
                                     "director": dir2, "evaluador": eval_actual})
    dir_tras_aprobado = db("SELECT director_id FROM anteproyectos WHERE id=%s;" % ant_id)
    record("Coordinacion: asigna director a anteproyecto APROBADO",
           dir_tras_aprobado == dir2,
           "estado previo=APROBADO_EVALUADOR, director_id=%s (esperado %s)" % (dir_tras_aprobado, dir2))
    # Se restituye el director original para continuar el flujo
    _, _, html_f = coord.get("/coordinacion.jsp?accion=ficha&id=" + est_id)
    token = csrf(html_f)
    coord.post("/coordinacion.jsp", {"csrf_token": token, "accion": "asignar",
                                     "anteproyecto_id": ant_id, "estudiante_id": est_id,
                                     "director": dir_id, "evaluador": eval_actual})

    # ---------------- 9) Entrega final: acceso del estudiante --------------
    est, _, _, _ = login("estudiante2@uts.edu.co", "estudiante123")
    _, _, html_av = est.get("/anteproyecto_ver.jsp?id=" + ant_id)
    tiene_enlace = ("entrega_final.jsp?id=" + ant_id) in html_av
    _, _, html_e = est.get("/entrega_final.jsp?id=" + ant_id)
    token = csrf(html_e)
    est.post("/entrega_final.jsp?id=" + ant_id, {"csrf_token": token, "accion": "crear",
             "titulo": "TRABAJO-E2E", "documento": "https://example.com/final.pdf"})
    estado_entrega = db("SELECT estado FROM anteproyectos WHERE id=%s;" % ant_id)
    st_e2, final_e2, html_e2 = est.get("/entrega_final.jsp?id=" + ant_id)
    ve_su_entrega = ("Documento entregado" in html_e2) and ("entrega_final.jsp?id=" + ant_id in final_e2)
    record("Entrega final: enlace visible en el anteproyecto aprobado", tiene_enlace,
           "enlace a entrega_final.jsp presente" if tiene_enlace else "enlace ausente")
    record("Entrega final: el estudiante sigue viendo su entrega (sin redireccion)",
           ve_su_entrega and estado_entrega == "ENTREGA_DOCUMENTO_FINAL",
           "estado=%s, url final=%s" % (estado_entrega, final_e2))

    # ---------------- 10) Coordinacion revisa (OBSERVADO) -> correccion -----
    _, _, html_u = admin.get("/usuarios.jsp")
    token = csrf(html_u)
    admin.post("/usuarios.jsp", {"csrf_token": token, "accion": "crear", "nombre": "Coord Dos",
               "email": "coord2@uts.edu.co", "password": "coord2pass", "rol": "COORDINACION",
               "codigo": ""})
    coord2_id = db("SELECT id FROM usuarios WHERE email='coord2@uts.edu.co';")
    coord2, _, _, _ = login("coord2@uts.edu.co", "coord2pass")
    _, _, html_r = coord2.get("/entrega_final.jsp?id=" + ant_id)
    token = csrf(html_r)
    entrega_id = db("SELECT id FROM entrega_final WHERE anteproyecto_id=%s;" % ant_id)
    coord2.post("/entrega_final.jsp?id=" + ant_id, {"csrf_token": token, "accion": "revisar",
               "entrega_id": entrega_id, "estado_nuevo": "OBSERVADO",
               "observaciones": "faltan anexos"})
    estado_ent_obs = db("SELECT estado FROM entrega_final WHERE anteproyecto_id=%s;" % ant_id)
    revisado_por = db("SELECT revisado_por FROM entrega_final WHERE anteproyecto_id=%s;" % ant_id)

    # 11) Eliminacion de usuario: revisor de entrega final (aun con revisado_por)
    _, _, html_u = admin.get("/usuarios.jsp")
    token = csrf(html_u)
    _, _, body_del_u = admin.post("/usuarios.jsp", {"csrf_token": token,
                                                    "accion": "eliminar", "id": coord2_id})
    existe_coord2 = db("SELECT COUNT(*) FROM usuarios WHERE id=%s;" % coord2_id)
    bloqueado = existe_coord2 == "1" and "No se puede eliminar" in body_del_u
    record("Usuarios: no elimina a quien reviso una entrega final", bloqueado,
           "revisado_por=%s, usuario sigue existiendo=%s, mensaje de bloqueo=%s" % (
               revisado_por, existe_coord2, "No se puede eliminar" in body_del_u))

    est, _, _, _ = login("estudiante2@uts.edu.co", "estudiante123")
    _, _, html_corr = est.get("/entrega_final.jsp?id=" + ant_id)
    ve_correccion = "Corregir y reenviar documento" in html_corr
    record("Entrega final: el estudiante ve correccion tras OBSERVADO",
           estado_ent_obs == "OBSERVADO" and ve_correccion,
           "estado entrega=%s, formulario de correccion visible=%s" % (estado_ent_obs, ve_correccion))
    token = csrf(html_corr)
    est.post("/entrega_final.jsp?id=" + ant_id, {"csrf_token": token, "accion": "corregir",
             "titulo": "TRABAJO-E2E", "documento": "https://example.com/final-v2.pdf"})
    estado_ent_corr = db("SELECT estado FROM entrega_final WHERE anteproyecto_id=%s;" % ant_id)
    record("Entrega final: el estudiante reenvia la correccion", estado_ent_corr == "ENTREGADO",
           "estado entrega=%s" % estado_ent_corr)

    # ---------------- Resumen ----------------
    total = len(results)
    aprobados = sum(1 for _, ok, _ in results if ok)
    print("\n===== RESUMEN: %d/%d APROBADOS =====" % (aprobados, total))
    return 0 if aprobados == total else 1


if __name__ == "__main__":
    sys.exit(main())
