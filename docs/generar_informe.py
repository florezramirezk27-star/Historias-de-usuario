#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Genera el documento final consolidado (.docx) del proyecto
"Sistema de Trabajos de Grado UTS" (JSP + JSTL).

El documento integra:
  * Requisitos funcionales (RF-01 ... RF-43) y no funcionales (RNF-01 ... RNF-10).
  * Historias de usuario.
  * Modelo de datos, arquitectura, seguridad y decisiones de diseño.
  * Plan de trabajo.
  * Guion de demostración (se conserva el contenido de GUION.md).
  * Registro de pruebas (se conserva el contenido de TEST_RESULTS.md).

Uso:
    python docs/generar_informe.py
Salida:
    docs/Sistema_Trabajos_de_Grado_UTS.docx
"""
import io
import os
import re
import sys
import zipfile
from datetime import date

from docx import Document
from docx.enum.section import WD_ORIENT
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(RAIZ, "docs")
SALIDA = os.path.join(DOCS, "Sistema_Trabajos_de_Grado_UTS.docx")

AZUL = RGBColor(0x1F, 0x4E, 0x79)
AZUL2 = RGBColor(0x2E, 0x74, 0xB5)
GRIS = RGBColor(0x59, 0x59, 0x59)


# ---------------------------------------------------------------- utilidades
def leer(ruta_rel):
    with io.open(os.path.join(RAIZ, ruta_rel), encoding="utf-8") as f:
        return f.read()


def limpiar(texto):
    """Quita marcas de Markdown en línea conservando el contenido."""
    texto = texto.replace("\\|", "|")
    texto = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r"\1 (\2)", texto)
    texto = texto.replace("**", "").replace("__", "")
    texto = texto.replace("`", "")
    texto = re.sub(r"(?<!\w)\*(?!\w)", "", texto)
    return texto.strip()


def sombrear(celda, color_hex):
    tc_pr = celda._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"), color_hex)
    tc_pr.append(shd)


def repetir_encabezado(fila):
    tr_pr = fila._tr.get_or_add_trPr()
    el = OxmlElement("w:tblHeader")
    el.set(qn("w:val"), "true")
    tr_pr.append(el)


def celda_texto(celda, texto, negrita=False, tam=8.5, color=None):
    celda.text = ""
    parrafo = celda.paragraphs[0]
    parrafo.paragraph_format.space_before = Pt(1)
    parrafo.paragraph_format.space_after = Pt(1)
    for i, parte in enumerate(str(texto).split("\n")):
        if i:
            parrafo = celda.add_paragraph()
            parrafo.paragraph_format.space_before = Pt(0)
            parrafo.paragraph_format.space_after = Pt(1)
        run = parrafo.add_run(parte)
        run.font.size = Pt(tam)
        run.bold = negrita
        if color is not None:
            run.font.color.rgb = color


def agregar_tabla(doc, cabeceras, filas, tam=8.5, ancho_total=16.4):
    tabla = doc.add_table(rows=1, cols=len(cabeceras))
    tabla.style = "Table Grid"
    tabla.alignment = WD_TABLE_ALIGNMENT.CENTER
    tabla.autofit = True
    for i, cab in enumerate(cabeceras):
        celda_texto(tabla.rows[0].cells[i], limpiar(cab), negrita=True, tam=tam, color=RGBColor(0xFF, 0xFF, 0xFF))
        sombrear(tabla.rows[0].cells[i], "1F4E79")
    repetir_encabezado(tabla.rows[0])
    for fila in filas:
        celdas = tabla.add_row().cells
        for i in range(len(cabeceras)):
            valor = fila[i] if i < len(fila) else ""
            celda_texto(celdas[i], limpiar(valor), tam=tam)
    # primera fila de datos en negrita suave para tablas de dos columnas
    if len(cabeceras) == 2:
        for fila in tabla.rows[1:]:
            for run in fila.cells[0].paragraphs[0].runs:
                run.bold = True
    return tabla


def parrafo(doc, texto, tam=10.5, negrita=False, cursiva=False, alineacion=None,
            espacio_antes=0, espacio_despues=4, color=None):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(espacio_antes)
    p.paragraph_format.space_after = Pt(espacio_despues)
    if alineacion is not None:
        p.alignment = alineacion
    run = p.add_run(limpiar(texto))
    run.font.size = Pt(tam)
    run.bold = negrita
    run.italic = cursiva
    if color is not None:
        run.font.color.rgb = color
    return p


def vinetas(doc, items, tam=10.5):
    for item in items:
        p = doc.add_paragraph(style="List Bullet")
        p.paragraph_format.space_after = Pt(2)
        run = p.add_run(limpiar(item))
        run.font.size = Pt(tam)


def codigo(doc, texto, tam=8.5):
    for linea in texto.split("\n"):
        p = doc.add_paragraph()
        p.paragraph_format.space_after = Pt(0)
        p.paragraph_format.space_before = Pt(0)
        p.paragraph_format.left_indent = Cm(0.5)
        run = p.add_run(linea if linea else " ")
        run.font.name = "Consolas"
        run.font.size = Pt(tam)
        run.font.color.rgb = RGBColor(0x1F, 0x1F, 0x1F)
    doc.add_paragraph().paragraph_format.space_after = Pt(2)


def titulo(doc, texto, nivel=1):
    h = doc.add_heading(limpiar(texto), level=nivel)
    for run in h.runs:
        run.font.color.rgb = AZUL if nivel == 1 else AZUL2
        run.font.name = "Calibri"
    return h


def salto_pagina(doc):
    doc.add_page_break()


def campo(parrafo_doc, instruccion, texto_provisional=""):
    run = parrafo_doc.add_run()
    f1 = OxmlElement("w:fldChar")
    f1.set(qn("w:fldCharType"), "begin")
    instr = OxmlElement("w:instrText")
    instr.set(qn("xml:space"), "preserve")
    instr.text = instruccion
    f2 = OxmlElement("w:fldChar")
    f2.set(qn("w:fldCharType"), "separate")
    t = OxmlElement("w:t")
    t.text = texto_provisional
    f2.append(t)
    f3 = OxmlElement("w:fldChar")
    f3.set(qn("w:fldCharType"), "end")
    run._r.append(f1)
    run._r.append(instr)
    run._r.append(f2)
    run._r.append(f3)


# ------------------------------------------------- render de Markdown a DOCX
def separar_fila(linea):
    celdas = []
    buffer = ""
    i = 0
    while i < len(linea):
        c = linea[i]
        if c == "\\" and i + 1 < len(linea) and linea[i + 1] == "|":
            buffer += "|"
            i += 2
            continue
        if c == "|":
            celdas.append(buffer)
            buffer = ""
            i += 1
            continue
        buffer += c
        i += 1
    celdas.append(buffer)
    if celdas and celdas[0].strip() == "":
        celdas = celdas[1:]
    if celdas and celdas[-1].strip() == "":
        celdas = celdas[:-1]
    return [c.strip() for c in celdas]


def render_markdown(doc, md, desplazamiento=0, saltar_h1=True):
    """Convierte Markdown (encabezados, tablas, listas, código) en contenido DOCX."""
    lineas = md.split("\n")
    i = 0
    en_codigo = False
    bloque = []
    while i < len(lineas):
        linea = lineas[i]
        s = linea.strip()
        if s.startswith("```"):
            if en_codigo:
                codigo(doc, "\n".join(bloque))
                bloque = []
                en_codigo = False
            else:
                en_codigo = True
            i += 1
            continue
        if en_codigo:
            bloque.append(linea)
            i += 1
            continue
        if not s:
            i += 1
            continue
        m = re.match(r"^(#{1,6})\s+(.*)$", s)
        if m:
            nivel = len(m.group(1))
            if saltar_h1 and nivel <= 1:
                i += 1
                continue
            titulo(doc, m.group(2), min(nivel + desplazamiento, 4))
            i += 1
            continue
        if re.match(r"^(-{3,}|\*{3,}|_{3,})$", s):
            i += 1
            continue
        if s.startswith("|"):
            grupo = []
            while i < len(lineas) and lineas[i].strip().startswith("|"):
                grupo.append(lineas[i].strip())
                i += 1
            if len(grupo) >= 2 and re.match(r"^\|[\s:\-\|]+\|$", grupo[1]):
                cabeceras = separar_fila(grupo[0])
                filas = [separar_fila(g) for g in grupo[2:]]
                agregar_tabla(doc, cabeceras, filas)
            else:
                for g in grupo:
                    parrafo(doc, g, tam=10)
            continue
        m = re.match(r"^\s*[-*]\s+(.*)$", linea)
        if m:
            vinetas(doc, [m.group(1)])
            i += 1
            continue
        m = re.match(r"^\s*\d+\.\s+(.*)$", linea)
        if m:
            p = doc.add_paragraph(style="List Number")
            p.paragraph_format.space_after = Pt(2)
            run = p.add_run(limpiar(m.group(1)))
            run.font.size = Pt(10.5)
            i += 1
            continue
        if s.startswith(">"):
            parrafo(doc, s.lstrip("> ").strip(), cursiva=True, tam=10, color=GRIS)
            i += 1
            continue
        parrafo(doc, s)
        i += 1
    if en_codigo and bloque:
        codigo(doc, "\n".join(bloque))


def secciones(md):
    """Divide un Markdown en secciones: [(nivel, titulo, cuerpo)]."""
    lineas = md.split("\n")
    resultado = []
    actual = None
    cuerpo = []
    for linea in lineas:
        m = re.match(r"^(#{1,6})\s+(.*)$", linea.strip())
        if m:
            if actual is not None:
                resultado.append((actual[0], actual[1], "\n".join(cuerpo)))
            actual = (len(m.group(1)), m.group(2).strip())
            cuerpo = []
        else:
            cuerpo.append(linea)
    if actual is not None:
        resultado.append((actual[0], actual[1], "\n".join(cuerpo)))
    return resultado


def seccion(md, prefijo):
    """Devuelve el cuerpo de la sección cuyo título empieza con prefijo."""
    objetivo = re.sub(r"^#+\s*", "", prefijo).strip().lower()
    for nivel, titulo_txt, cuerpo in secciones(md):
        if titulo_txt.strip().lower().startswith(objetivo):
            return cuerpo
    raise KeyError("No se encontró la sección: %s" % prefijo)


# ------------------------------------------------------------------ estilos
def configurar(doc):
    seccion_ = doc.sections[0]
    seccion_.orientation = WD_ORIENT.PORTRAIT
    seccion_.top_margin = Cm(2.2)
    seccion_.bottom_margin = Cm(2.0)
    seccion_.left_margin = Cm(2.2)
    seccion_.right_margin = Cm(2.2)

    normal = doc.styles["Normal"]
    normal.font.name = "Calibri"
    normal.font.size = Pt(10.5)
    normal.element.rPr.rFonts.set(qn("w:eastAsia"), "Calibri")
    normal.paragraph_format.space_after = Pt(4)

    for nombre, tam, color in (("Heading 1", 15, AZUL), ("Heading 2", 12.5, AZUL2),
                               ("Heading 3", 11, AZUL), ("Heading 4", 10.5, AZUL2)):
        st = doc.styles[nombre]
        st.font.name = "Calibri"
        st.font.size = Pt(tam)
        st.font.color.rgb = color
        st.font.bold = True
        st.paragraph_format.space_before = Pt(10)
        st.paragraph_format.space_after = Pt(4)

    pie = seccion_.footer.paragraphs[0]
    pie.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = pie.add_run("Sistema de Trabajos de Grado UTS  |  Página ")
    run.font.size = Pt(8)
    run.font.color.rgb = GRIS
    campo(pie, "PAGE", "1")
    run = pie.add_run(" de ")
    run.font.size = Pt(8)
    run.font.color.rgb = GRIS
    campo(pie, "NUMPAGES", "1")

    enc = seccion_.header.paragraphs[0]
    enc.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    run = enc.add_run("Trabajo de grado · JSP + JSTL · Universitaria Tecnológica de Santander")
    run.font.size = Pt(8)
    run.font.color.rgb = GRIS


# --------------------------------------------------------------- contenido
REQUISITOS_NO_FUNCIONALES = [
    ("RNF-01", "Rendimiento", "La aplicación debe responder cada petición en menos de 3 segundos en el entorno de pruebas (Tomcat 8.5.96 + MariaDB local).", "Todas las pantallas"),
    ("RNF-02", "Control de acceso por rol", "Cada módulo solo puede ser abierto por los roles autorizados; el menú lateral y las guardas de página se construyen a partir del rol de la sesión.", "Menú y guardas (RNF-02)"),
    ("RNF-03", "Control de propiedad", "Un usuario solo puede consultar o modificar los registros que le pertenecen (anteproyectos, trámites, entregas).", "Consultas con filtro por propietario"),
    ("RNF-04", "Integridad referencial y estados", "Los cambios de estado se ejecutan con guardas `AND estado = ...` para impedir transiciones ilegales o reenvíos de operaciones.", "UPDATE con condición de estado"),
    ("RNF-05", "Seguridad de credenciales", "Las contraseñas se almacenan con PBKDF2-HMAC-SHA256 (120 000 iteraciones) y sal aleatoria por usuario; nunca en texto plano.", "common/seguridad.jsp"),
    ("RNF-06", "Protección CSRF", "Toda petición POST valida un token por sesión; las peticiones sin token válido se rechazan.", "common/verify_csrf.jsp"),
    ("RNF-07", "Seguridad de sesión", "Rotación del identificador al iniciar sesión, invalidación al cerrar, tiempo de expiración de 30 minutos y cookies HttpOnly y SameSite=Lax.", "login.jsp / logout.jsp / web.xml"),
    ("RNF-08", "Robustez ante inyección", "Todas las consultas parametrizan sus valores con `<sql:param>`; la salida dinámica se escapa con `<c:out>` o `fn:escapeXml`.", "JSTL SQL + funciones"),
    ("RNF-09", "Usabilidad", "La interfaz es navegable sin JavaScript, con mensajes de éxito o error en cada operación y textos de ayuda en los formularios.", "Todos los módulos"),
    ("RNF-10", "Portabilidad", "El sistema se empaqueta como WAR y funciona en Tomcat 8.5/9 sobre Windows, Linux o contenedor, sin dependencias del sistema operativo.", "Maven WAR"),
]

REGLAS_NEGOCIO = [
    ("RN-01", "Un estudiante puede tener como máximo un anteproyecto registrado (restricción `UNIQUE` en `anteproyectos.estudiante_id`).", "RF-12"),
    ("RN-02", "El docente de una idea debe tener rol `DIRECTOR` o `EVALUADOR` y estar activo.", "RF-09, RF-25"),
    ("RN-03", "El director de un anteproyecto debe tener rol `DIRECTOR` y estar activo (validación en el servidor, no solo en el formulario).", "RF-14, RF-16"),
    ("RN-04", "El anteproyecto y el documento final se registran únicamente por URL `http(s)`; no se admiten archivos.", "RF-14, RF-36"),
    ("RN-05", "No se puede aprobar un anteproyecto sin haberlo calificado previamente (director y evaluador).", "RF-20, RF-23"),
    ("RN-06", "El evaluador solo puede asignarse cuando el anteproyecto ya fue aprobado por el director.", "RF-26"),
    ("RN-07", "El director puede asignarse o cambiarse por la coordinación en cualquier estado del anteproyecto.", "RF-26"),
    ("RN-08", "Solo puede existir una entrega final por anteproyecto (`UNIQUE` en `entrega_final.anteproyecto_id`).", "RF-36"),
    ("RN-09", "La revisión del documento final solo es posible en `ENTREGA_DOCUMENTO_FINAL` y `REVISIÓN_FINAL`; en estados posteriores el documento está cerrado.", "RF-41"),
    ("RN-10", "Observar el documento desde `REVISIÓN_FINAL` devuelve el trabajo a `ENTREGA_DOCUMENTO_FINAL` para permitir la corrección del estudiante.", "RF-41"),
    ("RN-11", "La calificación se valida en el rango de 0 a 5 y se registra además en el historial de calificaciones.", "RF-19, RF-22, RF-35"),
    ("RN-12", "No se puede eliminar un usuario que tenga anteproyectos, ideas, calificaciones, trámites o revisiones de entrega final asociadas, ni la cuenta propia.", "RF-08"),
    ("RN-13", "Un trámite resuelto no puede volver a resolverse.", "RF-38, RF-39, RF-40"),
    ("RN-14", "La sustentación solo se puede programar con el anteproyecto en `REVISIÓN_FINAL`; si el resultado es `APROBADO` el proyecto queda `FINALIZADO`.", "RF-42, RF-43"),
    ("RN-15", "Todo evento del proceso genera una notificación en la bandeja del destinatario.", "RF-37"),
]

HISTORIAS_USUARIO = [
    ("US-01", "Iniciar sesión en el sistema", "Todos los roles",
     "Como usuario del sistema, quiero iniciar sesión con mi correo y contraseña, para acceder a los módulos que me corresponden.",
     "Dado un usuario activo, cuando ingresa credenciales válidas, entonces el sistema lo dirige a su panel según el rol.",
     "RF-01, RF-02, RNF-05, RNF-07"),
    ("US-02", "Cerrar sesión", "Todos los roles",
     "Como usuario del sistema, quiero cerrar mi sesión, para que nadie más use mi sesión abierta.",
     "Dado un usuario autenticado, cuando pulsa «Salir», entonces la sesión se invalida y los módulos vuelven a exigir login.",
     "RF-01, RNF-07"),
    ("US-03", "Crear usuarios", "Administrador",
     "Como administrador, quiero registrar usuarios con su rol y código, para contar con las cuentas que exige el proceso.",
     "Dado el administrador, cuando completa el formulario con datos válidos, entonces el usuario queda creado con la contraseña cifrada.",
     "RF-04, RNF-05"),
    ("US-04", "Editar usuarios", "Administrador",
     "Como administrador, quiero modificar los datos de un usuario, para mantenerlos actualizados.",
     "Dado un usuario existente, cuando el administrador edita y guarda, entonces los cambios quedan persistidos.",
     "RF-05, RF-07"),
    ("US-05", "Eliminar usuarios", "Administrador",
     "Como administrador, quiero eliminar cuentas que ya no se usan, para mantener el listado depurado.",
     "Dado un usuario sin datos asociados, cuando el administrador lo elimina, entonces la cuenta se borra; si tiene dependencias, el sistema lo informa y no borra.",
     "RF-08, RN-12"),
    ("US-06", "Publicar una idea de trabajo de grado", "Director / Evaluador / Administración",
     "Como docente, quiero publicar una idea de trabajo de grado, para que los estudiantes laijan un tema.",
     "Dado un docente con rol válido, cuando publica la idea, entonces queda registrada a su nombre y en estado `PUBLICADA`.",
     "RF-09, RN-02"),
    ("US-07", "Administrar el banco de ideas", "Administrador / Coordinación",
     "Como administración, quiero editar, cerrar y eliminar ideas, para mantener la bolsa de ideas al día.",
     "Dado un banco de ideas, cuando el administrador edita, cierra o elimina, entonces la idea refleja el cambio y deja de ofrecerse si se cierra.",
     "RF-10, RF-25"),
    ("US-08", "Seleccionar una idea", "Estudiante",
     "Como estudiante, quiero seleccionar una idea publicada, para iniciar mi anteproyecto.",
     "Dada una idea disponible, cuando el estudiante la selecciona, entonces se crea su anteproyecto en `BORRADOR` y la idea queda `SELECCIONADA`.",
     "RF-11, RF-13, RN-01"),
    ("US-09", "Registrar el anteproyecto", "Estudiante",
     "Como estudiante, quiero completar la información de mi anteproyecto y el enlace de su documento, para enviarlo a mi director.",
     "Dado un anteproyecto en borrador, cuando el estudiante guarda con un director válido y una URL `http(s)`, entonces el estado pasa a `ENVIADO` y se notifica al director.",
     "RF-14, RF-16, RN-03, RN-04"),
    ("US-10", "Consultar y corregir mi anteproyecto", "Estudiante",
     "Como estudiante, quiero ver el estado, las observaciones y las calificaciones de mi anteproyecto, para corregir lo que me indiquen.",
     "Dado un anteproyecto propio, cuando el estudiante lo consulta, entonces ve el estado, las observaciones de los docentes y el historial de calificaciones.",
     "RF-15, RF-34, RF-35"),
    ("US-11", "Calificar el anteproyecto", "Director",
     "Como director, quiero calificar el anteproyecto que dirijo, para registrar mi avalúo.",
     "Dado un anteproyecto en `ENVIADO`, cuando el director califica entre 0 y 5, entonces la nota se guarda y queda registrada en el historial.",
     "RF-19, RF-35, RN-11"),
    ("US-12", "Aprobar o rechazar el anteproyecto", "Director",
     "Como director, quiero aprobar o rechazar el anteproyecto, para que el proceso continúe o vuelva al estudiante.",
     "Dado un anteproyecto calificado, cuando el director aprueba, entonces pasa a `APROBADO_DIRECTOR` y se asigna un evaluador; cuando rechaza, el estudiante recibe las observaciones.",
     "RF-20, RF-37"),
    ("US-13", "Evaluar y aprobar el anteproyecto", "Evaluador",
     "Como evaluador, quiero calificar y aprobar el anteproyecto que me asignaron, para completar la evaluación.",
     "Dado un anteproyecto en `APROBADO_DIRECTOR`, cuando el evaluador califica y aprueba, entonces pasa a `APROBADO_EVALUADOR` y se notifica al estudiante y a la coordinación.",
     "RF-22, RF-23, RF-24"),
    ("US-14", "Buscar estudiantes", "Coordinación / Administración",
     "Como coordinación, quiero buscar estudiantes por nombre, código o correo, para localizar un proyecto rápidamente.",
     "Dada una cadena de búsqueda, cuando la coordinación busca, entonces la tabla muestra las coincidencias; si no hay resultados, el sistema lo informa.",
     "RF-27"),
    ("US-15", "Consultar la ficha del estudiante", "Coordinación / Administración",
     "Como coordinación, quiero ver la ficha de un estudiante con su proyecto y su equipo evaluador, para hacer seguimiento.",
     "Dado un resultado de búsqueda, cuando la coordinación abre la ficha, entonces ve código, anteproyecto, director y evaluador.",
     "RF-28"),
    ("US-16", "Asignar director y evaluador", "Coordinación / Administración",
     "Como coordinación, quiero asignar o cambiar el director y el evaluador de un anteproyecto, para dirigir el trabajo.",
     "Dado un anteproyecto, cuando la coordinación guarda la asignación, entonces los datos se actualizan y se envían las notificaciones; el evaluador solo se asigna tras la aprobación del director.",
     "RF-26, RN-06, RN-07"),
    ("US-17", "Entregar el documento final", "Estudiante",
     "Como estudiante, quiero registrar el enlace de mi documento final, para entregar el trabajo de grado.",
     "Dado un anteproyecto en `APROBADO_EVALUADOR`, cuando el estudiante entrega, entonces la entrega queda `ENTREGADO` y el director es notificado.",
     "RF-36, RN-08"),
    ("US-18", "Corregir y reenviar el documento final", "Estudiante",
     "Como estudiante, quiero corregir el documento que me fue observado, para devolverlo a revisión.",
     "Dada una entrega `OBSERVADO`, cuando el estudiante envía la corrección, entonces la entrega vuelve a `ENTREGADO` y el director es notificado.",
     "RF-36, RN-10"),
    ("US-19", "Revisar el documento final", "Director / Coordinación / Administración",
     "Como revisor, quiero observar, poner en revisión o aprobar el documento final, para decidir si pasa a sustentación.",
     "Dado un documento entregado, cuando el revisor registra su decisión, entonces la entrega cambia de estado; observar devuelve el trabajo a corrección y en estados cerrados la operación se bloquea.",
     "RF-41, RN-09, RN-10"),
    ("US-20", "Programar la sustentación", "Coordinación / Administración",
     "Como coordinación, quiero programar la fecha, hora y lugar de la sustentación, para organizar la defensa.",
     "Dado un anteproyecto en `REVISIÓN_FINAL`, cuando la coordinación programa, entonces se registra el acto y el estado pasa a `SUSTENTACIÓN`.",
     "RF-42, RN-14"),
    ("US-21", "Registrar el resultado de la sustentación", "Director / Evaluador",
     "Como director o evaluador, quiero registrar el resultado de la sustentación, para cerrar el proceso.",
     "Dada una sustentación programada, cuando se registra `APROBADO`, entonces el anteproyecto queda `FINALIZADO`; si es `RECHAZADO` permanece en `SUSTENTACIÓN`.",
     "RF-43, RN-14"),
    ("US-22", "Consultar el estado de los proyectos", "Coordinación / Administración",
     "Como administración, quiero consultar informes por estudiante, director y evaluador, para medir el avance del proceso.",
     "Dado un conjunto de anteproyectos, cuando se abre un informe, entonces se muestra la tabla con las columnas del rol solicitado.",
     "RF-29, RF-30, RF-31"),
    ("US-23", "Administrar el calendario académico", "Administrador / Coordinación",
     "Como administración, quiero registrar, editar y eliminar los hitos del calendario, para publicar las fechas del proceso.",
     "Dado el calendario, cuando la administración registra, edita o elimina un evento, entonces la tabla refleja el cambio.",
     "RF-32"),
    ("US-24", "Administrar los formatos de grado", "Administrador / Coordinación",
     "Como administración, quiero registrar y actualizar el enlace de los formatos, para tener las plantillas disponibles.",
     "Dados los formatos, cuando la administración crea, actualiza o elimina, entonces el enlace del documento queda correcto y escapado en el HTML.",
     "RF-33, RNF-08"),
    ("US-25", "Consultar formatos y calendario", "Todos los roles",
     "Como estudiante, quiero consultar el calendario y los formatos, para conocer las fechas y plantillas del proceso.",
     "Dado un usuario autenticado, cuando abre el calendario o los formatos, entonces ve la información sin acceso a la administración.",
     "RF-32, RF-33"),
    ("US-26", "Solicitar un trámite", "Estudiante",
     "Como estudiante, quiero solicitar retiro, prórroga o beneficio, para gestionar mi situación académica.",
     "Dado un estudiante autenticado, cuando envía una solicitud, entonces el trámite queda `PENDIENTE` y la coordinación es notificada.",
     "RF-38, RF-39, RF-40"),
    ("US-27", "Resolver trámites", "Coordinación / Administración",
     "Como coordinación, quiero aprobar o rechazar los trámites, para dar respuesta formal a los estudiantes.",
     "Dado un trámite pendiente, cuando la coordinación responde, entonces queda resuelto con su respuesta; un trámite ya resuelto no se puede volver a resolver.",
     "RF-38, RF-39, RF-40, RN-13"),
    ("US-28", "Consultar notificaciones", "Todos los roles",
     "Como usuario del sistema, quiero ver mis avisos, para seguir el estado de mi proceso.",
     "Dado un evento del proceso, cuando se produce, entonces el destinatario recibe una notificación en su bandeja.",
     "RF-37, RN-15"),
]

PLAN_TRABAJO = [
    ("F1", "Análisis y levantamiento de requisitos", "Identificación de roles, módulos y reglas del parcial; definición del catálogo RF-01…RF-43 y RNF-01…RNF-10.", "Documento de requisitos, historias de usuario", "2 semanas", "Equipo de análisis", "Completada"),
    ("F2", "Modelado de datos", "Diseño del esquema relacional (10 tablas), índices, restricciones `UNIQUE` y script de inicialización.", "db_tgd_uts.sql", "1 semana", "Equipo de modelo de datos", "Completada"),
    ("F3", "Diseño de la interfaz y navegación", "Menú por rol, estilos, formularios y mensajes de validación.", "Maquetación HTML/CSS", "1 semana", "Equipo de interfaz", "Completada"),
    ("F4", "Implementación del núcleo del proceso", "Autenticación, usuarios, ideas, anteproyecto, calificaciones, aprobación y evaluación.", "Módulos JSP núcleo", "3 semanas", "Equipo de desarrollo", "Completada"),
    ("F5", "Módulos complementarios", "Entrega final, sustentación, trámites, calendario, formatos, informes y notificaciones.", "Módulos JSP complementarios", "2 semanas", "Equipo de desarrollo", "Completada"),
    ("F6", "Seguridad y endurecimiento", "PBKDF2, CSRF, guardas por rol, por propiedad y por estado, escapado de la salida HTML.", "Capa de seguridad", "1 semana", "Equipo de desarrollo", "Completada"),
    ("F7", "Pruebas end-to-end y correcciones", "Suite de 99 casos, ejecución real contra Tomcat y base de datos, corrección de los defectos detectados.", "Suite E2E (Python, retirada del repositorio) + TEST_RESULTS.md", "1,5 semanas", "Equipo de pruebas", "Completada (99/99)"),
    ("F8", "Documentación y sustentación final", "Documento técnico, guion de demostración, manual de usuario y documento final.", "README, DOCUMENTACION_TECNICA, GUION, TEST_RESULTS, .docx", "1 semana", "Equipo de documentación", "Completada"),
]

TAREAS_OPERACION = [
    ("Reconstruir el WAR", "`cd tguts && mvn clean package`", "Genera `tguts/target/tguts.war` (JDK 21, release 17); copiarlo a `C:\\xampp\\tomcat\\webapps\\` y reiniciar Tomcat."),
    ("Consultar la base de datos", "`C:\\xampp\\mysql\\bin\\mysql.exe -uroot -N -B --default-character-set=utf8mb4 db_tgd_uts -e \"<sql>\"`", "Acceso directo a MariaDB de XAMPP."),
    ("Migrar una base existente", "`cmd /c \"mysql -uroot < tguts\\sql\\migracion_seguridad.sql\"`", "Amplía `password`, crea índices y `UNIQUE` y migra los hashes SHA-256 heredados."),
    ("Rotar el costo de PBKDF2", "Variable de entorno `PBKDF2_ITERATIONS`", "Los hashes se recalculan en el siguiente inicio de sesión."),
]


def construir():
    doc = Document()
    configurar(doc)

    readme = leer("README.md")
    guion = leer("GUION.md")
    pruebas = leer("TEST_RESULTS.md")
    tecnica = leer("DOCUMENTACION_TECNICA.md")
    # La evidencia de la suite E2E se retiró del repositorio junto con los
    # scripts; si vuelve a existir, se incrusta en el informe.
    ruta_evidencia = "pruebas/salida_e2e_local.txt"
    evidencia = leer(ruta_evidencia) if os.path.exists(os.path.join(RAIZ, ruta_evidencia)) else ""

    # ------------------------------------------------------------- portada
    for _ in range(3):
        doc.add_paragraph()
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run("SISTEMA DE TRABAJOS DE GRADO")
    run.font.size = Pt(24)
    run.bold = True
    run.font.color.rgb = AZUL
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run("Universitaria Tecnológica de Santander (UTS)")
    run.font.size = Pt(15)
    run.font.color.rgb = AZUL2
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run("Aplicación web para la gestión del proceso de trabajos de grado\n"
                    "desarrollada con JSP + JSTL sobre MySQL/MariaDB")
    run.font.size = Pt(11.5)
    run.italic = True
    run.font.color.rgb = GRIS
    doc.add_paragraph()

    agregar_tabla(doc, ["Dato", "Detalle"], [
        ("Título", "Sistema de Trabajos de Grado UTS"),
        ("Tecnología", "JSP + JSTL 1.2 (core, fmt, functions, sql), empaquetado como WAR con Maven"),
        ("Servidor de aplicaciones", "Apache Tomcat 8.5.96 (XAMPP) — compatible con Tomcat 9"),
        ("Base de datos", "MariaDB 10.4.32 / MySQL (XAMPP), base `db_tgd_uts`"),
        ("Lenguaje de programación", "Java (JDK 17 como destino de compilación; build verificada con JDK 21)"),
        ("Entorno de pruebas", "http://localhost:8080/tguts — 99/99 pruebas E2E aprobadas el 22/10/2026"),
        ("Versión del documento", "2.0 (22/10/2026)"),
        ("Autores", "Integrantes del equipo de desarrollo (2.º corte — Programación en Java)"),
        ("Tutor / docente", "Docente de la asignatura Programación en Java"),
    ], tam=10)
    doc.add_paragraph()
    parrafo(doc,
            "Nota: los usuarios, ideas, calendario y formatos incluidos en la base de datos son "
            "datos de demostración y no corresponden a información oficial de la institución.",
            tam=9.5, cursiva=True, alineacion=WD_ALIGN_PARAGRAPH.CENTER, color=GRIS)
    salto_pagina(doc)

    # --------------------------------------------------------------- índice
    titulo(doc, "Tabla de contenido", 1)
    parrafo(doc, "Para actualizar el índice en Word: clic derecho sobre la tabla → «Actualizar campos» → «Actualizar toda la tabla».",
            tam=9.5, cursiva=True, color=GRIS)
    p = doc.add_paragraph()
    campo(p, r'TOC \o "1-3" \h \z \u', "Índice (actualice los campos para generarlo).")
    salto_pagina(doc)

    # ----------------------------------------------------------- 1. Introducción
    titulo(doc, "1. Introducción", 1)
    titulo(doc, "1.1 Antecedentes", 2)
    parrafo(doc,
            "La Universidad Tecnológica de Santander ejecuta mensualmente el proceso de trabajos de grado. "
            "El seguimiento de ese proceso se realiza hoy de forma manual: el docente publica ideas de investigación, "
            "el estudiante escribe su anteproyecto, el director y el evaluador califican, se revisa el documento final, "
            "se programa la sustentación y, en paralelo, se atienden trámites de retiro, prórroga y beneficios. "
            "Esa gestión manual concentra la información en correos, documentos sueltos y hojas de cálculo, "
            "lo que dificulta saber en qué estado está cada proyecto y quién es responsable de la siguiente acción.")
    titulo(doc, "1.2 Problemática", 2)
    parrafo(doc,
            "El proceso de trabajos de grado concentra información sensible (datos de estudiantes, notas, estados de "
            "avance) que hoy no está centralizada. De esa situación se derivan cinco problemas concretos:")
    vinetas(doc, [
        "No existe un registro único que permita saber, en un momento dado, en qué estado se encuentra cada anteproyecto.",
        "La asignación de director y evaluador se realiza de forma manual, lo que genera retrasos en el arranque de los trabajos y permite asignaciones inconsistentes.",
        "Las calificaciones y las correcciones del documento final quedan dispersas, sin historial auditable.",
        "Los informes de avance se elaboran a mano, con el riesgo de error y con demora para la toma de decisiones.",
        "No hay control de acceso por rol: cualquier persona con un enlace puede consultar información de otros estudiantes.",
    ])
    titulo(doc, "1.3 Justificación", 2)
    parrafo(doc,
            "Una aplicación web centralizada resuelve los cinco problemas anteriores: un único repositorio con el estado "
            "de cada proyecto, la validación en el servidor de cada transición, el registro histórico de calificaciones, "
            "los informes calculados en el momento de consultarlos y el control de acceso por rol y por propiedad. "
            "El proyecto se desarrolla con JSP y JSTL, tecnologías que el curso trabaja de forma transversal y que "
            "permiten construir la lógica de negocio íntegramente en la capa de presentación, sin depender "
            "de frameworks de aplicación adicionales.")
    titulo(doc, "1.4 Objetivos", 2)
    parrafo(doc, "Objetivo general", negrita=True)
    parrafo(doc,
            "Desarrollar e poner en funcionamiento una aplicación web que gestione de extremo a extremo el proceso de "
            "trabajos de grado de la UTS: publicación de ideas, registro y aprobación del anteproyecto, asignación de "
            "director y evaluador, entrega y revisión del documento final, sustentación, trámites, calendario, "
            "formatos e informes, con control de acceso por rol y trazabilidad de cada acción.")
    parrafo(doc, "Objetivos específicos", negrita=True)
    agregar_tabla(doc, ["#", "Objetivo específico", "Requisito asociado"], [
        ("1", "Autenticar a los usuarios y construir el panel inicial y el menú según su rol.", "RF-01, RF-02, RF-03 / RNF-02"),
        ("2", "Administrar las cuentas del sistema (alta, edición, consulta y baja con control de dependencias).", "RF-04 … RF-08"),
        ("3", "Gestionar el banco de ideas y permitir que el estudiante seleccione una para iniciar su anteproyecto.", "RF-09 … RF-13, RF-25"),
        ("4", "Registrar, enviar, consultar y corregir el anteproyecto del estudiante.", "RF-14, RF-15, RF-16, RF-36"),
        ("5", "Permitir que el director califique, apruebe o rechace el anteproyecto que dirige.", "RF-17 … RF-20, RF-35"),
        ("6", "Permitir que el evaluador califique y apruebe el anteproyecto que le asignan.", "RF-21 … RF-24, RF-35"),
        ("7", "Brindar a la coordinación la búsqueda de estudiantes y la asignación de director y evaluador.", "RF-26, RF-27, RF-28"),
        ("8", "Generar los informes de estado por estudiante, director y evaluador.", "RF-29, RF-30, RF-31"),
        ("9", "Gestionar la entrega del documento final, su corrección y su revisión.", "RF-36, RF-41"),
        ("10", "Programar la sustentación y registrar su resultado.", "RF-34, RF-42, RF-43"),
        ("11", "Ofrecer el calendario académico y los formatos de grado con su administración.", "RF-32, RF-33"),
        ("12", "Registrar y consultar los trámites de retiro, prórroga y beneficio.", "RF-38, RF-39, RF-40"),
        ("13", "Notificar cada evento del proceso a los interesados.", "RF-37"),
        ("14", "Verificar el sistema con una suite de pruebas end-to-end ejecutadas sobre el despliegue real.", "RNF-01 … RNF-10"),
    ], tam=9.5)
    titulo(doc, "1.5 Alcance", 2)
    parrafo(doc,
            "El sistema cubre el ciclo completo del trabajo de grado, desde la publicación de ideas hasta el cierre del "
            "proyecto en estado `FINALIZADO`. Cubre los cinco roles de la institución: administración, coordinación, "
            "dirección, evaluación y estudiante. Los documentos (anteproyecto y documento final) se registran por enlace "
            "(URL) y no se almacenan en el servidor.")
    titulo(doc, "1.6 Limitaciones del alcance", 2)
    vinetas(doc, [
        "El envío real de correo electrónico (SMTP) no está implementado: las notificaciones se registran en la base de datos y se muestran en la bandeja del usuario.",
        "No se realiza la carga de archivos: la decisión «dejar solo URL y documentar» fue tomada con el docente y la infraestructura heredada se conserva para registros antiguos.",
        "Los contenidos iniciales (usuarios, ideas, calendario y formatos) son datos de demostración y deben reemplazarse por los oficiales.",
    ])

    # ------------------------------------------------------ 2. Marco referencial
    titulo(doc, "2. Marco referencial", 1)
    titulo(doc, "2.1 JavaServer Pages (JSP)", 2)
    parrafo(doc,
            "JSP es una tecnología de la especificación Java EE que permite construir páginas web dinámicas combinando "
            "HTML con Java. El motor de JSP traduce la página a un servlet en el momento de la primera petición, por lo que "
            "el código generado es tan rápido como el de un servlet escrito a mano, con la ventaja de que la presentación y la "
            "lógica conviven en un mismo archivo. En este proyecto JSP es el pilar de la arquitectura: la lógica de negocio "
            "—consultas, validaciones, transacciones y control de sesión— reside en los archivos `.jsp`.")
    titulo(doc, "2.2 JavaServer Pages Tag Library (JSTL)", 2)
    parrafo(doc,
            "JSTL es la biblioteca de etiquetas estándar que evita el Java embebido (`<% %>`) dentro de las páginas. "
            "El proyecto utiliza cuatro librerías:")
    agregar_tabla(doc, ["Librería", "URI", "Uso en el sistema"], [
        ("Core", "http://java.sun.com/jsp/jstl/core", "Variables, condicionales, iteraciones y funciones de lógica (`fn:`)."),
        ("SQL", "http://java.sun.com/jsp/jstl/sql", "Consultas parametrizadas (`<sql:query>`, `<sql:param>`, `<sql:update>`) y transacciones (`<sql:transaction>`)."),
        ("Fmt", "http://java.sun.com/jsp/jstl/fmt", "Formateo de fechas y números en las tablas y en las notificaciones."),
        ("Functions", "http://java.sun.com/jsp/jstl/functions", "Funciones de cadena: `fn:escapeXml` (escapado de la salida), `fn:startsWith`, `fn:contains`, `fn:trim`."),
    ], tam=9.5)
    titulo(doc, "2.3 Modelo arquitectónico", 2)
    parrafo(doc,
            "La aplicación aplica una arquitectura de tres capas lógicas sobre JSP, en la línea del patrón MVC:")
    agregar_tabla(doc, ["Capa", "Ubicación en el proyecto", "Responsabilidad"], [
        ("Presentación", "`src/main/webapp/*.jsp`, `css/style.css`", "Interfaces, formularios, navegación por rol y mensajes al usuario."),
        ("Lógica de negocio", "Bloques `<sql:query>` / `<sql:update>` de las páginas y `common/*.jsp`", "Validaciones de rol, propiedad y estado; persistencia y notificaciones."),
        ("Datos", "`sql/db_tgd_uts.sql`, pool HikariCP (`PoolInicializador`)", "Esquema relacional, índices, restricciones y conexiones agrupadas."),
    ], tam=9.5)
    titulo(doc, "2.4 Componentes de infraestructura", 2)
    agregar_tabla(doc, ["Componente", "Detalle"], [
        ("Contenedor de servlets", "Apache Tomcat 8.5.96 (verificado) y 9 (compatible), con `javax.servlet`."),
        ("Gestor de dependencias", "Maven 3.6+; empaquetado `war`; `maven.compiler.release=17`."),
        ("Pool de conexiones", "HikariCP 5 con MySQL Connector/J 8.3, inicializado por `edu.uts.PoolInicializador` (única clase Java del proyecto)."),
        ("Configuración", "Variables de entorno (`DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`); sin ellas usa XAMPP (`localhost`, `root`, sin contraseña)."),
        ("Seguridad de sesión", "`web.xml` (timeout de 30 min, `tracking-mode=COOKIE`) y `META-INF/context.xml` (cookie `HttpOnly`, `SameSite=Lax`)."),
    ], tam=9.5)
    titulo(doc, "2.5 Modelo de desarrollo", 2)
    parrafo(doc,
            "El proyecto sigue un ciclo iterativo incremental: cada bloque funcional (autenticación, usuarios, ideas, "
            "anteproyyecto, evaluación, entrega final, sustentación, módulos complementarios) se implementa, se despliega y "
            "se valida antes de pasar al siguiente. La validación final se apoyó en una suite end-to-end de 99 casos "
            "ejecutada contra el despliegue real, cuyo registro se conserva en TEST_RESULTS.md.")

    # ------------------------------------------------------- 3. Requisitos
    titulo(doc, "3. Análisis de requisitos", 1)
    titulo(doc, "3.1 Roles del sistema", 2)
    render_markdown(doc, seccion(readme, "## Usuarios de demostración"), desplazamiento=0)
    titulo(doc, "3.2 Requisitos funcionales", 2)
    parrafo(doc,
            "El catálogo unificado RF-01 … RF-43 se mantiene sincronizado con los comentarios del código fuente; "
            "cada página JSP indica los requisitos que implementa.", cursiva=True, tam=10)
    seccion_rf = seccion(readme, "### Catálogo de requisitos funcionales")
    # se reconstruye como tabla de dos columnas para mejor legibilidad
    filas_rf = []
    for linea in seccion_rf.split("\n"):
        s = linea.strip()
        if not s.startswith("|"):
            continue
        celdas = [c.strip() for c in s.strip("|").split("|")]
        if len(celdas) < 4:
            continue
        for cod, descripcion in ((celdas[0], celdas[1]), (celdas[2], celdas[3])):
            if re.match(r"^(RF|RNF)-\d+$", cod):
                filas_rf.append((cod, descripcion))
    filas_rf.sort(key=lambda f: (0 if f[0].startswith("RF") else 1,
                                 int(re.sub(r"\D", "", f[0]))))
    filas_rf2 = []
    for i in range(0, len(filas_rf), 2):
        izq = filas_rf[i]
        der = filas_rf[i + 1] if i + 1 < len(filas_rf) else ("", "")
        filas_rf2.append((izq[0], izq[1], der[0], der[1]))
    agregar_tabla(doc, ["RF", "Descripción", "RF", "Descripción"], filas_rf2, tam=9)
    titulo(doc, "3.3 Requisitos no funcionales", 2)
    agregar_tabla(doc, ["Código", "Categoría", "Definición", "Evidencia de implementación"],
                  [(a, b, c, d) for a, b, c, d in REQUISITOS_NO_FUNCIONALES], tam=9)
    titulo(doc, "3.4 Reglas de negocio", 2)
    agregar_tabla(doc, ["Código", "Regla", "Requisito relacionado"],
                  [(a, b, c) for a, b, c in REGLAS_NEGOCIO], tam=9)

    # ---------------------------------------------------- 4. Historias de usuario
    titulo(doc, "4. Historias de usuario", 1)
    parrafo(doc,
            "Cada historia se deriva de un requisito funcional del catálogo y se valida con los casos end-to-end "
            "correspondientes del capítulo de pruebas.")
    agregar_tabla(doc, ["ID", "Historia", "Rol", "Narrativa", "Criterio de aceptación", "RF / RNF"],
                  HISTORIAS_USUARIO, tam=8.5)

    # --------------------------------------------------- 5. Modelo del sistema
    titulo(doc, "5. Modelado del sistema", 1)
    titulo(doc, "5.1 Modelo de datos", 2)
    render_markdown(doc, seccion(tecnica, "## 2. Esquema de base de datos"), desplazamiento=0)
    titulo(doc, "5.2 Catálogo de tablas", 2)
    agregar_tabla(doc, ["Tabla", "Descripción", "Clave"], [
        ("usuarios", "Cuentas del sistema con su rol, código de matrícula y estado.", "PK `id` · UNIQUE `email`"),
        ("ideas", "Banco de ideas de trabajo de grado publicadas por los docentes.", "PK `id` · FK `docente_id`"),
        ("anteproyectos", "Núcleo del proceso: idea, director, evaluador, estado y calificaciones.", "PK `id` · UNIQUE `estudiante_id`"),
        ("entrega_final", "Documento final del trabajo de grado (1:1 con el anteproyecto).", "PK `id` · UNIQUE `anteproyecto_id`"),
        ("sustentacion", "Acto de sustentación: fecha, hora, lugar y resultado.", "PK `id` · UNIQUE `anteproyecto_id`"),
        ("calificaciones", "Historial auditable de calificaciones de director y evaluador.", "PK `id` · FK `anteproyecto_id`, `usuario_id`"),
        ("notificaciones", "Avisos automáticos del proceso dirigidos a cada usuario.", "PK `id` · FK `usuario_id`"),
        ("calendario", "Hitos y fechas del proceso académico.", "PK `id`"),
        ("formatos", "Formatos de grado (plantillas base) con su enlace al documento.", "PK `id`"),
        ("tramites", "Solicitudes de retiro, prórroga y beneficio de los estudiantes.", "PK `id` · FK `estudiante_id`"),
    ], tam=9)
    titulo(doc, "5.3 Máquina de estados del anteproyecto", 2)
    codigo(doc, """BORRADOR
   |  (el estudiante envía con director válido + URL)
   v
