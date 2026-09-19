@echo off
title Rojo Server - ScrapOdyssey
echo ========================================================
echo   Starting Rojo Server on http://localhost:34872
echo   Keep this window open while developing!
echo ========================================================
where rojo >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    rojo serve default.project.json
) else (
    "%LOCALAPPDATA%\Microsoft\WinGet\Packages\Rojo.Rojo_Microsoft.Winget.Source_8wekyb3d8bbwe\rojo.exe" serve default.project.json
)
pause
