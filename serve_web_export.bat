@echo off
REM Godot Web exports must be served over http:// — opening the .html via file:// will fail (CORS).
cd /d "%~dp0exports"
echo.
echo  Serving folder: %CD%
echo  Open in your browser:  http://localhost:8765/MyMissionGame.html
echo  Press Ctrl+C to stop.
echo.
py -m http.server 8765
if errorlevel 1 python -m http.server 8765
