@echo off
setlocal
chcp 65001 >nul
set "SOLMERE_ENGINE=%~dp0runtime\Godot.exe"
if not exist "%SOLMERE_ENGINE%" set "SOLMERE_ENGINE=%~dp0..\..\..\engine\Godot_v4.5.1-stable_win64.exe"
if not exist "%SOLMERE_ENGINE%" (
  echo Please open project.godot with Godot 4.5 or use the complete portable package.
  pause
  exit /b 1
)
if not exist "%~dp0.godot\global_script_class_cache.cfg" (
  echo Preparing paper and recorded sounds for the first visit...
  "%SOLMERE_ENGINE%" --headless --editor --path "%~dp0." --import --quit
  if errorlevel 1 exit /b 1
)
start "" "%SOLMERE_ENGINE%" --path "%~dp0." %*
