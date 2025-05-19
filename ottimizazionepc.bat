@echo off
echo ================================
echo Ottimizzazione del PC in corso...
echo ================================
sfc /scannow
echo controllo sistema operativo
DISM /Online /Cleanup-Image /RestoreHealth
echo Controllo disco (chkdsk)...
chkdsk C: /scan
timeout /t 5 >nul
echo Pulizia Windows Update...
net stop wuauserv >nul 2>&1
del /f /s /q %windir%\SoftwareDistribution\Download\* >nul 2>&1
net start wuauserv >nul 2>&1
timeout /t 5 >nul
echo Avvio Pulizia disco automatica...
cleanmgr /sagerun:1
timeout /t 5 >nul
echo Pulizia file di log...
del /f /s /q C:\Windows\Logs\*.* >nul 2>&1
timeout /t 3 >nul
echo Pulizia cartelle temporanee dell'utente...
del /s /q "%USERPROFILE%\AppData\Local\Microsoft\Windows\INetCache\*" >nul 2>&1
del /s /q "%USERPROFILE%\AppData\Local\Microsoft\Windows\Temporary Internet Files\*" >nul 2>&1
timeout /t 5 >nul
echo Controllo stato SMART del disco...
wmic diskdrive get status
timeout /t 5 >nul
echo Pulizia avanzata rete...
nbtstat -R
nbtstat -RR
arp -d *
timeout /t 5 >nul

echo Ottimizzazione del disco...
defrag C: /O
echo ottimizzazione dns
ipconfig /flushdns
echo Disattivazione temporanea servizi inutili...
net stop DiagTrack >nul 2>&1  :: Servizio di tracciamento diagnostico
net stop WSearch >nul 2>&1    :: Ricerca indicizzata di Windows
net stop Fax >nul 2>&1
net stop RetailDemo >nul 2>&1
timeout /t 5 >nul

echo aggiornamento app pc
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
echo Vuoi far partire l'antivirs? (si/no) 
set/p risposta=
if [%risposta%]==[si]:: Mini Antivirus - Scansione con Windows Defender
echo Avvio della scansione con Windows Defender...
"%ProgramFiles%\Windows Defender\MpCmdRun.exe" -Scan -ScanType 1
if %errorlevel% equ 0 (
    echo Nessuna minaccia rilevata.
) else (
    echo Minacce rilevate! Controlla i dettagli in Windows Defender.
)

if [%risposta%]==[no]:: Notifica per il riavvio del PC
Add-Type -TypeDefinition @"
using System;
using System.Windows.Forms;

public class RestartPrompt
{
    public static void ShowMessage()
    {
        DialogResult result = MessageBox.Show("Per completare le modifiche, è consigliato riavviare il PC.", "Riavvio necessario", MessageBoxButtons.OKCancel, MessageBoxIcon.Warning);
        
        if (result == DialogResult.OK)
        {
            System.Diagnostics.Process.Start("shutdown", "/r /t 0");
        }
    }
}
"@ -Language CSharp

[RestartPrompt]::ShowMessage()
echo finito
pause


