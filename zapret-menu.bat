@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: Проверка прав администратора и перезапуск с правами администратора, если нужно
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Запуск с правами администратора...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: Папки
set "BIN=%~dp0binv2\"
set "LISTS=%~dp0lists\"
set "SRVCNAME=zapret"

:: Начальные значения
set "USE_GAMEFILTER=0"
set "USE_DEPENDENCY=0"

:MENU
cls
echo ==============================
echo      Настройка zapret
echo ==============================
echo.
echo 1. Включить/выключить игровой фильтр (текущий: %USE_GAMEFILTER%)
echo 2. Включить/выключить зависимость от GoodbyeDPI (текущий: %USE_DEPENDENCY%)
echo 3. Установить и запустить сервис
echo 4. Удалить сервис и драйверы
echo 5. Диагностика состояния
echo 6. Выход
echo.
set /p choice=Выберите опцию (1-6): 

if "%choice%"=="1" (
  if "%USE_GAMEFILTER%"=="0" (set "USE_GAMEFILTER=1") else (set "USE_GAMEFILTER=0")
  goto MENU
)
if "%choice%"=="2" (
  if "%USE_DEPENDENCY%"=="0" (set "USE_DEPENDENCY=1") else (set "USE_DEPENDENCY=0")
  goto MENU
)
if "%choice%"=="3" goto INSTALL
if "%choice%"=="4" goto REMOVE
if "%choice%"=="5" goto DIAGNOSE
if "%choice%"=="6" goto END

goto MENU

:INSTALL
echo.
echo Остановка и удаление старого сервиса и драйверов...
net stop %SRVCNAME% >nul 2>&1
sc delete %SRVCNAME% >nul 2>&1
net stop "WinDivert" >nul 2>&1
sc delete "WinDivert" >nul 2>&1
net stop "WinDivert14" >nul 2>&1
sc delete "WinDivert14" >nul 2>&1

if "%USE_GAMEFILTER%"=="1" (
  set "GameFilter=,50000-50100"
) else (
  set "GameFilter="
)

if "%USE_DEPENDENCY%"=="1" (
  set "DEPEND_PARAM=depend= \"GoodbyeDPI\""
) else (
  set "DEPEND_PARAM="
)

set "ARGS=--wf-tcp=80,443%GameFilter% --wf-udp=443,50000-50100%GameFilter% ^
--filter-udp=443 --hostlist=\"%LISTS%list-general.txt\" --dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fake-quic=\"%BIN%quic_initial_www_google_com.bin\" --new ^
--filter-udp=50000-50100 --filter-l7=discord,stun --dpi-desync=fake --dpi-desync-repeats=6 --new ^
--filter-tcp=80 --hostlist=\"%LISTS%list-general.txt\" --dpi-desync=fake,split2 --dpi-desync-autottl=2 --dpi-desync-fooling=md5sig --new ^
--filter-tcp=443 --hostlist=\"%LISTS%list-general.txt\" --dpi-desync=fake,split --dpi-desync-autottl=5 --dpi-desync-repeats=6 --dpi-desync-fooling=badseq --dpi-desync-fake-tls=\"%BIN%tls_clienthello_www_google_com.bin\" --new ^
--filter-udp=443 --ipset=\"%LISTS%ipset-all.txt\" --dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fake-quic=\"%BIN%quic_initial_www_google_com.bin\" --new ^
--filter-tcp=80 --ipset=\"%LISTS%ipset-all.txt\" --dpi-desync=fake,split2 --dpi-desync-autottl=2 --dpi-desync-fooling=md5sig --new ^
--filter-tcp=443%GameFilter% --ipset=\"%LISTS%ipset-all.txt\" --dpi-desync=fake,split --dpi-desync-autottl=5 --dpi-desync-repeats=6 --dpi-desync-fooling=badseq --dpi-desync-fake-tls=\"%BIN%tls_clienthello_www_google_com.bin\" --new ^
--filter-udp=%GameFilter% --ipset=\"%LISTS%ipset-all.txt\" --dpi-desync=fake --dpi-desync-autottl=2 --dpi-desync-repeats=12 --dpi-desync-any-protocol=1 --dpi-desync-fake-unknown-udp=\"%BIN%quic_initial_www_google_com.bin\" --dpi-desync-cutoff=n3"

echo Создание сервиса %SRVCNAME%...
sc create %SRVCNAME% binPath= "\"%BIN%winws.exe\" %ARGS%" DisplayName= "zapret DPI bypass : %SRVCNAME%" start= auto %DEPEND_PARAM%
sc description %SRVCNAME% "zapret DPI bypass software"

echo Запуск сервиса...
sc start %SRVCNAME%

echo.
pause
goto MENU

:REMOVE
echo.
echo Остановка и удаление сервиса и драйверов...
net stop %SRVCNAME% >nul 2>&1
sc delete %SRVCNAME% >nul 2>&1
net stop "WinDivert" >nul 2>&1
sc delete "WinDivert" >nul 2>&1
net stop "WinDivert14" >nul 2>&1
sc delete "WinDivert14" >nul 2>&1
echo.
pause
goto MENU

:DIAGNOSE
echo.
echo Проверка статуса сервиса %SRVCNAME%:
sc query %SRVCNAME% | findstr /i "STATE"
echo.

echo Проверка статуса драйвера WinDivert:
sc query WinDivert | findstr /i "STATE"
sc query WinDivert14 | findstr /i "STATE"
echo.

echo Проверка процессов winws.exe:
tasklist /FI "IMAGENAME eq winws.exe"
echo.

echo Проверка открытых портов (80, 443, 50000-50100):
netstat -ano | findstr ":80 "
netstat -ano | findstr ":443 "
netstat -ano | findstr ":50000"
echo.

pause
goto MENU

:END
endlocal
exit /b
