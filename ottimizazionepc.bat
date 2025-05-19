@echo off
echo ================================
echo Ottimizzazione del PC in corso...
echo ================================
echo [1/13]controllo sistema operativo
sfc /scannow
DISM /Online /Cleanup-Image /RestoreHealth
echo [2/13]Controllo disco (chkdsk)...
chkdsk C: /scan
timeout /t 5 >nul
echo [3/13] Pulizia Windows Update...
net stop wuauserv >nul 2>&1
del /f /s /q %windir%\SoftwareDistribution\Download\* >nul 2>&1
net start wuauserv >nul 2>&1
timeout /t 5 >nul
echo [4/13] Avvio Pulizia disco automatica...
cleanmgr /sagerun:1
timeout /t 5 >nul
echo [5/13] Pulizia file di log...
del /f /s /q C:\Windows\Logs\*.* >nul 2>&1
timeout /t 3 >nul
echo [6/13] Pulizia cartelle temporanee dell'utente...
del /s /q "%USERPROFILE%\AppData\Local\Microsoft\Windows\INetCache\*" >nul 2>&1
del /s /q "%USERPROFILE%\AppData\Local\Microsoft\Windows\Temporary Internet Files\*" >nul 2>&1
timeout /t 5 >nul
echo [7/13]Controllo stato SMART del disco...
wmic diskdrive get status
timeout /t 5 >nul
echo [8/13] Pulizia avanzata rete...
nbtstat -R
nbtstat -RR
arp -d *
timeout /t 5 >nul

echo [9/13] Ottimizzazione del disco...
defrag C: /O
echo [10/13] ottimizzazione dns
ipconfig /flushdns
echo [11/13] Disattivazione temporanea servizi inutili...
net stop DiagTrack >nul 2>&1  :: Servizio di tracciamento diagnostico
net stop WSearch >nul 2>&1    :: Ricerca indicizzata di Windows
net stop Fax >nul 2>&1
net stop RetailDemo >nul 2>&1
timeout /t 5 >nul

echo [12/13] aggiornamento app pc
winget upgrade
winget upgrade --all 
winget upgrade --all --include-unknown 
set "folder=C:\Windows\Prefetch"
if exist "%folder%" (
    del /q "%folder%\*.*"
    echo Tutti i file nella cartella "%folder%" sono stati eliminati.
) else (
    echo La cartella specificata non esiste.
)
pause
del /s /q %temp%\* 2>nul
rd /s /q %temp% 2>nul
md %temp%
pause
set "folder=C:\Windows\Temp"
if exist "%folder%" (
    del /q "%folder%\*.*"
    echo Tutti i file nella cartella "%folder%" sono stati eliminati.
) else (
    echo La cartella specificata non esiste.
)
@echo off
echo [13/13] Vuoi far partire l'antivirus? (si/no)
set /p risposta=

rem Controllo case-insensitive e gestisco il ramo “si”
if /i "%risposta%"=="si" (
    echo Avvio della scansione con Windows Defender...
    "%ProgramFiles%\Windows Defender\MpCmdRun.exe" -Scan -ScanType 1
    if %errorlevel% equ 0 (
        echo Nessuna minaccia rilevata.
    ) else (
        echo Minacce rilevate! Controlla i dettagli in Windows Defender.
    )
    echo finito
    pause
    goto :eof
)

rem Gestisco il ramo “no”
if /i "%risposta%"=="no" (
    rem Creo un file VBScript per mostrare il prompt
    > "%temp%\prompt_riavvio.vbs" echo result = MsgBox( _
    >> "%temp%\prompt_riavvio.vbs" echo "Per completare le modifiche, è consigliato riavviare il PC.", _
    >> "%temp%\prompt_riavvio.vbs" echo vbOKCancel + vbExclamation, _
    >> "%temp%\prompt_riavvio.vbs" echo "Riavvio necessario"^)

    >> "%temp%\prompt_riavvio.vbs" echo If result = vbOK Then WScript.Shell.Run "shutdown /r /t 0",1,False

    rem Eseguo il VBScript
    cscript //nologo "%temp%\prompt_riavvio.vbs"
    del "%temp%\prompt_riavvio.vbs"

    echo finito
    pause
    goto :eof
)
rem Risposta non valida
echo Risposta non valida. Inserisci “si” o “no” e riprova.
pause