ENVIADO
   |  (el director califica + aprueba)
   v
APROBADO_DIRECTOR
   |  (se asigna un evaluador; evalúa + aprueba)
   v
APROBADO_EVALUADOR
   |  (el estudiante entrega el documento final por URL)
   v
ENTREGA_DOCUMENTO_FINAL
   |  (el revisor aprueba el documento)
   v
REVISIÓN_FINAL
   |  (la coordinación programa la sustentación)
   v
SUSTENTACIÓN
   |  (resultado APROBADO)
   v
FINALIZADO

RECHAZADO  --->  el estudiante corrige y vuelve a ENVIADO
OBSERVADO (documento final) --->  el estudiante corrige y reenvía""")
    parrafo(doc,
            "Las transiciones legítimas están garantizadas con guardas del tipo `AND estado = '...'` en cada instrucción "
            "`UPDATE`, de modo que un reenvío de una petición o una acción fuera de estado no produce efectos.", tam=10)
    titulo(doc, "5.4 Casos de uso principales", 2)
    agregar_tabla(doc, ["Caso de uso", "Actor principal", "Actores secundarios", "Precondición", "Resultado"], [
        ("UC-01 Iniciar sesión", "Usuario", "—", "Cuenta activa", "Sesión iniciada según el rol"),
        ("UC-02 Crear usuario", "Administrador", "—", "Administrador autenticado", "Usuario creado"),
        ("UC-03 Publicar idea", "Director / Evaluador", "Administración", "Docente con rol válido", "Idea `PUBLICADA`"),
        ("UC-04 Seleccionar idea", "Estudiante", "—", "Idea disponible y sin anteproyecto previo", "Anteproyecto `BORRADOR`"),
        ("UC-05 Enviar anteproyecto", "Estudiante", "Director", "Borrador con director válido", "Anteproyecto `ENVIADO` + notificación"),
        ("UC-06 Calificar y aprobar (director)", "Director", "Estudiante, Evaluador", "Anteproyecto `ENVIADO`", "`APROBADO_DIRECTOR` + evaluador asignado"),
        ("UC-07 Calificar y aprobar (evaluador)", "Evaluador", "Estudiante, Coordinación", "`APROBADO_DIRECTOR`", "`APROBADO_EVALUADOR`"),
        ("UC-08 Buscar estudiante y asignar equipo", "Coordinación", "Director, Evaluador", "Anteproyecto existente", "Director/evaluador actualizados"),
        ("UC-09 Entregar documento final", "Estudiante", "Director", "`APROBADO_EVALUADOR`", "Entrega `ENTREGADO`"),
        ("UC-10 Revisar documento final", "Director / Coordinación", "Estudiante", "Documento entregado", "Entrega observada / revisada / aprobada"),
        ("UC-11 Programar sustentación", "Coordinación", "—", "`REVISIÓN_FINAL`", "Acto registrado, estado `SUSTENTACIÓN`"),
        ("UC-12 Registrar resultado", "Director / Evaluador", "Estudiante", "Sustentación programada", "Estado `FINALIZADO` o `RECHAZADO`"),
        ("UC-13 Generar informes", "Administración / Coordinación", "—", "Anteproyectos registrados", "Informe con el estado real"),
        ("UC-14 Solicitar y resolver trámite", "Estudiante / Coordinación", "—", "Usuario autenticado", "Trámite resuelto con respuesta"),
    ], tam=9)

    # ---------------------------------------------------- 6. Arquitectura
    titulo(doc, "6. Arquitectura y diseño", 1)
    titulo(doc, "6.1 Estructura del proyecto", 2)
    render_markdown(doc, seccion(readme, "## Estructura del proyecto"), desplazamiento=0)
    titulo(doc, "6.2 Módulos de la aplicación", 2)
    render_markdown(doc, seccion(readme, "### Módulos principales"), desplazamiento=0)
    titulo(doc, "6.3 Capa común (`common/`)", 2)
    agregar_tabla(doc, ["Archivo", "Responsabilidad"], [
        ("`config.jsp`", "DataSource desde el pool, lectura del cuerpo POST en el Map `campos` y detección de `multipart`."),
        ("`guard.jsp`", "Guarda de sesión: recupera `sessionScope.usuario` y `rol`; redirección a `login.jsp` si no hay sesión."),
        ("`seguridad.jsp`", "PBKDF2-HMAC-SHA256 (`pgHash`), comparación en tiempo constante y migración de hashes SHA-256 heredados."),
        ("`csrf.jsp` / `verify_csrf.jsp`", "Generación del token por sesión y validación de **todo** POST (incluidos formularios `multipart`)."),
        ("`menu.jsp`", "Menú lateral construido según el rol (RNF-02) y contador de notificaciones no leídas."),
        ("`estado.jsp`", "Etiqueta visual del estado del anteproyecto."),
        ("`resolver.jsp` / `resolver_idea.jsp`", "Resolución de nombres de usuario e idea a partir de sus identificadores."),
        ("`header.jsp` / `footer.jsp`", "Encabezado, pie de página y datos de la institución."),
    ], tam=9.5)
    titulo(doc, "6.4 Mecanismo de seguridad", 2)
    render_markdown(doc, seccion(tecnica, "## 4. Seguridad"), desplazamiento=0)
    titulo(doc, "6.5 Decisiones de diseño", 2)
    render_markdown(doc, seccion(tecnica, "## 5. Decisiones de diseño documentadas"), desplazamiento=0)

    # ------------------------------------------------------ 7. Plan de trabajo
    titulo(doc, "7. Plan de trabajo", 1)
    parrafo(doc,
            "El proyecto se ejecutó en ocho fases. La tabla resume las actividades, los entregables de cada fase, "
            "la duración estimada y el estado real de avance al cierre del proyecto.")
    agregar_tabla(doc, ["Fase", "Actividad", "Descripción de las tareas", "Entregable", "Duración", "Responsable", "Estado"],
                  PLAN_TRABAJO, tam=8.5)
    titulo(doc, "7.1 Tareas de operación y mantenimiento", 2)
    agregar_tabla(doc, ["Tarea", "Comando", "Detalle"], TAREAS_OPERACION, tam=9)

    # --------------------------------------------------- 8. Guion de demostración
    titulo(doc, "8. Guion de demostración", 1)
    parrafo(doc,
            "El siguiente guion reproduce, paso a paso, la demostración del sistema con las cinco cuentas de rol. "
            "Cada paso indica la acción a realizar y el resultado verificado en la ejecución real de las pruebas.")
    render_markdown(doc, guion, desplazamiento=0, saltar_h1=True)

    # -------------------------------------------------------- 9. Pruebas
    titulo(doc, "9. Pruebas del sistema", 1)
    titulo(doc, "9.1 Estrategia de pruebas", 2)
    parrafo(doc,
            "La validación se realiza mediante pruebas funcionales end-to-end: un script automatizado que se autentica "
            "como cada rol, ejecuta la operación sobre la interfaz real (formularios, botones y enlaces) y contrasta el "
            "resultado contra el estado de la base de datos. Este tipo de prueba es el adecuado para el proyecto porque "
            "verifica de forma simultánea la interfaz, las reglas de negocio, la persistencia y los mensajes al usuario.")
    parrafo(doc,
            "La suite se organizó en quince bloques (A–O) con 99 casos, cubrió el flujo completo hasta la aprobación del "
            "documento final y la finalización del trabajo de grado, y se ejecutó de forma aislada: creaba sus propias cuentas "
            "(`e2e-<rol>@uts.edu.co`) y las eliminaba al terminar, de modo que los datos de demostración permanecían intactos. "
            "Los scripts se retiraron del repositorio; el detalle caso por caso se conserva en TEST_RESULTS.md.",
            tam=10)
    titulo(doc, "9.2 Entorno de ejecución", 2)
    agregar_tabla(doc, ["Elemento", "Detalle"], [
        ("Fecha de la ejecución", "22/10/2026 09:49:39"),
        ("Aplicación probada", "http://localhost:8080/tguts (contexto WAR `tguts`)"),
        ("Servidor de aplicaciones", "Apache Tomcat 8.5.96 (XAMPP, `C:\\xampp\\tomcat`)"),
        ("Base de datos", "MariaDB 10.4.32 (XAMPP, puerto 3306), base `db_tgd_uts`"),
        ("Compilación", "Maven con JDK 21, `maven.compiler.release=17`"),
        ("Suite de pruebas", "E2E propia en Python 3 (solo librería estándar), hoy retirada del repositorio"),
        ("Evidencia", "Salida íntegra de la ejecución (archivo retirado del repositorio)"),
        ("Resultado", "99/99 APROBADOS en 66,2 s"),
    ], tam=9.5)
    titulo(doc, "9.3 Resultado global", 2)
    agregar_tabla(doc, ["Indicador", "Valor"], [
        ("Casos ejecutados", "99"),
        ("Casos aprobados", "99"),
        ("Casos fallidos", "0"),
        ("Duración de la suite", "66,2 segundos"),
        ("Cobertura funcional", "Login y seguridad · usuarios · ideas · anteproyecto · dirección · búsqueda · asignación · evaluación · informes · entrega final y sustentación · calendario · formatos · trámites · notificaciones · limpieza"),
        ("Integridad de los datos", "Verificada por el caso O-01: la base queda con 6 usuarios, 3 ideas, 2 formatos, 3 eventos y 0 anteproyectos"),
        ("Evidencia conservada", "Salida de la ejecución del 22/10/2026 (retirada del repositorio)"),
    ], tam=9.5)
    titulo(doc, "9.4 Resultados caso por caso", 2)

    # --- se arma la tabla de 99 casos a partir de la salida real
    filas_casos = []
    for linea in evidencia.split("\n"):
        if not (linea.startswith("APROBADO") or linea.startswith("FALLO")):
            continue
        partes = linea.split(" | ", 2)
        if len(partes) < 3:
            continue
        estado = partes[0].strip()
        titulo_caso = partes[1].strip()
        detalle = partes[2].strip()
        if ":" in titulo_caso:
            cabeza, desc = titulo_caso.split(":", 1)
        else:
            cabeza, desc = titulo_caso, ""
        palabras = cabeza.strip().split()
        ident = palabras[0] if palabras else ""
        bloque = " ".join(palabras[1:])
        descripcion = ("%s: %s" % (bloque, desc.strip())).strip(": ").strip() if bloque else desc.strip()
        filas_casos.append((ident.strip(), descripcion, detalle, estado))
    if filas_casos:
        titulo(doc, "9.4.1 Bloques A a E — acceso, usuarios, ideas, anteproyecto y dirección", 3)
        agregar_tabla(doc, ["Caso", "Descripción", "Evidencia observada", "Resultado"],
                      [f for f in filas_casos if re.match(r"^[A-E]-\d+$", f[0])], tam=8)
        titulo(doc, "9.4.2 Bloques F a J — búsqueda, asignación, evaluación, informes, entrega final y sustentación", 3)
        agregar_tabla(doc, ["Caso", "Descripción", "Evidencia observada", "Resultado"],
                      [f for f in filas_casos if re.match(r"^[F-J]-\d+$", f[0])], tam=8)
        titulo(doc, "9.4.3 Bloques K a O — calendario, formatos, trámites, notificaciones y limpieza", 3)
        agregar_tabla(doc, ["Caso", "Descripción", "Evidencia observada", "Resultado"],
                      [f for f in filas_casos if re.match(r"^[K-O]-\d+$", f[0])], tam=8)
    else:
        parrafo(doc,
                "La tabla caso por caso se generaba a partir de la salida de la suite E2E; ese archivo se retiró del "
                "repositorio. El detalle de los 99 casos y sus resultados se conserva en TEST_RESULTS.md.",
                tam=10)

    titulo(doc, "9.5 Defectos detectados y corregidos", 2)
    parrafo(doc,
            "La suite no solo verifica el comportamiento esperado: en el proceso se detectaron y corrigieron trece "
            "defectos reales, documentados a continuación con su síntoma, su corrección y el caso que lo cubre.")
    render_markdown(doc, seccion(pruebas, "## 3. Detalles técnicos de los bugs corregidos"), desplazamiento=0)
    titulo(doc, "9.6 Aislamiento de los datos de prueba", 2)
    render_markdown(doc, seccion(pruebas, "## 5. Aislamiento de los datos de prueba"), desplazamiento=0)
    titulo(doc, "9.7 Cobertura del flujo completo", 2)
    agregar_tabla(doc, ["Etapa", "Casos que la cubren", "Estado verificado"], [
        ("Inicio de sesión y control de acceso", "A-01 … A-12", "Correcto"),
        ("Alta, edición y baja de usuarios", "B-01 … B-09", "Correcto"),
        ("Publicación y gestión del banco de ideas", "C-01 … C-07", "Correcto"),
        ("Registro, envío y corrección del anteproyecto", "D-01 … D-10, E-07", "Correcto"),
        ("Calificación y aprobación del director", "E-01 … E-05", "Correcto"),
        ("Búsqueda de estudiantes y ficha", "F-01 … F-05", "Correcto"),
        ("Asignación de director y evaluador", "G-01 … G-05", "Correcto"),
        ("Calificación y aprobación del evaluador", "H-01 … H-04", "Correcto"),
        ("Informes de estado", "I-01 … I-04", "Correcto"),
        ("Entrega, corrección y revisión del documento final", "J-01 … J-10", "Correcto"),
        ("Sustentación y finalización del proyecto", "J-11, J-14, J-15", "Correcto"),
        ("Cierre del documento en estados avanzados", "J-12, J-13, J-16", "Correcto"),
        ("Calendario y formatos", "K-01 … K-05, L-01 … L-06", "Correcto"),
        ("Trámites y notificaciones", "M-01 … M-04, N-01 … N-03", "Correcto"),
        ("Restauración de la base de datos", "O-01", "Correcto"),
    ], tam=9)

    # ------------------------------------------------------ 10. Despliegue
    titulo(doc, "10. Despliegue y operación", 1)
    titulo(doc, "10.1 Entorno local verificado (XAMPP)", 2)
    agregar_tabla(doc, ["Paso", "Acción", "Detalle"], [
        ("1", "Iniciar MySQL/MariaDB de XAMPP", "Servicio en `localhost:3306`, usuario `root` sin contraseña."),
        ("2", "Crear la base de datos", "`C:\\xampp\\mysql\\bin\\mysql.exe -uroot -e \"source tguts/sql/db_tgd_uts.sql\"` → base `db_tgd_uts`."),
        ("3", "Compilar y desplegar", "`cd tguts && mvn clean package` → copiar `tguts.war` a `C:\\xampp\\tomcat\\webapps\\` y reiniciar Tomcat."),
        ("4", "Acceder", "`http://localhost:8080/tguts/`"),
    ], tam=9.5)
    titulo(doc, "10.2 Alternativa documentada con Docker (no ejecutada en esta versión)", 2)
    parrafo(doc,
            "El repositorio incluye un `Dockerfile` (Tomcat 9 + WAR) para levantar la aplicación en un contenedor en el "
            "puerto 18080. Esta variante queda documentada como alternativa; la verificación de esta versión se realizó "
            "en el entorno local XAMPP descrito en el apartado anterior.",
            tam=10)
    codigo(doc, """docker network create tguts_net
