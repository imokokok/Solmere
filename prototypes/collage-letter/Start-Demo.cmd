@echo off
if exist "%~dp0runtime\python\python.exe" (
  "%~dp0runtime\python\python.exe" "%~dp0server\launch.py" --showcase
) else (
  py -3 "%~dp0server\launch.py" --showcase
)
if errorlevel 1 pause
