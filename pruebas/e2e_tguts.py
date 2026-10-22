#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Pruebas end-to-end reales del Sistema de Trabajos de Grado UTS (JSP + JSTL).
Version Docker: Tomcat 9 + MySQL 8 levantados con Docker Compose.

Uso:
    python pruebas/e2e_tguts.py [url_base] [--mysql-container NOMBRE]

Por defecto:  url_base = http://localhost:18080/tguts
              contenedor MySQL = tguts-mysql

Los casos de prueba estan en pruebas/e2e_core.py; este archivo solo aporta la
forma de consultar la base de datos dentro del contenedor y ejecuta la suite
completa, guardando la salida en pruebas/salida_e2e_tguts.txt como evidencia.
"""
import io
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import e2e_core  # noqa: E402

BASE = "http://localhost:18080/tguts"
MYSQL = "tguts-mysql"
BASE_DE_DATOS = "db_tgd_uts"


def db(sql):
    """Ejecuta SQL en el contenedor MySQL y devuelve la primera fila (TSV)."""
    proc = subprocess.run(
        ["docker", "exec", MYSQL, "mysql", "-uroot", "-prootpw", "-N", "-B",
         "--default-character-set=utf8mb4", BASE_DE_DATOS, "-e", sql],
        capture_output=True, encoding="utf-8", errors="replace")
    salida = (proc.stdout or "").strip().splitlines()
    return salida[0].strip() if salida else ""


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

    inicio = time.time()
    resultados = e2e_core.run(db, BASE)
    duracion = time.time() - inicio

    total = len(resultados)
    aprobados = sum(1 for _, ok, _ in resultados if ok)
    print("\nDuracion de la suite: %.1f s" % duracion)

    # Evidencia: se guarda la salida completa de esta ejecucion.
    archivo = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           "salida_e2e_tguts.txt")
    with io.open(archivo, "w", encoding="utf-8") as f:
        f.write("SALIDA REAL DE LAS PRUEBAS END-TO-END\n")
        f.write("Sistema de Trabajos de Grado UTS (JSP + JSTL)\n")
        f.write("Ejecutado: %s\n" % time.strftime("%Y-%m-%d %H:%M:%S"))
        f.write("Aplicacion: %s\n" % BASE)
        f.write("Base de datos: contenedor MySQL '%s'\n" % MYSQL)
        f.write("Resultado: %d/%d APROBADOS en %.1f s\n\n"
                % (aprobados, total, duracion))
        for nombre, ok, evidencia in resultados:
            f.write(("APROBADO" if ok else "FALLO  ") + " | " + nombre + " | " + evidencia + "\n")
        f.write("\n===== RESUMEN: %d/%d APROBADOS =====\n" % (aprobados, total))
    print("Evidencia guardada en:", archivo)
    return 0 if aprobados == total else 1


if __name__ == "__main__":
    sys.exit(main())