docker run -d --name tguts-mysql --network tguts_net \\
  -e MYSQL_ROOT_PASSWORD=rootpw -e MYSQL_DATABASE=db_tgd_uts \\
  -v "%CD%\\tguts\\sql\\db_tgd_uts.sql:/docker-entrypoint-initdb.d/01.sql:ro" mysql:8.0
cd tguts && mvn -B clean package
docker run -d --name tguts-tomcat --network tguts_net -p 18080:8080 \\
  -e DB_HOST=tguts-mysql -e DB_PORT=3306 -e DB_NAME=db_tgd_uts \\
  -e DB_USER=root -e DB_PASSWORD=rootpw \\
  -v "%CD%\\tguts\\target\\tguts.war:/usr/local/tomcat/webapps/ROOT.war:ro" \\
  tomcat:9.0-jdk17-temurin""")
    titulo(doc, "10.3 Despliegue en la nube", 2)
    render_markdown(doc, seccion(readme, "## Despliegue en la nube (Render)"), desplazamiento=0)

    # ---------------------------------------------------- 11. Conclusiones
    titulo(doc, "11. Conclusiones", 1)
    parrafo(doc,
            "El sistema centraliza la gestión del proceso de trabajos de grado y cumple los objetivos propuestos: "
            "los cinco roles disposent de un módulo propio, cada transición del proceso está validada en el servidor y "
            "queda registrada, y la información de avance está disponible en el momento en que se necesita. "
            "La verificación con 99 casos end-to-end ejecutados sobre el despliegue real confirma que el comportamiento "
            "implementado coincide con el especificado en los requisitos funcionales y no funcionales.")
    parrafo(doc,
            "Como trabajo académico, el proyecto mostró el valor de separar la lógica de negocio de la presentación: "
            "las reglas se concentran en las guardas de estado, de rol y de propiedad, y los JSP se limitan a presentar "
            "el resultado. Entre las decisiones con mayor impacto se cuentan el registro de documentos por URL, que "
            "elimina la dependencia del sistema de archivos del servidor, y el aislamiento de la suite de pruebas, que "
            "permite ejecutar la validación completa sin alterar los datos de demostración.")

    titulo(doc, "12. Referencias", 1)
    vinetas(doc, [
        "Oracle. JavaServer Pages (JSP) Specification. Jakarta EE.",
        "Oracle. JavaServer Pages Tag Library (JSTL) Specification.",
        "Apache Software Foundation. Apache Tomcat 9 User Guide.",
        "MariaDB Foundation / Oracle. MySQL 8.0 Reference Manual.",
        "Spring Framework Team. HikariCP — A fast, lightweight, and highly configurable connection pool.",
        "Oracle. MySQL Connector/J — Official MySQL JDBC driver documentation.",
        "Apache Software Foundation. Apache Maven — Introduction to the Build System.",
        "OWASP Foundation. OWASP Top 10 (identificador y gestión de sesiones, control de acceso, validación de entradas).",
        "Universidad Tecnológica de Santander. Documentos internos del proceso de trabajos de grado (referencia institucional del proyecto).",
    ])

    # ---------------------------------------------------------- Anexos
    salto_pagina(doc)
    titulo(doc, "Anexo A. Usuarios de demostración", 1)
    render_markdown(doc, seccion(readme, "## Usuarios de demostración"), desplazamiento=0)
    titulo(doc, "Anexo B. Extracto de la evidencia de la ejecución", 1)
    if evidencia:
        parrafo(doc,
                "Extracto de la cabecera y de los últimos casos de la salida de la suite:",
                tam=10)
        lineas_ev = [l for l in evidencia.split("\n") if l.strip()]
        extracto = "\n".join(lineas_ev[:6] + ["   ..."] + lineas_ev[-6:])
        codigo(doc, extracto, tam=8)
    else:
        parrafo(doc,
                "La salida íntegra de la ejecución del 22/10/2026 (99/99 APROBADOS) se generó con la suite E2E y se "
                "retiró del repositorio junto con los scripts. El detalle caso por caso se conserva en TEST_RESULTS.md.",
                tam=10)
    titulo(doc, "Anexo C. Documentación del repositorio", 1)
    agregar_tabla(doc, ["Archivo", "Contenido"], [
        ("`README.md`", "Puesta en marcha, usuarios, catálogo de requisitos, despliegue y notas."),
        ("`GUION.md`", "Guion de demostración paso a paso (todas las acciones en tablas)."),
        ("`TEST_RESULTS.md`", "Registro histórico de las 99 pruebas y detalle de los defectos corregidos."),
        ("`DOCUMENTACION_TECNICA.md`", "Arquitectura, esquema de la base de datos, seguridad y decisiones de diseño."),
        ("`tguts/sql/db_tgd_uts.sql`", "Esquema completo y datos de demostración."),
    ], tam=9.5)

    os.makedirs(DOCS, exist_ok=True)
    doc.save(SALIDA)
    print("Documento generado:", SALIDA)
    print("Casos incluidos:", len(filas_casos))
    return SALIDA


def solo_zip():
    """Reconstruye el paquete .zip sin volver a generar el .docx."""
    zip_salida = os.path.join(RAIZ, "Sistema_Trabajos_de_Grado_UTS.zip")
    incluidos = [
        "README.md", "GUION.md", "TEST_RESULTS.md", "DOCUMENTACION_TECNICA.md",
        "tguts/sql/db_tgd_uts.sql", "tguts/sql/migracion_seguridad.sql",
        "tguts/pom.xml",
    ]
    with zipfile.ZipFile(zip_salida, "w", zipfile.ZIP_DEFLATED) as z:
        docx = os.path.join(DOCS, "Sistema_Trabajos_de_Grado_UTS.docx")
        if os.path.exists(docx):
            z.write(docx, os.path.basename(docx))
        pdf = os.path.join(DOCS, "Sistema_Trabajos_de_Grado_UTS.pdf")
        if os.path.exists(pdf):
            z.write(pdf, os.path.basename(pdf))
        z.write(os.path.join(RAIZ, "docs", "generar_informe.py"), "generar_informe.py")
        for rel in incluidos:
            ruta = os.path.join(RAIZ, rel)
            if os.path.exists(ruta):
                z.write(ruta, rel.replace("/", "\\"))
    print("Paquete generado:", zip_salida)


if __name__ == "__main__":
    if "--solo-zip" not in sys.argv:
        construir()
    solo_zip()