@echo off
:: Builds a Windows release of the app on Windows.
::
:: Usage (from repo root):
::   scripts\build\build_for_windows.bat
::
:: The executable lands in build\windows\x64\runner\Release\.

setlocal
set "REPO=%~dp0..\.."
pushd "%REPO%" || exit /b 1


echo Refreshing dependencies...
call flutter pub get >nul
if errorlevel 1 goto :error

echo Building assets...
call dart run flutter_launcher_icons >nul
if errorlevel 1 goto :error

echo Building Windows release...
call flutter build windows  --no-pub --release
if errorlevel 1 goto :error

echo.
echo Build complete:
echo   %CD%\build\windows\x64\runner\Release\DISC.exe

popd
endlocal
exit /b 0

:error
set "EXIT_CODE=%ERRORLEVEL%"
popd
endlocal & exit /b %EXIT_CODE%
