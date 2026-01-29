@echo off
REM BiblioHub - Stop the Docker Swarm stack (Windows)
REM This script stops and removes the BiblioHub stack from Docker Swarm

setlocal enabledelayedexpansion

set "STACK_NAME=bibliohub"

echo ==========================================
echo   BiblioHub - Stopping Stack
echo ==========================================

REM Check if Docker is running
docker info >nul 2>&1
if errorlevel 1 (
    echo Error: Docker is not running. Please start Docker Desktop.
    exit /b 1
)

REM Check if the stack exists
docker stack ls | findstr /C:"%STACK_NAME%" >nul
if errorlevel 1 (
    echo Stack '%STACK_NAME%' is not running.
    exit /b 0
)

echo.
echo Removing stack '%STACK_NAME%'...
docker stack rm %STACK_NAME%

echo.
echo Waiting for services to stop...
timeout /t 5 /nobreak >nul

:wait_services
for /f %%i in ('docker service ls --filter "name=%STACK_NAME%" -q 2^>nul') do (
    timeout /t 2 /nobreak >nul
    goto wait_services
)

echo Waiting for networks to be cleaned up...
timeout /t 5 /nobreak >nul

:wait_networks
for /f %%i in ('docker network ls --filter "name=%STACK_NAME%" -q 2^>nul') do (
    timeout /t 2 /nobreak >nul
    goto wait_networks
)

echo.
echo ==========================================
echo   BiblioHub stack stopped successfully!
echo ==========================================
echo.
echo Note: Volumes are preserved. To remove them, run:
echo   docker volume rm (docker volume ls -q ^| findstr bibliohub)

endlocal
