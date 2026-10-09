# Despliegue en Render

Guía para publicar **Sistema de Trabajos de Grado UTS** (JSP + JSTL sobre Tomcat 9)
usando **Render** para la app y **Clever Cloud** para la base de datos MySQL.

> ⚠️ **Vercel no sirve para este proyecto.** Vercel solo hospeda sitios estáticos y
> funciones serverless (Node/Python/Go/Ruby). No ejecuta Java, Tomcat ni JSP.
> Para esta app usa **Render** (o Railway, Fly.io, AWS Elastic Beanstalk).

---

## Arquitectura

```
Navegador ──HTTPS──> Render (Docker: Tomcat 9 + WAR)
                          │
                          └──JDBC──> Clever Cloud (MySQL 8)
```

---

## Archivos listos en el repositorio

| Archivo | Para qué sirve |
|---|---|
| `Dockerfile` | Compila el WAR con Maven y lo despliega en **Tomcat 9**. |
| `.dockerignore` | Evita subir `target/`, `.git`, etc. al build. |
| `render.yaml` | Infraestructura como código (Web Service + variables de entorno). |
| `common/config.jsp` | Lee la conexión desde variables de entorno. |

---

## Base de datos (Clever Cloud) — ya inicializada

La base ya está creada e importada con el esquema y los datos de prueba
(`usuarios`, `ideas`, `calendario`, `formatos`, etc.).

- **Host:** `bpdhyrbabuc6fghivcj7-mysql.services.clever-cloud.com`
- **Puerto:** `3306`
- **Base de datos:** `bpdhyrbabuc6fghivcj7`
- **Usuario:** `urgnhehtkdhpmazp`
- **Contraseña:** la del addon (se configura en Render como secreto).

> Nota: el usuario del addon **no puede crear** la base `db_tgd_uts`, por eso se usa
> el nombre propio del addon (`bpdhyrbabuc6fghivcj7`) como `DB_NAME`. El login de
> `config.jsp` arma la URL `jdbc:mysql://DB_HOST:DB_PORT/DB_NAME`.

Si necesitas **reimportar** el esquema (por ejemplo tras vaciar la base), ejecuta
`tguts/sql/db_tgd_uts.sql` omitiendo las líneas `CREATE DATABASE ...` y `USE db_tgd_uts;`
(con cualquier cliente MySQL apuntando a la base del addon).

---

## Paso 1 — Subir el proyecto a GitHub

```bash
git add .
git commit -m "Deploy en Render"
git push
```

---

## Paso 2 — Crear el Web Service en Render

### Opción A (automática): Blueprint `render.yaml`

1. Render → **New > Blueprint**.
2. Conecta el repositorio. Render detecta `render.yaml`.
3. Cuando lo solicite, pega el valor de **`DB_PASSWORD`** (la contraseña de Clever Cloud).
   No está en el repositorio por seguridad (`sync: false`).
4. Aplica el Blueprint y espera el build.

### Opción B (manual): Web Service

1. Render → **New > Web Service** → conecta el repo.
2. Configura:
   | Campo | Valor |
   |---|---|
   | Language | **Docker** |
   | Dockerfile Path | `./Dockerfile` |
   | Plan | `free` (o `0.5c-512mb` para que no se duerma) |
3. En **Environment**, agrega:

   | Key | Value |
   |---|---|
   | `PORT` | `8080` |
   | `DB_HOST` | `bpdhyrbabuc6fghivcj7-mysql.services.clever-cloud.com` |
   | `DB_PORT` | `3306` |
   | `DB_NAME` | `bpdhyrbabuc6fghivcj7` |
   | `DB_USER` | `urgnhehtkdhpmazp` |
   | `DB_PASSWORD` | *(contraseña de Clever Cloud)* |

4. **Create Web Service**.

---

## Paso 3 — Verificar

- URL: `https://tguts-xxxx.onrender.com`
- Login de prueba: `admin@uts.edu.co` / `admin123` (ver README).

---

## Notas y solución de problemas

- **Tomcat 9 obligatorio.** Con Tomcat 10/11 los `taglib` de JSTL 1.2 (`javax`) fallan.
- **`PORT=8080`.** Render espera el puerto indicado en `PORT` (por defecto 10000);
  Tomcat escucha en 8080, por eso se fija `PORT=8080`.
- **Primer acceso lento** en plan free: el servicio se duerme y tarda ~30–60 s en despertar.
- **Error 500 en el login:** revisa `DB_HOST`, `DB_USER` y `DB_PASSWORD`.
- **Los archivos subidos** (documentos) se pierden en cada deploy porque el disco del
  Web Service es efímero.
- **SSL:** la conexión usa `useSSL=false`. Si Clever Cloud lo exigiera, cambia la URL en
  `src/main/java/edu/uts/PoolInicializador.java` a `useSSL=true`.
- **Warning "Invalid shutdown command [HEAD / HTTP/1.1]":** no es un error. Son las sondas
  de Render que caen en el puerto de apagado de Tomcat (8005). Ya se desactivó ese puerto
  en el `Dockerfile` (`port="-1"` en `server.xml`) para eliminar el ruido en los logs.
