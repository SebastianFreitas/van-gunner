@echo off
rem Double-click to play this checkout without opening the editor.
rem Finds Godot the way the tools do (tools/godot_env.py: the GODOT variable,
rem then PATH) and runs it in this console, so errors print here while you play.
rem Extra arguments go to Godot:  play.bat res://scenes/van/van.tscn
setlocal
cd /d "%~dp0"

set "GODOT_EXE="
for /f "usebackq delims=" %%G in (`py -3 -c "import sys; sys.path.insert(0, 'tools'); from godot_env import find_godot; print(find_godot() or '')"`) do set "GODOT_EXE=%%G"
if not defined GODOT_EXE if defined GODOT set "GODOT_EXE=%GODOT%"
if not defined GODOT_EXE (
	echo No Godot found: set the GODOT environment variable to the Godot 4.7 executable.
	pause
	exit /b 1
)

rem Import every launch: a checkout the editor never opened has no import cache, and a pull that
rem adds class_name scripts leaves the class cache stale (their names then fail to parse).
rem A warm import takes seconds.
if not exist ".godot\" echo First run: importing assets, this takes a few minutes...
"%GODOT_EXE%" --headless --path . --import >nul 2>&1

"%GODOT_EXE%" --path . %*
rem Keep the window open after a crash so the error stays readable.
if errorlevel 1 pause
