@echo off
echo ================================================
echo    ENTROPY PRIME - Zero Trust Auth System
echo ================================================
echo.

REM Kill any existing instances
tasklist /FI "IMAGENAME eq node.exe" 2>NUL | find /I /N "node.exe">NUL
if %ERRORLEVEL% EQU 0 (
    echo Stopping existing Node.js processes...
    taskkill /F /IM node.exe >nul 2>&1
)

REM Only kill Python/uvicorn if they're on port 8001 (not Splunk on 8000)
for /f "tokens=5" %%a in ('netstat -aon ^| find ":8001"') do (
    taskkill /F /PID %%a >nul 2>&1
)

echo Starting MongoDB...
start "MongoDB" docker-compose up -d

echo Waiting for MongoDB to initialize...
timeout /t 8 /nobreak > nul

echo Starting Backend Server on port 8001...
start "Entropy Prime Backend" cmd /k "cd backend && if exist venv\Scripts\activate.bat (call .\venv\Scripts\activate.bat) && set MONGODB_URL=mongodb://admin:changeme@localhost:27017/entropy_prime?authSource=admin && set CORS_ORIGINS=http://localhost:3000,http://localhost:3001,http://127.0.0.1:3000,http://localhost:5173 && set PORT=8001 && echo Backend starting on port 8001... && py -m uvicorn main:app --reload --host 0.0.0.0 --port 8001"

echo Waiting for backend to start...
timeout /t 6 /nobreak > nul

echo Starting Frontend...
start "Entropy Prime Frontend" cmd /k "set VITE_API_URL=http://localhost:8001 && echo Frontend starting... && npm run dev"

echo.
echo ================================================
echo    ENTROPY PRIME STARTUP COMPLETE
echo ================================================
echo.
echo   Frontend:   http://localhost:3000
echo   Backend:    http://localhost:8001
echo   API Docs:   http://localhost:8001/docs
echo   Health:     http://localhost:8001/health
echo   MongoDB:    localhost:27017
echo.
echo NOTE: Port 8000 is occupied by Splunk.
echo       Backend uses port 8001.
echo.
echo Close this window to stop all servers.
echo.
pause