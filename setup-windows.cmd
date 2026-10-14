@echo off
rem Sets up this ArtCraft app for Claude on Windows: shortcut + MCP server + skill.
rem Extra options are passed through, e.g.:  setup-windows.cmd -Mode both -DryRun
setlocal
set "HERE=%~dp0"
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "(Get-Content -Raw '%HERE%app.json' | ConvertFrom-Json).id"`) do set "APPID=%%I"
powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%scripts\artcraft-setup.ps1" -Config "%HERE%app.json" -SkillDir "%HERE%skills\%APPID%" %*
echo.
pause
