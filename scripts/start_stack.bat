@echo off
REM BiblioHub - Start the Docker Swarm stack (Windows)
REM This script deploys the BiblioHub stack to Docker Swarm

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "HUB_DIR=%SCRIPT_DIR%.."
set "STACK_NAME=bibliohub"

REM Load environment variables from .env file if it exists
if exist "%HUB_DIR%\.env" (
    echo Loading environment from .env file...
    for /f "usebackq tokens=1,* delims==" %%a in ("%HUB_DIR%\.env") do (
        REM Skip comments and empty lines
        set "line=%%a"
        if not "!line:~0,1!"=="#" if not "!line!"=="" (
            set "%%a=%%b"
        )
    )
)

REM Set defaults for hub URL
if not defined BIBLIO_HUB_HOSTNAME set "BIBLIO_HUB_HOSTNAME=localhost"
if not defined BIBLIO_HUB_PORT set "BIBLIO_HUB_PORT=9900"
set "HUB_URL=http://!BIBLIO_HUB_HOSTNAME!:!BIBLIO_HUB_PORT!"

echo ==========================================
echo   BiblioHub - Starting Stack
echo ==========================================

REM Check if Docker is running
docker info >nul 2>&1
if errorlevel 1 (
    echo Error: Docker is not running. Please start Docker Desktop.
    exit /b 1
)

REM Check if Docker Swarm is initialized
docker info 2>nul | findstr /C:"Swarm: active" >nul
if errorlevel 1 (
    echo Docker Swarm is not active. Initializing...
    docker swarm init
)

REM Create data directories
echo.
echo Creating data directories...
if not exist "%HUB_DIR%\data\abb_tts\db" mkdir "%HUB_DIR%\data\abb_tts\db"
if not exist "%HUB_DIR%\data\abb_tts\temp" mkdir "%HUB_DIR%\data\abb_tts\temp"
if not exist "%HUB_DIR%\data\abb_tts\logs" mkdir "%HUB_DIR%\data\abb_tts\logs"
if not exist "%HUB_DIR%\data\tts_silero\models" mkdir "%HUB_DIR%\data\tts_silero\models"
if not exist "%HUB_DIR%\data\tts_openvoice\models" mkdir "%HUB_DIR%\data\tts_openvoice\models"
if not exist "%HUB_DIR%\data\opds\db" mkdir "%HUB_DIR%\data\opds\db"
if not exist "%HUB_DIR%\data\opds\books" mkdir "%HUB_DIR%\data\opds\books"
if not exist "%HUB_DIR%\data\keycloak\db" mkdir "%HUB_DIR%\data\keycloak\db"
echo   - data\abb_tts\db              (database)
echo   - data\abb_tts\temp            (temp files and audiobooks)
echo   - data\abb_tts\logs            (log files)
echo   - data\tts_silero\models       (Silero TTS models cache)
echo   - data\tts_openvoice\models    (OpenVoice TTS models cache)
echo   - data\opds\db                 (database)
echo   - data\opds\books              (e-book library)
echo   - data\keycloak\db             (Keycloak database)

REM Deploy the stack
echo.
echo Deploying stack '%STACK_NAME%'...
cd /d "%HUB_DIR%"
docker stack deploy -c stack.yaml --resolve-image always %STACK_NAME%

REM All services to monitor
set "ALL_SERVICES=keycloak-db keycloak nginx-gateway opds-server abb-tts tts-silero tts-openvoice"
set "MAX_WAIT=180"
set "POLL_INTERVAL=3"

set "start_time=%time:~0,2%%time:~3,2%%time:~6,2%"

:wait_loop
cls
echo ==========================================
echo   BiblioHub - Service Status
echo ==========================================
echo.
echo   SERVICE              STATUS
echo   ----------------------------------------

set "all_ready=true"
set "has_failed=false"

for %%s in (%ALL_SERVICES%) do (
    set "full_name=%STACK_NAME%_%%s"
    set "replicas="
    set "status=Pending"
    
    for /f "tokens=*" %%r in ('docker service ls --filter "name=!full_name!" --format "{{.Replicas}}" 2^>nul') do (
        set "replicas=%%r"
    )
    
    if not "!replicas!"=="" (
        for /f "tokens=1,2 delims=/" %%a in ("!replicas!") do (
            set "current=%%a"
            set "desired=%%b"
        )
        if "!current!"=="!desired!" if not "!current!"=="0" (
            set "status=Ready"
        ) else (
            set "status=Starting"
            set "all_ready=false"
        )
    ) else (
        set "all_ready=false"
    )
    
    if "!status!"=="Ready" (
        echo   %%s                    [OK] Ready
    ) else if "!status!"=="Starting" (
        echo   %%s                    [...] Starting
    ) else (
        echo   %%s                    [ ] Pending
    )
)

echo.

if "!all_ready!"=="true" (
    echo ==========================================
    echo   BiblioHub is ready!
    echo ==========================================
    echo.
    echo   Access the hub at: !HUB_URL!
    echo.
    echo   Use 'scripts\stop_stack.bat' to stop the stack
    goto :end
)

timeout /t %POLL_INTERVAL% /nobreak >nul
goto wait_loop

:end

endlocal
