@echo off
set "PATH=C:\Program Files\nodejs;%LOCALAPPDATA%\Programs\nodejs;%PATH%"
cd /d "%~dp0"
echo Starting Syupeo Admin Web dev server...
cmd /c npm run dev

