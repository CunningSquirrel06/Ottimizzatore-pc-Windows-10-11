@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title Manutenzione automatica PC - v3.0
color 0B

rem ============================================================
rem MANUTENZIONE AUTOMATICA PC v3.0
rem Nessun menu: esegue i controlli in sequenza e registra i risultati.
rem Non cancella log/Prefetch, non disattiva servizi e non riavvia da solo.
rem ============================================================

rem Richiede privilegi amministrativi.
fltmc >nul 2>&1
if errorlevel 1 (
    echo Richiesta autorizzazione amministratore...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

set "ROOT=%ProgramData%\ManutenzionePC"
set "LOGDIR=%ROOT%\Logs"
set "BACKUPDIR=%ROOT%\Backups"
if not exist "%LOGDIR%" md "%LOGDIR%" >nul 2>&1
if not exist "%BACKUPDIR%" md "%BACKUPDIR%" >nul 2>&1

for /f %%I in ('powershell.exe -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss" 2^>nul') do set "STAMP=%%I"
if not defined STAMP set "STAMP=%RANDOM%_%RANDOM%"
set "LOG=%LOGDIR%\Manutenzione_%STAMP%.log"
set "TI_OK=0"
set "TI_FILE_OK=0"
set "TI_PATH_OK=0"
set "ERRORS=0"
set "WARNINGS=0"

>"%LOG%" echo MANUTENZIONE AUTOMATICA PC v3.0
>>"%LOG%" echo Avvio: %date% %time%
>>"%LOG%" echo Computer: %COMPUTERNAME%
>>"%LOG%" echo Utente: %USERDOMAIN%\%USERNAME%
>>"%LOG%" echo ============================================================

echo.
echo ============================================================
echo          MANUTENZIONE AUTOMATICA PC - v3.0
echo ============================================================
echo Il programma eseguira' i controlli in automatico.
echo Non spegnera' e non riavviera' il computer.
echo Registro: %LOG%
echo.
call :Log "Avvio manutenzione automatica."

call :Section "1/10 - Informazioni e punto di ripristino"
(ver & echo. & systeminfo | findstr /B /C:"Nome SO" /C:"Versione SO" /C:"OS Name" /C:"OS Version" /C:"Nome sistema operativo" /C:"Versione sistema operativo") >>"%LOG%" 2>&1
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { Checkpoint-Computer -Description 'Manutenzione automatica PC' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop; Write-Output 'Punto di ripristino creato.'; exit 0 } catch { Write-Output ('Punto di ripristino non creato: ' + $_.Exception.Message); exit 1 }" >>"%LOG%" 2>&1
if errorlevel 1 (
    set /a WARNINGS+=1
    call :Log "Avviso: punto di ripristino non creato (protezione sistema disattivata o limite temporale)."
) else (
    call :Log "Punto di ripristino: operazione completata o richiesta accettata."
)

call :Section "2/10 - Verifica e ripristino controllato di TrustedInstaller"
call :Log "Verifica presenza e firma digitale di TrustedInstaller.exe."
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$f=Join-Path $env:windir 'servicing\TrustedInstaller.exe'; if(-not (Test-Path -LiteralPath $f)){Write-Output 'TrustedInstaller.exe non trovato.'; exit 2}; $s=Get-AuthenticodeSignature -LiteralPath $f; Write-Output ('Firma: ' + $s.Status); if($s.SignerCertificate){Write-Output ('Firmatario: ' + $s.SignerCertificate.Subject)}; if($s.Status -eq 'Valid' -and $s.SignerCertificate.Subject -match 'Microsoft'){exit 0}else{exit 3}" >>"%LOG%" 2>&1
if errorlevel 1 (
    set /a ERRORS+=1
    call :Log "ERRORE: TrustedInstaller.exe manca o la firma Microsoft non e' verificabile. Nessuna modifica automatica al servizio."
) else (
    set "TI_FILE_OK=1"
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p=(Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\TrustedInstaller' -Name ImagePath -ErrorAction Stop).ImagePath; $expected=Join-Path $env:windir 'servicing\TrustedInstaller.exe'; $p=[Environment]::ExpandEnvironmentVariables($p).Trim([char]34); Write-Output ('ImagePath attuale: ' + $p); Write-Output ('ImagePath atteso:  ' + $expected); if($p -ieq $expected){exit 0}else{exit 10}" >>"%LOG%" 2>&1
    if errorlevel 1 (
        call :Log "TrustedInstaller ha un percorso non standard: preparo un backup prima del ripristino."
        reg.exe export "HKLM\SYSTEM\CurrentControlSet\Services\TrustedInstaller" "%BACKUPDIR%\TrustedInstaller_%STAMP%.reg" /y >>"%LOG%" 2>&1
        if errorlevel 1 (
            set /a ERRORS+=1
            call :Log "ERRORE: backup del registro non riuscito. TrustedInstaller non e' stato modificato."
        ) else (
            sc.exe config TrustedInstaller binPath= "%windir%\servicing\TrustedInstaller.exe" >>"%LOG%" 2>&1
            if errorlevel 1 (
                set /a ERRORS+=1
                call :Log "ERRORE: impossibile ripristinare ImagePath di TrustedInstaller."
            ) else (
                call :Log "ImagePath di TrustedInstaller ripristinato; backup salvato in %BACKUPDIR%."
            )
        )
    ) else (
        call :Log "ImagePath di TrustedInstaller gia' corretto."
    )

    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p=(Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\TrustedInstaller' -Name ImagePath -ErrorAction Stop).ImagePath; $e=Join-Path $env:windir 'servicing\TrustedInstaller.exe'; $p=[Environment]::ExpandEnvironmentVariables($p).Trim([char]34); if($p -ieq $e){exit 0}else{exit 1}" >>"%LOG%" 2>&1
    if errorlevel 1 (
        set /a ERRORS+=1
        call :Log "ERRORE: il percorso TrustedInstaller non risulta corretto dopo il tentativo."
    ) else (
        set "TI_PATH_OK=1"
        sc.exe config TrustedInstaller start= demand >>"%LOG%" 2>&1
        call :Log "Verifica avvio del servizio TrustedInstaller."
        sc.exe start TrustedInstaller >>"%LOG%" 2>&1
        for /L %%N in (1,1,10) do (
            if "!TI_OK!"=="0" (
                powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$s=Get-Service -Name TrustedInstaller -ErrorAction SilentlyContinue; if($s -and $s.Status -eq 'Running'){exit 0}else{exit 1}" >nul 2>&1
                if not errorlevel 1 set "TI_OK=1"
                if "!TI_OK!"=="0" timeout /t 2 /nobreak >nul
            )
        )
        if "!TI_OK!"=="1" (
            call :Log "TrustedInstaller avviato correttamente."
        ) else (
            set /a ERRORS+=1
            call :Log "ERRORE: TrustedInstaller non si e' avviato. DISM e SFC verranno saltati per evitare riparazioni incomplete."
        )
    )
)

call :Section "3/10 - Riparazione immagine Windows e file di sistema"
if "!TI_OK!"=="1" (
    call :Log "Esecuzione DISM RestoreHealth."
    "%windir%\System32\Dism.exe" /Online /Cleanup-Image /RestoreHealth >>"%LOG%" 2>&1
    set "DISM_RC=!errorlevel!"
    if "!DISM_RC!"=="0" (
        call :Log "DISM completato correttamente."
    ) else if "!DISM_RC!"=="3010" (
        set /a WARNINGS+=1
        call :Log "DISM completato: e' richiesto un riavvio (codice 3010)."
    ) else (
        set /a ERRORS+=1
        call :Log "ERRORE DISM: codice !DISM_RC!. Consultare il log DISM/CBS e il rapporto di manutenzione."
    )
    call :Log "Esecuzione SFC /scannow."
    sfc.exe /scannow >>"%LOG%" 2>&1
    set "SFC_RC=!errorlevel!"
    if "!SFC_RC!"=="0" (
        call :Log "SFC terminato. Verificare il messaggio finale nel log."
    ) else (
        set /a WARNINGS+=1
        call :Log "SFC ha restituito il codice !SFC_RC!. Verificare il messaggio finale nel log."
    )
) else (
    set /a WARNINGS+=1
    call :Log "Saltati DISM e SFC: TrustedInstaller non e' disponibile."
)

call :Section "4/10 - Controllo del file system"
call :Log "CHKDSK online scan sull'unita' di sistema."
chkdsk.exe %SystemDrive% /scan >>"%LOG%" 2>&1
if errorlevel 1 (
    set /a WARNINGS+=1
    call :Log "Avviso: CHKDSK ha segnalato un problema o richiede ulteriori controlli."
) else (
    call :Log "CHKDSK terminato. Consultare l'esito dettagliato nel log."
)

call :Section "5/10 - Stato di salute dei dischi"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { Get-PhysicalDisk -ErrorAction Stop | Select-Object FriendlyName,MediaType,HealthStatus,OperationalStatus,Size | Format-Table -AutoSize | Out-String -Width 220; exit 0 } catch { Write-Output ('Stato SMART/PhysicalDisk non disponibile: ' + $_.Exception.Message); exit 1 }" >>"%LOG%" 2>&1
if errorlevel 1 set /a WARNINGS+=1

call :Section "6/10 - Pulizia sicura dei file temporanei"
call :Log "Eliminazione dei soli file temporanei piu' vecchi di 7 giorni; file in uso ignorati."
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$cut=(Get-Date).AddDays(-7); $roots=@($env:TEMP,(Join-Path $env:windir 'Temp')); foreach($r in $roots){if(Test-Path -LiteralPath $r){Get-ChildItem -LiteralPath $r -File -Force -Recurse -ErrorAction SilentlyContinue | Where-Object {$_.LastWriteTime -lt $cut} | ForEach-Object {Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue}; Get-ChildItem -LiteralPath $r -Directory -Force -Recurse -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | ForEach-Object {if(-not (Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue | Select-Object -First 1)){Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue}}}}; Write-Output 'Pulizia temporanei terminata (elementi in uso lasciati intatti).'; exit 0" >>"%LOG%" 2>&1
if errorlevel 1 set /a WARNINGS+=1

call :Section "7/10 - Aggiornamento applicazioni installate"
where.exe winget.exe >nul 2>&1
if errorlevel 1 (
    set /a WARNINGS+=1
    call :Log "WinGet non disponibile: aggiornamento applicazioni saltato."
) else (
    call :Log "Aggiornamento sorgenti WinGet."
    winget.exe source update --disable-interactivity >>"%LOG%" 2>&1
    call :Log "Aggiornamento automatico dei pacchetti disponibili (modalita' silenziosa)."
    winget.exe upgrade --all --silent --accept-package-agreements --accept-source-agreements --disable-interactivity >>"%LOG%" 2>&1
    set "WINGET_RC=!errorlevel!"
    if not "!WINGET_RC!"=="0" (
        set /a WARNINGS+=1
        call :Log "WinGet ha restituito il codice !WINGET_RC!: alcuni pacchetti potrebbero richiedere installazione manuale."
    ) else (
        call :Log "WinGet ha terminato il ciclo di aggiornamento."
    )
)

call :Section "8/10 - Aggiornamento firme e scansione antivirus"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { Update-MpSignature -ErrorAction Stop; Write-Output 'Firme Defender aggiornate.'; Start-MpScan -ScanType QuickScan -ErrorAction Stop; Write-Output 'Scansione rapida Defender avviata/completata.'; exit 0 } catch { Write-Output ('Microsoft Defender non disponibile o scansione non riuscita: ' + $_.Exception.Message); exit 1 }" >>"%LOG%" 2>&1
if errorlevel 1 (
    set /a WARNINGS+=1
    call :Log "Avviso: Defender potrebbe essere disattivato, gestito da un antivirus di terze parti o non disponibile."
) else (
    call :Log "Operazione Microsoft Defender terminata."
)

call :Section "9/10 - Rete, ottimizzazione unita' e report batteria"
ipconfig.exe /flushdns >>"%LOG%" 2>&1
call :Log "Cache DNS svuotata."
defrag.exe /C /O /U /V >>"%LOG%" 2>&1
if errorlevel 1 (
    set /a WARNINGS+=1
    call :Log "Avviso: ottimizzazione unita' non completata su uno o piu' volumi."
) else (
    call :Log "Ottimizzazione unita' terminata."
)
powercfg.exe /batteryreport /output "%ROOT%\BatteryReport_%STAMP%.html" >>"%LOG%" 2>&1
if errorlevel 1 (
    call :Log "Report batteria non disponibile (normale su PC senza batteria compatibile)."
) else (
    call :Log "Report batteria salvato in %ROOT%."
)

call :Section "10/10 - Chiusura e riepilogo"
>>"%LOG%" echo ============================================================
>>"%LOG%" echo Fine: %date% %time%
>>"%LOG%" echo Errori bloccanti/operativi registrati: !ERRORS!
>>"%LOG%" echo Avvisi registrati: !WARNINGS!
call :Log "Manutenzione terminata. Errori: !ERRORS! - Avvisi: !WARNINGS!."
echo.
echo ============================================================
echo MANUTENZIONE COMPLETATA
echo ============================================================
echo Errori registrati: !ERRORS!
echo Avvisi registrati: !WARNINGS!
echo.
echo Log completo: %LOG%
echo Backup configurazione: %BACKUPDIR%
echo.
echo Il PC NON verra' riavviato automaticamente.
echo Salva il tuo lavoro e riavvia se Windows o il log lo richiedono.
echo.
start "" notepad.exe "%LOG%"
pause
exit /b 0

:Section
echo.
echo [%~1]
>>"%LOG%" echo.
>>"%LOG%" echo [%~1]
exit /b 0

:Log
echo [%date% %time%] %~1
>>"%LOG%" echo [%date% %time%] %~1
exit /b 0
