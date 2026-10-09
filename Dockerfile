# =====================================================================
# Dockerfile - Sistema de Trabajos de Grado UTS
# Etapa 1: compila el WAR con Maven.
# Etapa 2: despliega el WAR sobre Tomcat 9 (javax) para Render.
# =====================================================================

# ---- Etapa 1: compilar el WAR con Maven ----
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /build

# Cachea las dependencias: si el pom.xml no cambia, esta capa se reutiliza.
COPY tguts/pom.xml .
RUN mvn -B -q dependency:go-offline

# Copia el código fuente (JSP, css, img, WEB-INF, etc.)
COPY tguts/src ./src

# Genera tguts/target/tguts.war
RUN mvn -B -q clean package -DskipTests

# ---- Etapa 2: Tomcat 9 (Java EE / javax) ----
# IMPORTANTE: debe ser Tomcat 9, NO 10/11 (esos usan Jakarta y rompen JSTL 1.2).
FROM tomcat:9.0-jdk17-temurin

# Limpia las apps de ejemplo y despliega la nuestra en la raíz (/)
RUN rm -rf /usr/local/tomcat/webapps/*
COPY --from=build /build/target/tguts.war /usr/local/tomcat/webapps/ROOT.war

# Desactiva el puerto de apagado (8005) de Tomcat.
# Render envía sondas HTTP al contenedor y, al caer en el puerto 8005,
# generan warnings repetidos: "Invalid shutdown command [HEAD / HTTP/1.1]".
# Con port="-1" el puerto 8005 deja de escuchar (config segura/STIG);
# el puerto HTTP 8080 no se ve afectado.
RUN sed -i 's/<Server port="8005" shutdown="SHUTDOWN">/<Server port="-1" shutdown="SHUTDOWN">/' /usr/local/tomcat/conf/server.xml

EXPOSE 8080
CMD ["catalina.sh", "run"]
