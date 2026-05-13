@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

title DAVE THE DIVER SAVE SYNC
set "LOGFILE=%~dp0DAVE_SYNC.log"

:: =================配置区=================
:: ADB 使用本工具包内置版本。
set "ADB=%~dp0adb\adb.exe"

:: 潜水员戴夫 TapTap 安卓版包名。
set "PKG=com.xd.dave.tap.cn"

:: 电脑端存档目录。若账号目录不存在，会自动取 SteamSData 下找到的账号目录。
set "PC_BASE=%USERPROFILE%\AppData\LocalLow\nexon\DAVE THE DIVER\SteamSData"
set "PC_SAVE=%PC_BASE%\1918815201"
if not exist "%PC_SAVE%\" (
    for /d %%i in ("%PC_BASE%\*") do set "PC_SAVE=%%i"
)

:: 手机端真实游戏存档目录，以及普通内部存储中转目录。
set "MOBILE_SAVE=/storage/emulated/0/Android/data/com.xd.dave.tap.cn/files/SData"
set "PHONE_STAGE=/sdcard/DAVE_SYNC_TRANSFER/SData"
set "PHONE_STAGE_ROOT=/sdcard/DAVE_SYNC_TRANSFER"

:: 本地备份目录。
set "MB_ROOT=%~dp0DAVE_Mobile_Backup"
set "PC_ROOT=%~dp0DAVE_PC_Backup"
set "EXP_ROOT=%~dp0DAVE_Mobile_Export"
set "MAX_BK=10"

if not exist "%ADB%" (
    echo [错误] 找不到 adb\adb.exe
    pause
    exit /b
)

set "DEVICE_STR=未检测"

