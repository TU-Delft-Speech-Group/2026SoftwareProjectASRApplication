@echo off
:: Builds an Android release of the app on Windows.
::
:: Usage (from repo root):
::   scripts\build\build_for_android.bat
::
:: The .apk lands in build\app\outputs\flutter-apk\.

setlocal
set "REPO=%~dp0..\.."
pushd "%REPO%" || exit /b 1


echo Refreshing dependencies...
call flutter pub get >nul
if errorlevel 1 goto :error

echo Building assets...
call dart run flutter_launcher_icons >nul
if errorlevel 1 goto :error

echo Building Android release...
call flutter build apk  --no-pub --release
if errorlevel 1 goto :error

echo.
echo Build complete:
echo   %CD%\build\app\outputs\flutter-apk\app-release.apk

popd
endlocal
exit /b 0

:error
set "EXIT_CODE=%ERRORLEVEL%"
popd
endlocal & exit /b %EXIT_CODE%
