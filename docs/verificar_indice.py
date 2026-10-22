# -*- coding: utf-8 -*-
"""Comprueba que el índice (TOC) del .docx quedó generado con entradas."""
import re
import zipfile

z = zipfile.ZipFile(r"docs\Sistema_Trabajos_de_Grado_UTS.docx")
xml = z.read("word/document.xml").decode("utf-8")
patron = re.compile(r'<w:hyperlink w:anchor="_Toc[0-9]+".*?<w:t>(.*?)</w:t>', re.S)
entradas = patron.findall(xml)
print("Entradas de indice:", len(entradas))
for e in entradas[:10]:
    print("   ", e)
print("    ...")
for e in entradas[-5:]:
    print("   ", e)
