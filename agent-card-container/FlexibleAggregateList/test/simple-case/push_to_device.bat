@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set SCRIPT_DIR=%~dp0
set REMOTE_BASE=/storage/media/100/local/files/Docs/Download/AgentCards

echo Checking hdc connection...
hdc list targets | findstr /r "." >nul
if errorlevel 1 (
    echo [ERROR] No device connected.
    exit /b 1
)

echo Cleaning old data on device...
hdc shell rm -rf %REMOTE_BASE%
hdc shell mkdir -p %REMOTE_BASE%

echo Pushing files...
pushd "%SCRIPT_DIR%"

for /d %%D in (*) do (
    echo.
    echo [%%~nxD]
    set "APP_DIR=%REMOTE_BASE%/%%~nxD"
    hdc shell mkdir -p "!APP_DIR!"
    hdc shell mkdir -p "!APP_DIR!/list"

    if exist "%%D\config.json" (
        hdc file send "%%D\config.json" "!APP_DIR!/config.json"
        echo   config.json
    )
    if exist "%%D\action.js" (
        hdc file send "%%D\action.js" "!APP_DIR!/action.js"
        echo   action.js
    )
    if exist "%%D\take.js" (
        hdc file send "%%D\take.js" "!APP_DIR!/take.js"
        echo   take.js
    )
    for %%F in ("%%D\list\*") do (
        hdc file send "%%F" "!APP_DIR!/list/%%~nxF"
        echo   list/%%~nxF
    )
)

popd

echo.
echo Done. Verifying:
hdc shell ls -R %REMOTE_BASE%
endlocal