:MENU
for /f %%i in ('powershell -noprofile -command "Get-Date -Format yyyyMMdd_HHmmss"') do set "ts=%%i"
echo. >> "!LOGFILE!" 2>nul
echo ===== %DATE% %TIME% ===== >> "!LOGFILE!" 2>nul
cls
echo(==========================================
echo(         DAVE THE DIVER SAVE SYNC
echo(==========================================
echo( [PC Save] !PC_SAVE!
echo( [Mobile Save] !MOBILE_SAVE!
echo(------------------------------------------
echo( 1. PC to Mobile
echo( 2. Mobile to PC
echo( 3. Export to phone transfer folder
echo( 4. Restore PC backup
echo( 5. Restore Mobile backup
echo( 6. Export Mobile save to PC
echo( 7. Verify Mobile save
echo( 8. USB tutorial
echo( 9. Exit
echo(------------------------------------------
echo( [Device] !DEVICE_STR!
echo(------------------------------------------
set /p opt=请选择: 

if "!opt!"=="1" goto TO_MOBILE
if "!opt!"=="2" goto TO_PC
if "!opt!"=="3" goto EXPORT_TO_PHONE_STAGE
if "!opt!"=="4" goto RESTORE_PC
if "!opt!"=="5" goto RESTORE_MB
if "!opt!"=="6" goto EXPORT_MB
if "!opt!"=="7" goto VERIFY_MB
if "!opt!"=="8" goto TUTORIAL
if "!opt!"=="9" exit /b
goto MENU

:CONFIRM
echo.
set /p confirm=确认执行操作吗? (y/n): 
if /i "!confirm!"=="y" exit /b
echo 操作取消。
pause
goto MENU

:CHECK_PC_SAVE
if exist "!PC_SAVE!\" exit /b
echo [错误] 未找到电脑端存档目录:
echo !PC_SAVE!
echo.
echo [提示] 请确认 Steam 版潜水员戴夫至少启动过一次。
pause
goto MENU

:CHECK_ADB
echo.
echo [连接检测] 正在检查 ADB 设备...
set "ADB_OK="
set "DEVICE_STR=未连接"
for /f "skip=1 tokens=1,2" %%a in ('"%ADB%" devices 2^>nul') do (
    if "%%b"=="device" (
        set "ADB_OK=1"
        for /f "delims=" %%m in ('"%ADB%" shell getprop ro.product.manufacturer 2^>nul') do set "MFR=%%m"
        for /f "delims=" %%m in ('"%ADB%" shell getprop ro.product.marketname 2^>nul') do set "MDL=%%m"
        if "!MDL!"=="" for /f "delims=" %%m in ('"%ADB%" shell getprop ro.product.vendor.marketname 2^>nul') do set "MDL=%%m"
        if "!MDL!"=="" for /f "delims=" %%m in ('"%ADB%" shell getprop ro.vendor.oplus.market.name 2^>nul') do set "MDL=%%m"
        if "!MDL!"=="" for /f "delims=" %%m in ('"%ADB%" shell getprop ro.vivo.market.name 2^>nul') do set "MDL=%%m"
        if "!MDL!"=="" for /f "delims=" %%m in ('"%ADB%" shell getprop ro.product.model 2^>nul') do set "MDL=%%m"
        set "DEVICE_STR=!MFR! !MDL!"
        echo [OK] 检测到设备: !DEVICE_STR!
        exit /b
    )
    if "%%b"=="unauthorized" (
        set "DEVICE_STR=[未授权]"
        echo [错误] 设备未授权
        echo [提示] 请在手机上点击「允许USB调试」后重试
        exit /b
    )
    if "%%b"=="offline" (
        set "DEVICE_STR=[离线]"
        echo [错误] 设备离线
        echo [提示] 请拔插USB线后重试
        exit /b
    )
)
if not defined ADB_OK (
    echo [错误] 未检测到任何设备
    echo [提示] 请确认 USB线已连接 / USB调试已开启 / 驱动已安装
)
exit /b

:COUNT_LOCAL
set /a LOCAL_COUNT=0
if exist "%~1\" (
    for /r "%~1" %%f in (*) do set /a LOCAL_COUNT+=1
)
exit /b

:COUNT_REMOTE
set "REMOTE_COUNT=0"
for /f "delims=" %%c in ('"%ADB%" shell "if [ -d '%~1' ]; then find '%~1' -type f 2^>/dev/null ^| wc -l; else echo 0; fi" 2^>nul') do set "REMOTE_COUNT=%%c"
exit /b

:MAKE_ADB_LOCAL_PATH
set "ADB_LOCAL_PATH=%~1"
set "ADB_LOCAL_PATH=%ADB_LOCAL_PATH:\=/%"
exit /b

:PUSH_TO_STAGE
echo [步骤] 正在把电脑存档放入手机中转目录...
"%ADB%" shell "rm -rf '%PHONE_STAGE_ROOT%' ^&^& mkdir -p '%PHONE_STAGE%'" >nul 2>&1
"%ADB%" push "%~1\." "%PHONE_STAGE%/" > "%TEMP%\_dave_push_stage.tmp" 2>&1
if errorlevel 1 (
    echo [错误] 推送到手机中转目录失败:
    type "%TEMP%\_dave_push_stage.tmp"
    echo [错误] PUSH_TO_STAGE 失败 >> "!LOGFILE!"
    type "%TEMP%\_dave_push_stage.tmp" >> "!LOGFILE!"
    exit /b 1
)
call :COUNT_REMOTE "%PHONE_STAGE%"
call :LOG "中转目录文件数: !REMOTE_COUNT!"
echo [OK] 已放入中转目录: %PHONE_STAGE%  ^(!REMOTE_COUNT! 个文件^)
exit /b 0

:WRITE_STAGE_TO_MOBILE
echo [步骤] 正在尝试直接写入手机游戏目录...
"%ADB%" shell "mkdir -p '%MOBILE_SAVE%' ^&^& touch '%MOBILE_SAVE%/.dave_sync_write_test' ^&^& rm -f '%MOBILE_SAVE%/.dave_sync_write_test'" > "%TEMP%\_dave_write_test.tmp" 2>&1
if errorlevel 1 (
    echo [警告] 当前手机系统不允许 ADB 直接写入 Android/data。
    echo [提示] 文件已保留在: %PHONE_STAGE%
    echo [提示] 请用 MT管理器 把该目录内的文件复制到:
    echo        %MOBILE_SAVE%
    echo [警告] WRITE_TEST 失败 >> "!LOGFILE!"
    type "%TEMP%\_dave_write_test.tmp" >> "!LOGFILE!"
    exit /b 2
)

"%ADB%" shell "rm -rf '%MOBILE_SAVE%.__dave_sync_old'; if [ -d '%MOBILE_SAVE%' ]; then mv '%MOBILE_SAVE%' '%MOBILE_SAVE%.__dave_sync_old'; fi; mkdir -p '%MOBILE_SAVE%'; if cp -R '%PHONE_STAGE%/.' '%MOBILE_SAVE%/'; then rm -rf '%MOBILE_SAVE%.__dave_sync_old'; else rm -rf '%MOBILE_SAVE%'; if [ -d '%MOBILE_SAVE%.__dave_sync_old' ]; then mv '%MOBILE_SAVE%.__dave_sync_old' '%MOBILE_SAVE%'; fi; exit 1; fi" > "%TEMP%\_dave_copy_target.tmp" 2>&1
if errorlevel 1 (
    echo [警告] 写入手机游戏目录失败。
    echo [提示] 文件已保留在: %PHONE_STAGE%
    echo [提示] 请用 MT管理器 手动复制到:
    echo        %MOBILE_SAVE%
    echo [警告] COPY_TARGET 失败 >> "!LOGFILE!"
    type "%TEMP%\_dave_copy_target.tmp" >> "!LOGFILE!"
    exit /b 2
)

call :COUNT_REMOTE "%MOBILE_SAVE%"
"%ADB%" shell "rm -rf '%PHONE_STAGE_ROOT%'" >nul 2>&1
call :LOG "手机游戏目录文件数: !REMOTE_COUNT!"
echo [OK] 已写入手机游戏目录，共 !REMOTE_COUNT! 个文件。
exit /b 0

:: ------------------ [1. PC -> Mobile] ------------------
:TO_MOBILE
call :LOG "TO_MOBILE 开始"
call :CHECK_PC_SAVE
call :COUNT_LOCAL "!PC_SAVE!"
if !LOCAL_COUNT! leq 0 (
    echo [错误] 电脑端存档目录为空，已停止。
    pause
    goto MENU
)
call :CHECK_ADB
if not defined ADB_OK (pause & goto MENU)
call :CONFIRM

"%ADB%" shell "am force-stop %PKG%" >nul 2>&1

echo [1/4] 正在备份手机当前存档...
set "BK=%MB_ROOT%\%ts%"
mkdir "%BK%" 2>nul
call :MAKE_ADB_LOCAL_PATH "%BK%"
"%ADB%" pull "%MOBILE_SAVE%/." "!ADB_LOCAL_PATH!" > "%TEMP%\_dave_pull_backup.tmp" 2>&1
call :COUNT_LOCAL "%BK%"
if !LOCAL_COUNT! gtr 0 (
    call :LOG "手机旧存档备份文件数: !LOCAL_COUNT!"
    echo [OK] 手机备份完成: %BK%  ^(!LOCAL_COUNT! 个文件^)
) else (
    echo [提示] 没有读取到手机旧存档，可能是首次同步或权限受限。
    rmdir /s /q "%BK%" 2>nul
)

echo [2/4] 正在准备电脑端存档...
call :PUSH_TO_STAGE "!PC_SAVE!"
if errorlevel 1 (pause & goto MENU)

echo [3/4] 正在写入手机...
call :WRITE_STAGE_TO_MOBILE
set "WRITE_RESULT=!ERRORLEVEL!"

echo [4/4] 正在清理旧备份...
call :CLEANUP "%MB_ROOT%"

if "!WRITE_RESULT!"=="0" (
    call :LOG "TO_MOBILE 完成: 已直接写入手机游戏目录"
    echo [OK] 同步到手机完成。
) else (
    call :LOG "TO_MOBILE 完成: 仅导出到手机中转目录"
    echo [完成] 已完成中转导出，等待你用 MT管理器 手动放入游戏目录。
)
pause
goto MENU

:: ------------------ [2. Mobile -> PC] ------------------
:TO_PC
call :LOG "TO_PC 开始"
call :CHECK_PC_SAVE
call :CHECK_ADB
if not defined ADB_OK (pause & goto MENU)
call :CONFIRM

"%ADB%" shell "am force-stop %PKG%" >nul 2>&1

set "TEMP_P=%~dp0dave_temp_pull"
rmdir /s /q "%TEMP_P%" 2>nul
mkdir "%TEMP_P%" 2>nul
call :MAKE_ADB_LOCAL_PATH "%TEMP_P%"
set "TEMP_P_ADB=!ADB_LOCAL_PATH!"

echo [1/4] 正在从手机游戏目录读取存档...
"%ADB%" pull "%MOBILE_SAVE%/." "!TEMP_P_ADB!" > "%TEMP%\_dave_pull_mobile.tmp" 2>&1
call :COUNT_LOCAL "%TEMP_P%"
if !LOCAL_COUNT! gtr 0 goto TO_PC_HAVE_FILES

echo [提示] 直接读取失败或手机游戏目录为空。
echo [提示] 现在尝试读取手机中转目录:
echo        %PHONE_STAGE%
"%ADB%" pull "%PHONE_STAGE%/." "!TEMP_P_ADB!" > "%TEMP%\_dave_pull_stage.tmp" 2>&1
call :COUNT_LOCAL "%TEMP_P%"
if !LOCAL_COUNT! gtr 0 goto TO_PC_HAVE_FILES

echo [错误] 没有读取到手机存档，已停止。
echo [提示] 请先用 MT管理器 把游戏 SData 复制到下面这个中转目录:
echo        %PHONE_STAGE%
rmdir /s /q "%TEMP_P%" 2>nul
pause
goto MENU

:TO_PC_HAVE_FILES

echo [2/4] 正在备份电脑当前存档...
set "PC_BK=%PC_ROOT%\%ts%"
robocopy "!PC_SAVE!" "%PC_BK%" /E /R:0 /W:0 >nul
if errorlevel 8 (
    echo [错误] 备份电脑存档失败，已停止。
    rmdir /s /q "%TEMP_P%" 2>nul
    pause
    goto MENU
)
echo [OK] 电脑备份完成: %PC_BK%

echo [3/4] 正在覆盖电脑存档...
robocopy "%TEMP_P%" "!PC_SAVE!" /MIR /R:0 /W:0 >nul
if errorlevel 8 (
    echo [错误] 覆盖电脑存档失败，请检查权限。
    rmdir /s /q "%TEMP_P%" 2>nul
    pause
    goto MENU
)

echo [4/4] 正在清理...
rmdir /s /q "%TEMP_P%" 2>nul
call :CLEANUP "%PC_ROOT%"
echo [OK] 同步到电脑完成，共 !LOCAL_COUNT! 个文件。
call :LOG "TO_PC 完成: !LOCAL_COUNT! 个文件"
pause
goto MENU

:: ------------------ [3. PC -> 手机中转目录] ------------------
:EXPORT_TO_PHONE_STAGE
call :LOG "EXPORT_TO_PHONE_STAGE 开始"
call :CHECK_PC_SAVE
call :COUNT_LOCAL "!PC_SAVE!"
if !LOCAL_COUNT! leq 0 (
    echo [错误] 电脑端存档目录为空，已停止。
    pause
    goto MENU
)
call :CHECK_ADB
if not defined ADB_OK (pause & goto MENU)
call :CONFIRM
call :PUSH_TO_STAGE "!PC_SAVE!"
if errorlevel 1 (pause & goto MENU)
echo.
echo [OK] 已导出到手机中转目录:
echo      %PHONE_STAGE%
echo.
echo 接下来用 MT管理器 把该目录内的文件复制到:
echo      %MOBILE_SAVE%
pause
goto MENU

:: ------------------ [4. 恢复电脑存档] ------------------
:RESTORE_PC
call :LOG "RESTORE_PC 开始"
call :CHECK_PC_SAVE
cls
echo ======= 恢复电脑备份 =======
set /a cnt=0
for /d %%d in ("%PC_ROOT%\*") do (
    set /a cnt+=1
    set "f!cnt!=%%~nxd"
    echo  [!cnt!] %%~nxd
)
if !cnt! equ 0 (
    echo 暂无备份。
    pause
    goto MENU
)
echo.
set /p sel=序号: 
set "S_BK=!f%sel%!"
if "!S_BK!"=="" goto MENU
call :CONFIRM

set "PC_BK=%PC_ROOT%\before_restore_%ts%"
robocopy "!PC_SAVE!" "%PC_BK%" /E /R:0 /W:0 >nul
robocopy "%PC_ROOT%\!S_BK!" "!PC_SAVE!" /MIR /R:0 /W:0 >nul
if errorlevel 8 (
    echo [错误] 恢复失败，请检查权限。
) else (
    echo [OK] 已恢复电脑存档: !S_BK!
)
pause
goto MENU

:: ------------------ [5. 恢复手机存档] ------------------
:RESTORE_MB
call :LOG "RESTORE_MB 开始"
cls
echo ======= 恢复手机备份 =======
set /a cnt=0
for /d %%d in ("%MB_ROOT%\*") do (
    set /a cnt+=1
    set "f!cnt!=%%~nxd"
    echo  [!cnt!] %%~nxd
)
if !cnt! equ 0 (
    echo 暂无备份。
    pause
    goto MENU
)
echo.
set /p sel=序号: 
set "S_BK=!f%sel%!"
if "!S_BK!"=="" goto MENU
call :CHECK_ADB
if not defined ADB_OK (pause & goto MENU)
call :CONFIRM

"%ADB%" shell "am force-stop %PKG%" >nul 2>&1
call :PUSH_TO_STAGE "%MB_ROOT%\!S_BK!"
if errorlevel 1 (pause & goto MENU)
call :WRITE_STAGE_TO_MOBILE
if errorlevel 1 (
    echo [完成] 已放入手机中转目录，需用 MT管理器 手动复制。
) else (
    echo [OK] 已恢复手机存档: !S_BK!
)
pause
goto MENU

:: ------------------ [6. 导出手机存档到电脑] ------------------
:EXPORT_MB
call :LOG "EXPORT_MB 开始"
call :CHECK_ADB
if not defined ADB_OK (pause & goto MENU)
call :CONFIRM

"%ADB%" shell "am force-stop %PKG%" >nul 2>&1
set "EXP=%EXP_ROOT%\%ts%"
mkdir "%EXP%" 2>nul
call :MAKE_ADB_LOCAL_PATH "%EXP%"
echo 正在导出手机存档...
"%ADB%" pull "%MOBILE_SAVE%/." "!ADB_LOCAL_PATH!" > "%TEMP%\_dave_export_mobile.tmp" 2>&1
call :COUNT_LOCAL "%EXP%"
if !LOCAL_COUNT! leq 0 (
    echo [错误] 没有导出到任何文件。
    echo [提示] 如果 Android/data 无法直接读取，可先用 MT管理器 复制到:
    echo        %PHONE_STAGE%
    rmdir /s /q "%EXP%" 2>nul
) else (
    echo [OK] 导出完成: %EXP%  ^(!LOCAL_COUNT! 个文件^)
)
pause
goto MENU

:: ------------------ [7. 检查手机存档状态] ------------------
:VERIFY_MB
call :LOG "VERIFY_MB 开始"
call :CHECK_ADB
if not defined ADB_OK (pause & goto MENU)

echo.
echo [检查] 手机游戏目录:
echo        %MOBILE_SAVE%
echo ------------------------------------------
"%ADB%" shell "if [ -d '%MOBILE_SAVE%' ]; then echo EXISTS; ls -la '%MOBILE_SAVE%'; else echo MISSING; fi" > "%TEMP%\_dave_verify_mobile.tmp" 2>&1
type "%TEMP%\_dave_verify_mobile.tmp"
type "%TEMP%\_dave_verify_mobile.tmp" >> "!LOGFILE!" 2>nul

call :COUNT_REMOTE "%MOBILE_SAVE%"
echo ------------------------------------------
echo [结果] 手机游戏目录内共有 !REMOTE_COUNT! 个文件。
call :LOG "VERIFY_MB 手机游戏目录文件数: !REMOTE_COUNT!"

echo.
echo [检查] 手机中转目录:
echo        %PHONE_STAGE%
echo ------------------------------------------
"%ADB%" shell "if [ -d '%PHONE_STAGE%' ]; then echo EXISTS; ls -la '%PHONE_STAGE%'; else echo MISSING; fi" > "%TEMP%\_dave_verify_stage.tmp" 2>&1
type "%TEMP%\_dave_verify_stage.tmp"
type "%TEMP%\_dave_verify_stage.tmp" >> "!LOGFILE!" 2>nul

call :COUNT_REMOTE "%PHONE_STAGE%"
echo ------------------------------------------
echo [结果] 手机中转目录内共有 !REMOTE_COUNT! 个文件。
call :LOG "VERIFY_MB 手机中转目录文件数: !REMOTE_COUNT!"
pause
goto MENU

:TUTORIAL
cls
echo ==========================================
echo             USB 连接教程
echo ==========================================
echo.
echo  1. 手机开启开发者选项和 USB调试
echo     设置 - 关于手机 - 连续点击版本号 7 次
echo     返回开发者选项，打开 USB调试
echo.
echo  2. 用数据线连接电脑
echo     手机弹出「允许 USB调试」时点击允许
echo     USB 用途通常选择「仅充电」即可
echo.
echo  3. 小米/红米若读写失败
echo     开发者选项中开启「禁用权限监控」
echo.
echo  4. 如果 Android/data 仍不允许直接写入
echo     使用菜单 3，把电脑存档导出到:
echo        %PHONE_STAGE%
echo     再用 MT管理器 复制到:
echo        %MOBILE_SAVE%
echo.
echo ==========================================
pause
goto MENU

:LOG
echo %~1 >> "!LOGFILE!" 2>nul
exit /b

:CLEANUP
set /a _cnt=0
for /d %%d in ("%~1\*") do set /a _cnt+=1
if !_cnt! leq %MAX_BK% exit /b
set /a _del=_cnt - MAX_BK
set /a _done=0
for /d %%d in ("%~1\*") do (
    if !_done! lss !_del! (
        rmdir /s /q "%%d" 2>nul
        set /a _done+=1
    )
)
exit /b
