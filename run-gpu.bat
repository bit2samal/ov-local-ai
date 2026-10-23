@echo off
setlocal
cd /d "%~dp0"

set "COMPOSE_FILES=-f docker-compose.yml -f docker-compose.wsl-gpu.yml"
if not defined MODEL_ID set "MODEL_ID=OpenVINO/Qwen3.5-9B-int8-ov"

where docker >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker CLI was not found. Install or start Docker Desktop, then retry.
    goto :failed
)

docker info >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker is not running or the current Docker context is unavailable.
    echo Start Docker Desktop and retry.
    goto :failed
)

echo Checking the WSL 2 GPU Compose configuration...
docker compose %COMPOSE_FILES% config --quiet
if errorlevel 1 (
    echo ERROR: Docker Compose configuration validation failed.
    goto :failed
)

echo Starting OVMS with GPU inference using %MODEL_ID%...
docker compose %COMPOSE_FILES% up --build -d
if errorlevel 1 (
    echo ERROR: The GPU service failed to start. Recent service logs:
    docker compose %COMPOSE_FILES% logs --tail 60 model-server
    goto :failed
)

echo.
echo GPU service started. The first model download and load may take several minutes.
echo API: http://localhost:8000
echo Check status: docker compose %COMPOSE_FILES% ps
echo Follow logs:  docker compose %COMPOSE_FILES% logs -f model-server
echo Stop service: docker compose %COMPOSE_FILES% down
echo.
pause
exit /b 0

:failed
echo.
pause
exit /b 1
