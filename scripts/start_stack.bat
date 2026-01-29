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

REM Define services to monitor
set "CORE_SERVICES=keycloak-db keycloak nginx-gateway opds-server abb-tts"
set "MAX_WAIT=180"
set "POLL_INTERVAL=5"

echo.
echo ==========================================
echo   Waiting for services to start...
echo ==========================================
echo.

set "start_time=%time%"
set "all_ready=false"

:wait_loop
set "all_ready=true"
set "status_line="

for %%s in (%CORE_SERVICES%) do (
    set "full_name=%STACK_NAME%_%%s"
    for /f "tokens=*" %%r in ('docker service ls --filter "name=!full_name!" --format "{{.Replicas}}" 2^>nul') do (
        set "replicas=%%r"
    )
    
    if "!replicas!"=="" (
        set "status_line=!status_line!%%s: ...  "
        set "all_ready=false"
    ) else (
        for /f "tokens=1,2 delims=/" %%a in ("!replicas!") do (
            set "current=%%a"
            set "desired=%%b"
        )
        if "!current!"=="!desired!" if not "!current!"=="0" (
            set "status_line=!status_line!%%s: OK  "
        ) else (
            set "status_line=!status_line!%%s: !current!/!desired!  "
            set "all_ready=false"
        )
    )
)

echo !status_line!

if "!all_ready!"=="false" (
    timeout /t %POLL_INTERVAL% /nobreak >nul
    goto wait_loop
)

echo.
echo.

if "!all_ready!"=="true" (
    echo ==========================================
    echo   BiblioHub is ready!
    echo ==========================================
    echo.
    echo   Access the hub at: http://localhost:9900
    echo.
    echo   Use 'scripts\stop_stack.bat' to stop the stack
) else (
    echo.
    echo   Partial startup - access the hub at: http://localhost:9900
    echo   Use 'scripts\stop_stack.bat' to stop the stack
)

endlocal
