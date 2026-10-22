#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Pruebas end-to-end reales del Sistema de Trabajos de Grado UTS (JSP + JSTL).
Version local: XAMPP (MariaDB en el puerto 3306) + Tomcat 8.5 en el puerto 8080.

Uso:
    python pruebas/e2e_local.py [url_base]

Por defecto:  url_base = http://localhost:8080/tguts

Los casos de prueba estan en pruebas/e2e_core.py; este archivo solo aporta la
forma de consultar la base de datos de MySQL local (cliente de linea de
comandos de XAMPP) y ejecuta la suite completa, guardando la salida en
pruebas/salida_e2e_local.txt como evidencia de la ejecucion.
"""
import io
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import e2e_core  # noqa: E402

BASE = "http://localhost:8080/tguts"
MYSQL = r"C:\xampp\mysql\bin\mysql.exe"
BASE_DE_DATOS = "db_tgd_uts"


def db(sql):
    """Ejecuta SQL en el MySQL local de XAMPP y devuelve la primera fila."""
    proc = subprocess.run(
        [MYSQL, "-uroot", "-N", "-B", "--default-character-set=utf8mb4",
         BASE_DE_DATOS, "-e", sql],
        capture_output=True, encoding="utf-8", errors="replace")
    salida = (proc.stdout or "").strip().splitlines()
    return salida[0].strip() if salida else ""


def main():
    global BASE
    args = list(sys.argv[1:])
    if args:
        BASE = args[0]

    print("Base URL:", BASE, "| MySQL:", MYSQL)

    inicio = time.time()
    resultados = e2e_core.run(db, BASE)
    duracion = time.time() - inicio

    total = len(resultados)
    aprobados = sum(1 for _, ok, _ in resultados if ok)
    print("\nDuracion de la suite: %.1f s" % duracion)

    # Evidencia: se guarda la salida completa de esta ejecucion.
    archivo = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           "salida_e2e_local.txt")
    with io.open(archivo, "w", encoding="utf-8") as f:
        f.write("SALIDA REAL DE LAS PRUEBAS END-TO-END\n")
        f.write("Sistema de Trabajos de Grado UTS (JSP + JSTL)\n")
        f.write("Ejecutado: %s\n" % time.strftime("%Y-%m-%d %H:%M:%S"))
        f.write("Aplicacion: %s\n" % BASE)
        f.write("Base de datos: MySQL/MariaDB local de XAMPP (%s)\n" % BASE_DE_DATOS)
        f.write("Resultado: %d/%d APROBADOS en %.1f s\n\n"
                % (aprobados, total, duracion))
        for nombre, ok, evidencia in resultados:
            f.write(("APROBADO" if ok else "FALLO  ") + " | " + nombre + " | " + evidencia + "\n")
        f.write("\n===== RESUMEN: %d/%d APROBADOS =====\n" % (aprobados, total))
    print("Evidencia guardada en:", archivo)
    return 0 if aprobados == total else 1


if __name__ == "__main__":
    sys.exit(main())
