# ============================================================
#  desplegar_local.ps1 - Reconstruye el WAR y lo despliega en el
#  Tomcat local de XAMPP (contexto /tguts, puerto 8080).
#
#  Uso (desde la raiz del repositorio):
#      powershell -ExecutionPolicy Bypass -File pruebas\desplegar_local.ps1
#
#  Pasos: mvn clean package -> copia el WAR -> reinicia Tomcat.
# ============================================================
$ErrorActionPreference = "Stop"

$raiz   = Split-Path -Parent $PSScriptRoot
$tomcat = "C:\xampp\tomcat"
$war    = Join-Path $raiz "tguts\target\tguts.war"
$dest   = Join-Path $tomcat "webapps\tguts.war"

Write-Host "[1/5] Compilando el WAR (Maven)..." -ForegroundColor Cyan
Push-Location (Join-Path $raiz "tguts")
mvn -B -q -o clean package
if ($LASTEXITCODE -ne 0) { Pop-Location; throw "Falló la compilación del WAR." }
Pop-Location

Write-Host "[2/5] Deteniendo Tomcat..." -ForegroundColor Cyan
$env:JAVA_HOME       = "C:\Program Files\Java\jdk-21.0.10"
$env:CATALINA_HOME   = $tomcat
$env:CATALINA_BASE   = $tomcat
$env:CATALINA_TMPDIR = "$tomcat\temp"
# shutdown.bat escribe avisos (JDK_JAVA_OPTIONS) por stderr: se ignoran.
$ErrorActionPreference = "Continue"
cmd /c "`"$tomcat\bin\shutdown.bat`"" 2>&1 | Out-Null
Start-Sleep -Seconds 6
Get-Process -Name "java" -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -like "*jdk*" } |
    Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
$ErrorActionPreference = "Stop"

Write-Host "[3/5] Copiando el WAR a webapps\tguts.war..." -ForegroundColor Cyan
Copy-Item $war $dest -Force
if (Test-Path (Join-Path $tomcat "webapps\tguts")) {
    Remove-Item (Join-Path $tomcat "webapps\tguts") -Recurse -Force
}

Write-Host "[4/5] Arrancando Tomcat..." -ForegroundColor Cyan
# startup.bat se lanza en un proceso aparte: cmd /c lo dejaria esperando.
Start-Process -FilePath "cmd.exe" `
    -ArgumentList "/c", "`"$tomcat\bin\startup.bat`"" `
    -WindowStyle Hidden
Start-Sleep -Seconds 12

Write-Host "[5/5] Comprobando la disponibilidad de la aplicacion..." -ForegroundColor Cyan

# Comprobacion de salud: se reintenta hasta 120 s (Tomcat tarda en arrancar).
$ok = $false
for ($i = 1; $i -le 40; $i++) {
    Start-Sleep -Seconds 3
    try {
        $r = Invoke-WebRequest -Uri "http://localhost:8080/tguts/login.jsp" -UseBasicParsing -TimeoutSec 10
        if ($r.StatusCode -eq 200) {
            Write-Host "OK - la aplicacion responde en http://localhost:8080/tguts/ (HTTP $($r.StatusCode))" -ForegroundColor Green
            $ok = $true
            break
        }
    } catch { }
}
if (-not $ok) {
    throw "Tomcat no responde en http://localhost:8080/tguts/login.jsp tras 120 s."
}
