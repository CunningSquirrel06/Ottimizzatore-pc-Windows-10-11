@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul
title Manutenzione automatica PC v4.6 - file unico

REM Percorso esatto di questo BAT e log diagnostico del launcher.
set "MANUTENZIONE_SELF=%~f0"
set "MANUTENZIONE_RUNTIME_LOG=%TEMP%\ManutenzionePC_Avvio_%RANDOM%_%RANDOM%.log"
>"%MANUTENZIONE_RUNTIME_LOG%" echo Avvio launcher: %DATE% %TIME%
>>"%MANUTENZIONE_RUNTIME_LOG%" echo File: %MANUTENZIONE_SELF%

REM Verifica privilegi amministrativi.
fltmc >nul 2>&1
if errorlevel 1 (
    echo.
    echo Richiesta autorizzazione amministratore...
    echo Dopo aver scelto SI nella finestra UAC, si aprira' la manutenzione.
    echo.
    REM Usa .NET ProcessStartInfo con ShellExecute=RunAs. Evita il conflitto
    REM di parameter set di Start-Process quando si combinano -Verb, -Wait e -PassThru.
    REM Il processo elevato riparte dallo stesso file BAT e continua autonomamente.
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
      "$ErrorActionPreference='Stop'; try { $bat=$env:MANUTENZIONE_SELF; if(-not (Test-Path -LiteralPath $bat)){throw 'File BAT originale non trovato'}; $wd=[System.IO.Path]::GetDirectoryName($bat); $psi=New-Object System.Diagnostics.ProcessStartInfo; $psi.FileName=$env:ComSpec; $q=[char]34; $psi.Arguments='/d /c ' + $q + $q + $bat + $q + $q; $psi.WorkingDirectory=$wd; $psi.UseShellExecute=$true; $psi.Verb='runas'; $psi.WindowStyle=[System.Diagnostics.ProcessWindowStyle]::Normal; $child=[System.Diagnostics.Process]::Start($psi); if(-not $child){throw 'Windows non ha avviato il processo elevato'}; exit 0 } catch { $_ | Out-String | Add-Content -LiteralPath $env:MANUTENZIONE_RUNTIME_LOG -Encoding UTF8; Write-Host 'Avvio amministratore non riuscito:'; Write-Host $_.Exception.Message; Write-Host ('Dettagli: ' + $env:MANUTENZIONE_RUNTIME_LOG); Read-Host 'Premi Invio per chiudere'; exit 1 }"
    set "UAC_RESULT=%ERRORLEVEL%"
    if not "%UAC_RESULT%"=="0" (
        echo.
        echo L'avvio elevato non e' riuscito. Dettagli:
        echo %MANUTENZIONE_RUNTIME_LOG%
        pause
    )
    exit /b %UAC_RESULT%
)

>>"%MANUTENZIONE_RUNTIME_LOG%" echo Privilegi amministrativi: OK
set "MANUTENZIONE_TEMP_SCRIPT=%TEMP%\ManutenzionePC_%RANDOM%_%RANDOM%.ps1"

REM Estrae il motore PowerShell incorporato nel BAT.
echo Preparazione del programma...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; try { $p=$env:MANUTENZIONE_SELF; $t=[IO.File]::ReadAllText($p,[Text.Encoding]::UTF8); $m=[regex]::Match($t,'(?m)^###POWERSHELL_PAYLOAD###\r?\n'); if(-not $m.Success){throw 'Contenuto interno non trovato'}; $body=$t.Substring($m.Index+$m.Length); [IO.File]::WriteAllText($env:MANUTENZIONE_TEMP_SCRIPT,$body,(New-Object System.Text.UTF8Encoding($true))); Write-Output 'Estrazione motore PowerShell: OK' } catch { Write-Error $_; exit 2 }" >>"%MANUTENZIONE_RUNTIME_LOG%" 2>&1
if errorlevel 1 (
    echo ERRORE: impossibile preparare il motore interno.
    echo Consulta: %MANUTENZIONE_RUNTIME_LOG%
    type "%MANUTENZIONE_RUNTIME_LOG%"
    pause
    exit /b 2
)
if not exist "%MANUTENZIONE_TEMP_SCRIPT%" (
    echo ERRORE: motore interno non trovato.
    echo Consulta: %MANUTENZIONE_RUNTIME_LOG%
    type "%MANUTENZIONE_RUNTIME_LOG%"
    pause
    exit /b 3
)

>>"%MANUTENZIONE_RUNTIME_LOG%" echo Avvio interfaccia PowerShell...
echo Avvio interfaccia grafica di manutenzione...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "%MANUTENZIONE_TEMP_SCRIPT%" >>"%MANUTENZIONE_RUNTIME_LOG%" 2>&1
set "RESULT=%ERRORLEVEL%"
>>"%MANUTENZIONE_RUNTIME_LOG%" echo Codice uscita PowerShell: %RESULT%

if exist "%MANUTENZIONE_TEMP_SCRIPT%" del /f /q "%MANUTENZIONE_TEMP_SCRIPT%" >nul 2>&1
if not "%RESULT%"=="0" (
    echo.
    echo ERRORE: il motore di manutenzione si e' chiuso con codice %RESULT%.
    echo Registro diagnostico: %MANUTENZIONE_RUNTIME_LOG%
    echo.
    type "%MANUTENZIONE_RUNTIME_LOG%"
    echo.
    pause
)
endlocal & exit /b %RESULT%

###POWERSHELL_PAYLOAD###
#requires -Version 5.1
# Manutenzione automatica PC v4.6 - file unico - interfaccia con avanzamento per fase
$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Il launcher BAT gestisce UAC prima di estrarre questo motore.
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    [System.Windows.Forms.MessageBox]::Show('Avvia il programma tramite il file BAT originale e conferma la richiesta UAC.','Manutenzione PC') | Out-Null
    exit 1
}

[System.Windows.Forms.Application]::EnableVisualStyles()

$root = Join-Path $env:ProgramData 'ManutenzionePC'
$logDir = Join-Path $root 'Logs'
$backupDir = Join-Path $root 'Backups'
$taskDir = Join-Path ([System.IO.Path]::GetTempPath()) ('ManutenzionePC_Tasks_' + [Guid]::NewGuid().ToString('N'))
foreach ($dir in @($root,$logDir,$backupDir,$taskDir)) {
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
}
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logPath = Join-Path $logDir "Manutenzione_$stamp.log"
$script:LogPath = $logPath

@"
MANUTENZIONE AUTOMATICA PC v4.3
Avvio: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')
Computer: $env:COMPUTERNAME
Utente: $env:USERDOMAIN\$env:USERNAME
============================================================
"@ | Set-Content -LiteralPath $logPath -Encoding UTF8

# Script di supporto: punto di ripristino.
$restorePointScript = @'
try {
    Checkpoint-Computer -Description 'Manutenzione automatica PC' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
    Write-Output 'Punto di ripristino creato.'
    exit 0
} catch {
    Write-Output ('Punto di ripristino non creato: ' + $_.Exception.Message)
    exit 1
}
'@

# Ripristino TrustedInstaller solo se il file è presente e firmato validamente da Microsoft.
$trustedInstallerScript = @'
$regPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\TrustedInstaller'
$exe = Join-Path $env:windir 'servicing\TrustedInstaller.exe'
if (-not (Test-Path -LiteralPath $exe)) { Write-Output 'ERRORE: TrustedInstaller.exe non trovato.'; exit 20 }
$sig = Get-AuthenticodeSignature -LiteralPath $exe
$signerSubject = if ($sig.SignerCertificate) { $sig.SignerCertificate.Subject } else { '' }
Write-Output ('Firma digitale: ' + $sig.Status)
if ($signerSubject) { Write-Output ('Firmatario: ' + $signerSubject) }
if ($sig.Status -ne 'Valid' -or -not $signerSubject.Contains('Microsoft')) {
    Write-Output 'ERRORE: impossibile verificare una firma Microsoft valida. Il servizio non verrà modificato.'
    exit 21
}
try {
    $current = (Get-ItemProperty -Path $regPath -Name ImagePath -ErrorAction Stop).ImagePath
    $expanded = [Environment]::ExpandEnvironmentVariables($current).Trim([char]34)
    Write-Output ('Percorso attuale: ' + $expanded)
    Write-Output ('Percorso previsto: ' + $exe)
    if ($expanded -ine $exe) {
        $backup = Join-Path $env:ProgramData ('ManutenzionePC\Backups\TrustedInstaller_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.reg')
        & reg.exe export 'HKLM\SYSTEM\CurrentControlSet\Services\TrustedInstaller' $backup /y | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Output 'ERRORE: backup registro non riuscito; modifica annullata.'; exit 22 }
        Write-Output ('Backup registro: ' + $backup)
        & sc.exe config TrustedInstaller binPath= $exe
        if ($LASTEXITCODE -ne 0) { Write-Output 'ERRORE: impossibile ripristinare ImagePath.'; exit 23 }
        Write-Output 'Percorso del servizio ripristinato.'
    } else { Write-Output 'Percorso del servizio già corretto.' }
    & sc.exe config TrustedInstaller start= demand
    if ($LASTEXITCODE -ne 0) { Write-Output 'AVVISO: impossibile aggiornare il tipo di avvio.' }
    try {
        Start-Service -Name TrustedInstaller -ErrorAction Stop
        Write-Output 'Richiesta di avvio TrustedInstaller inviata correttamente.'
    } catch {
        # Se il servizio è già avviato, non è un errore.
        $svc = Get-Service -Name TrustedInstaller -ErrorAction SilentlyContinue
        if (-not $svc -or $svc.Status -ne 'Running') {
            Write-Output ('ERRORE avvio TrustedInstaller: ' + $_.Exception.Message)
            exit 24
        }
    }
    Start-Sleep -Seconds 2
    $svc = Get-Service -Name TrustedInstaller -ErrorAction SilentlyContinue
    if ($svc) { Write-Output ('Stato servizio dopo la richiesta: ' + $svc.Status) }
    exit 0
} catch {
    Write-Output ('ERRORE TrustedInstaller: ' + $_.Exception.Message)
    exit 25
}
'@

# Pulizia temporanei con conteggio e percentuale della fase.
$cleanupScript = @'
$cutoff = (Get-Date).AddDays(-7)
$roots = @($env:TEMP, (Join-Path $env:windir 'Temp')) | Select-Object -Unique
$files = New-Object System.Collections.Generic.List[System.IO.FileInfo]
foreach ($root in $roots) {
    if (Test-Path -LiteralPath $root) {
        Get-ChildItem -LiteralPath $root -File -Force -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoff } |
            ForEach-Object { [void]$files.Add($_) }
    }
}
$total = $files.Count
Write-Output ("Elementi temporanei da esaminare: $total")
if ($total -eq 0) { Write-Output 'Nessun file temporaneo più vecchio di 7 giorni.'; exit 0 }
$removed = 0
$step = [Math]::Max(1, [Math]::Floor($total / 100))
for ($i = 0; $i -lt $total; $i++) {
    try { Remove-Item -LiteralPath $files[$i].FullName -Force -ErrorAction Stop; $removed++ } catch { }
    if ((($i + 1) % $step) -eq 0 -or ($i + 1) -eq $total) {
        $pct = [int](100 * ($i + 1) / $total)
        Write-Output ("Pulizia: $pct%")
    }
}
Write-Output ("Pulizia terminata. File eliminati: $removed di $total. File in uso o non accessibili lasciati intatti.")
exit 0
'@

# Controllo stato dischi.
$diskHealthScript = @'
try {
    $disks = Get-PhysicalDisk -ErrorAction Stop
    if (-not $disks) { Write-Output 'Nessun disco fisico esposto dal provider Storage.'; exit 0 }
    $disks | Select-Object FriendlyName,MediaType,HealthStatus,OperationalStatus,Size | Format-Table -AutoSize | Out-String -Width 220 | Write-Output
    $bad = $disks | Where-Object { $_.HealthStatus -notin @('Healthy','Unknown') -or $_.OperationalStatus -contains 'Degraded' }
    if ($bad) { Write-Output 'AVVISO: uno o più dischi segnalano uno stato da verificare.'; exit 2 }
    exit 0
} catch { Write-Output ('Stato dischi non disponibile tramite provider Storage: ' + $_.Exception.Message); exit 1 }
'@

# Microsoft Defender: aggiornamento firme e scansione rapida.
$defenderScript = @'
try {
    Update-MpSignature -ErrorAction Stop
    Write-Output 'Aggiornamento firme Microsoft Defender completato.'
} catch { Write-Output ('Aggiornamento firme non disponibile: ' + $_.Exception.Message); exit 1 }
try {
    Start-MpScan -ScanType QuickScan -ErrorAction Stop
    Write-Output 'Richiesta scansione rapida Defender completata.'
    exit 0
} catch { Write-Output ('Scansione Defender non disponibile o non completata: ' + $_.Exception.Message); exit 2 }
'@

$taskScripts = @{
    'RestorePoint.ps1' = $restorePointScript
    'TrustedInstaller.ps1' = $trustedInstallerScript
    'CleanupTemp.ps1' = $cleanupScript
    'DiskHealth.ps1' = $diskHealthScript
    'Defender.ps1' = $defenderScript
}
foreach ($name in $taskScripts.Keys) {
    Set-Content -LiteralPath (Join-Path $taskDir $name) -Value $taskScripts[$name] -Encoding UTF8
}

# Interfaccia grafica
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Manutenzione automatica PC v4.3 - file unico'
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size(820, 660)
$form.MinimumSize = New-Object System.Drawing.Size(760, 600)
$form.BackColor = [System.Drawing.Color]::FromArgb(245,247,250)
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$form.MaximizeBox = $false

$header = New-Object System.Windows.Forms.Label
$header.Text = 'MANUTENZIONE AUTOMATICA PC'
$header.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 17, [System.Drawing.FontStyle]::Bold)
$header.ForeColor = [System.Drawing.Color]::FromArgb(25,55,85)
$header.Location = New-Object System.Drawing.Point(24,18)
$header.Size = New-Object System.Drawing.Size(740,36)
$form.Controls.Add($header)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = 'Esecuzione automatica · avanzamento generale e della singola operazione'
$subtitle.Location = New-Object System.Drawing.Point(27,58)
$subtitle.Size = New-Object System.Drawing.Size(740,24)
$subtitle.ForeColor = [System.Drawing.Color]::FromArgb(85,96,110)
$form.Controls.Add($subtitle)

$overallLabel = New-Object System.Windows.Forms.Label
$overallLabel.Text = 'Avanzamento complessivo: 0%'
$overallLabel.Location = New-Object System.Drawing.Point(27,100)
$overallLabel.Size = New-Object System.Drawing.Size(740,22)
$overallLabel.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($overallLabel)

$overallBar = New-Object System.Windows.Forms.ProgressBar
$overallBar.Location = New-Object System.Drawing.Point(27,126)
$overallBar.Size = New-Object System.Drawing.Size(750,22)
$overallBar.Minimum = 0; $overallBar.Maximum = 100; $overallBar.Value = 0
$overallBar.Style = 'Continuous'
$form.Controls.Add($overallBar)

$phaseLabel = New-Object System.Windows.Forms.Label
$phaseLabel.Text = 'Preparazione...'
$phaseLabel.Location = New-Object System.Drawing.Point(27,166)
$phaseLabel.Size = New-Object System.Drawing.Size(750,24)
$phaseLabel.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 11, [System.Drawing.FontStyle]::Bold)
$phaseLabel.ForeColor = [System.Drawing.Color]::FromArgb(20,70,110)
$form.Controls.Add($phaseLabel)

$stepStatus = New-Object System.Windows.Forms.Label
$stepStatus.Text = 'In attesa di avvio'
$stepStatus.Location = New-Object System.Drawing.Point(27,194)
$stepStatus.Size = New-Object System.Drawing.Size(750,24)
$stepStatus.ForeColor = [System.Drawing.Color]::FromArgb(75,85,95)
$form.Controls.Add($stepStatus)

$stepBar = New-Object System.Windows.Forms.ProgressBar
$stepBar.Location = New-Object System.Drawing.Point(27,224)
$stepBar.Size = New-Object System.Drawing.Size(750,24)
$stepBar.Minimum = 0; $stepBar.Maximum = 100; $stepBar.Value = 0
$stepBar.Style = 'Marquee'
$stepBar.MarqueeAnimationSpeed = 24
$form.Controls.Add($stepBar)

$progressHint = New-Object System.Windows.Forms.Label
$progressHint.Text = 'La barra della fase usa le percentuali fornite da Windows quando disponibili; altrimenti indica che la fase e in corso.'
$progressHint.Location = New-Object System.Drawing.Point(27,253)
$progressHint.Size = New-Object System.Drawing.Size(750,30)
$progressHint.ForeColor = [System.Drawing.Color]::FromArgb(100,105,115)
$form.Controls.Add($progressHint)

$logLabel = New-Object System.Windows.Forms.Label
$logLabel.Text = 'Registro attività in tempo reale'
$logLabel.Location = New-Object System.Drawing.Point(27,292)
$logLabel.Size = New-Object System.Drawing.Size(750,22)
$logLabel.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($logLabel)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(27,318)
$logBox.Size = New-Object System.Drawing.Size(750,220)
$logBox.Multiline = $true
$logBox.ReadOnly = $true
$logBox.ScrollBars = 'Vertical'
$logBox.WordWrap = $false
$logBox.Font = New-Object System.Drawing.Font('Consolas', 8.5)
$logBox.BackColor = [System.Drawing.Color]::White
$form.Controls.Add($logBox)

$logPathLabel = New-Object System.Windows.Forms.Label
$logPathLabel.Text = "Registro: $logPath"
$logPathLabel.Location = New-Object System.Drawing.Point(27,548)
$logPathLabel.Size = New-Object System.Drawing.Size(750,28)
$logPathLabel.ForeColor = [System.Drawing.Color]::FromArgb(90,95,105)
$form.Controls.Add($logPathLabel)

$openLogButton = New-Object System.Windows.Forms.Button
$openLogButton.Text = 'Apri registro'
$openLogButton.Location = New-Object System.Drawing.Point(27,580)
$openLogButton.Size = New-Object System.Drawing.Size(110,30)
$openLogButton.Enabled = $false
$openLogButton.Add_Click({ Start-Process notepad.exe -ArgumentList ('"' + $logPath + '"') })
$form.Controls.Add($openLogButton)

$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Text = 'Chiudi'
$closeButton.Location = New-Object System.Drawing.Point(667,580)
$closeButton.Size = New-Object System.Drawing.Size(110,30)
$closeButton.Enabled = $false
$closeButton.Add_Click({ $form.Close() })
$form.Controls.Add($closeButton)

# Runspace dedicato: mantiene reattiva la finestra anche durante DISM/SFC.
# La barra della fase legge le percentuali reali dai programmi quando disponibili.
$script:UiQueue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]'
$script:PowerShellInstance = $null
$script:RunspaceInstance = $null
$script:AsyncResult = $null

$workerScript = {
    param($queue, $ctx)
    $ErrorActionPreference = 'Continue'
    $totalStages = 13
    $errors = 0
    $warnings = 0
    $tiReady = $false

    function Add-LogLine([string]$message) {
        $line = '[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $message
        Add-Content -LiteralPath $ctx.LogPath -Value $line -Encoding UTF8
        [void]$queue.Enqueue([pscustomobject]@{ Kind='Log'; Text=$line })
    }
    function Set-Stage([int]$number, [string]$name) {
        $ctx.CurrentStage = $name
        $overall = [int](100 * ($number - 1) / $totalStages)
        [void]$queue.Enqueue([pscustomobject]@{ Kind='Stage'; Overall=$overall; Stage=$number; Total=$totalStages; Name=$name; StepPercent=0; Mode='Marquee'; Status='Avvio fase...' })
        Add-LogLine("FASE $number/$totalStages - $name")
    }
    function Set-SubProgress([int]$number, [int]$percent, [string]$status, [bool]$determinate) {
        $overall = [int](100 * (($number - 1) + ($percent / 100)) / $totalStages)
        $mode = if ($determinate) { 'Continuous' } else { 'Marquee' }
        [void]$queue.Enqueue([pscustomobject]@{ Kind='Progress'; Overall=$overall; Stage=$number; Total=$totalStages; Name=$ctx.CurrentStage; StepPercent=[Math]::Max(0,[Math]::Min(100,$percent)); Mode=$mode; Status=$status })
    }
    function Invoke-Native([string]$file, [string]$arguments, [int]$stage, [string]$description, [bool]$parsePercent=$true) {
        Add-LogLine("Avvio: $description")
        Set-SubProgress $stage 0 "$description — avvio" $false
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $file
        $psi.Arguments = $arguments
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        try {
            if (-not $proc.Start()) { throw 'Avvio del processo non riuscito.' }
            $stdoutTask = $proc.StandardOutput.ReadLineAsync()
            $stderrTask = $proc.StandardError.ReadLineAsync()
            $stdoutDone = $false
            $stderrDone = $false
            $clock = [Diagnostics.Stopwatch]::StartNew()
            $lastStatus = -5
            $lastPercent = -1
            while (-not ($proc.HasExited -and $stdoutDone -and $stderrDone)) {
                if (-not $stdoutDone -and $stdoutTask.IsCompleted) {
                    try { $line = $stdoutTask.GetAwaiter().GetResult() } catch { $line = $null }
                    if ($null -eq $line) { $stdoutDone = $true }
                    else {
                        Add-LogLine($line)
                        if ($parsePercent -and $line -match '(?<!\d)(\d{1,3}(?:[\.,]\d+)?)\s*%') {
                            $pctText = $matches[1] -replace ',', '.'
                            $pct = [int][Math]::Round([double]::Parse($pctText,[Globalization.CultureInfo]::InvariantCulture))
                            if ($pct -ge 0 -and $pct -le 100 -and $pct -ne $lastPercent) { $lastPercent = $pct }
                        }
                        $stdoutTask = $proc.StandardOutput.ReadLineAsync()
                    }
                }
                if (-not $stderrDone -and $stderrTask.IsCompleted) {
                    try { $line = $stderrTask.GetAwaiter().GetResult() } catch { $line = $null }
                    if ($null -eq $line) { $stderrDone = $true }
                    else {
                        Add-LogLine($line)
                        if ($parsePercent -and $line -match '(?<!\d)(\d{1,3}(?:[\.,]\d+)?)\s*%') {
                            $pctText = $matches[1] -replace ',', '.'
                            $pct = [int][Math]::Round([double]::Parse($pctText,[Globalization.CultureInfo]::InvariantCulture))
                            if ($pct -ge 0 -and $pct -le 100 -and $pct -ne $lastPercent) { $lastPercent = $pct }
                        }
                        $stderrTask = $proc.StandardError.ReadLineAsync()
                    }
                }
                if ($clock.Elapsed.TotalSeconds -ge ($lastStatus + 3)) {
                    $lastStatus = [int]$clock.Elapsed.TotalSeconds
                    if ($lastPercent -ge 0 -and $lastPercent -lt 100) {
                        $eta = ''
                        if ($lastPercent -ge 5) {
                            $remaining = [TimeSpan]::FromSeconds([Math]::Max(0, $clock.Elapsed.TotalSeconds * (100-$lastPercent) / $lastPercent))
                            $eta = ' · stima residua ' + $remaining.ToString('hh\:mm\:ss')
                        }
                        Set-SubProgress $stage $lastPercent "$description — $lastPercent% · trascorso $($clock.Elapsed.ToString('hh\:mm\:ss'))$eta" $true
                    } elseif ($lastPercent -eq 100) {
                        Set-SubProgress $stage 100 "$description — 100%" $true
                    } else {
                        Set-SubProgress $stage 0 "$description — in corso · tempo trascorso $($clock.Elapsed.ToString('hh\:mm\:ss'))" $false
                    }
                }
                Start-Sleep -Milliseconds 100
            }
            $proc.WaitForExit()
            $code = $proc.ExitCode
            Add-LogLine("Terminato: $description — codice uscita $code")
            Set-SubProgress $stage 100 "$description — completato" $true
            return $code
        } catch {
            Add-LogLine("ERRORE avvio $description : $($_.Exception.Message)")
            return 999
        } finally {
            $proc.Dispose()
        }
    }
    function Invoke-PowerShellTask([string]$scriptName, [int]$stage, [string]$description, [bool]$parsePercent=$true) {
        $scriptPath = Join-Path $ctx.TaskDir $scriptName
        $quoted = '"' + $scriptPath + '"'
        return Invoke-Native "$env:windir\System32\WindowsPowerShell\v1.0\powershell.exe" "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File $quoted" $stage $description $parsePercent
    }

    # 1 - Informazioni e punto di ripristino
    Set-Stage 1 'Preparazione e punto di ripristino'
    Add-LogLine("Computer: $env:COMPUTERNAME | Windows: $([Environment]::OSVersion.Version)")
    $rc = Invoke-PowerShellTask 'RestorePoint.ps1' 1 'Creazione punto di ripristino' $false
    if ($rc -ne 0) { $warnings++; Add-LogLine('AVVISO: punto di ripristino non creato. La protezione sistema potrebbe essere disattivata.') }

    # 2 - TrustedInstaller
    Set-Stage 2 'Controllo e ripristino TrustedInstaller'
    $rc = Invoke-PowerShellTask 'TrustedInstaller.ps1' 2 'Verifica TrustedInstaller' $false
    if ($rc -eq 0) {
        $tiReady = $true
        Add-LogLine('TrustedInstaller verificato; proseguo con la manutenzione componenti.')
    } else {
        $errors++
        Add-LogLine('ERRORE: TrustedInstaller non è stato verificato/ripristinato. DISM e SFC verranno saltati per sicurezza.')
    }

    # 3 - DISM
    Set-Stage 3 'Riparazione immagine Windows (DISM)'
    if ($tiReady) {
        $rc = Invoke-Native "$env:windir\System32\Dism.exe" '/Online /Cleanup-Image /RestoreHealth' 3 'DISM RestoreHealth' $true
        if ($rc -ne 0 -and $rc -ne 3010) { $errors++; Add-LogLine("ERRORE DISM: codice $rc.") }
        elseif ($rc -eq 3010) { $warnings++; Add-LogLine('DISM completato: è richiesto un riavvio.') }
    } else { $warnings++; Set-SubProgress 3 100 'DISM saltato: TrustedInstaller non disponibile' $true }

    # 4 - SFC
    Set-Stage 4 'Verifica file protetti (SFC)'
    if ($tiReady) {
        $rc = Invoke-Native "$env:windir\System32\sfc.exe" '/scannow' 4 'SFC /scannow' $true
        if ($rc -ne 0) { $warnings++; Add-LogLine("AVVISO SFC: codice uscita $rc. Controllare il risultato dettagliato.") }
    } else { $warnings++; Set-SubProgress 4 100 'SFC saltato: TrustedInstaller non disponibile' $true }

    # 5 - CHKDSK
    Set-Stage 5 'Controllo file system (CHKDSK)'
    $rc = Invoke-Native "$env:windir\System32\chkdsk.exe" "$env:SystemDrive /scan" 5 'CHKDSK online scan' $true
    if ($rc -ne 0) { $warnings++; Add-LogLine("AVVISO CHKDSK: codice $rc.") }

    # 6 - Salute dischi
    Set-Stage 6 'Controllo stato SSD e HDD'
    $rc = Invoke-PowerShellTask 'DiskHealth.ps1' 6 'Lettura stato dischi' $false
    if ($rc -ne 0) { $warnings++; Add-LogLine('AVVISO: stato dischi non disponibile o da verificare.') }

    # 7 - Temporanei
    Set-Stage 7 'Pulizia temporanei non recenti'
    $rc = Invoke-PowerShellTask 'CleanupTemp.ps1' 7 'Pulizia file temporanei più vecchi di 7 giorni' $true
    if ($rc -ne 0) { $warnings++; Add-LogLine('AVVISO: pulizia temporanei terminata con segnalazioni.') }

    # 8 - WinGet sorgenti
    Set-Stage 8 'Aggiornamento sorgenti applicazioni'
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($winget) {
        $rc = Invoke-Native $winget.Source 'source update --disable-interactivity' 8 'Aggiornamento sorgenti WinGet' $false
        if ($rc -ne 0) { $warnings++; Add-LogLine("AVVISO WinGet source update: codice $rc.") }
    } else { $warnings++; Add-LogLine('WinGet non disponibile: aggiornamento applicazioni saltato.'); Set-SubProgress 8 100 'WinGet non disponibile — fase saltata' $true }

    # 9 - WinGet upgrade
    Set-Stage 9 'Aggiornamento applicazioni installate'
    if ($winget) {
        $rc = Invoke-Native $winget.Source 'upgrade --all --silent --accept-package-agreements --accept-source-agreements --disable-interactivity' 9 'Aggiornamento automatico applicazioni (WinGet)' $true
        if ($rc -ne 0) { $warnings++; Add-LogLine("AVVISO WinGet upgrade: codice $rc. Alcune app potrebbero richiedere aggiornamento manuale.") }
    } else { Set-SubProgress 9 100 'WinGet non disponibile — fase saltata' $true }

    # 10 - Defender
    Set-Stage 10 'Aggiornamento firme e scansione antivirus'
    $rc = Invoke-PowerShellTask 'Defender.ps1' 10 'Microsoft Defender — firme e scansione rapida' $false
    if ($rc -ne 0) { $warnings++; Add-LogLine('AVVISO: Microsoft Defender non disponibile, gestito da altro antivirus o scansione non riuscita.') }

    # 11 - Rete
    Set-Stage 11 'Rete e cache DNS'
    $rc = Invoke-Native "$env:windir\System32\ipconfig.exe" '/flushdns' 11 'Pulizia cache DNS' $false
    if ($rc -ne 0) { $warnings++; Add-LogLine('AVVISO: pulizia DNS non completata.') }

    # 12 - Ottimizzazione unità
    Set-Stage 12 'Ottimizzazione SSD e HDD'
    $rc = Invoke-Native "$env:windir\System32\defrag.exe" '/C /O /U /V' 12 'Ottimizzazione volumi Windows' $true
    if ($rc -ne 0) { $warnings++; Add-LogLine('AVVISO: ottimizzazione di uno o più volumi non completata.') }

    # 13 - Report batteria e riepilogo
    Set-Stage 13 'Report batteria e riepilogo'
    $batteryPath = Join-Path $ctx.Root "BatteryReport_$($ctx.Stamp).html"
    $rc = Invoke-Native "$env:windir\System32\powercfg.exe" "/batteryreport /output `"$batteryPath`"" 13 'Generazione report batteria' $false
    if ($rc -ne 0) { Add-LogLine('Report batteria non disponibile (normale su alcuni PC desktop o configurazioni).') }
    else { Add-LogLine("Report batteria salvato in $batteryPath") }

    Add-LogLine('============================================================')
    Add-LogLine("MANUTENZIONE COMPLETATA — Errori: $errors — Avvisi: $warnings")
    Add-LogLine("Fine: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')")
    [pscustomobject]@{ Errors=$errors; Warnings=$warnings; Log=$ctx.LogPath; Battery=$batteryPath }
}

$script:RunspaceInstance = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
$script:RunspaceInstance.ApartmentState = 'MTA'
$script:RunspaceInstance.ThreadOptions = 'ReuseThread'
$script:RunspaceInstance.Open()
$script:PowerShellInstance = [System.Management.Automation.PowerShell]::Create()
$script:PowerShellInstance.Runspace = $script:RunspaceInstance
[void]$script:PowerShellInstance.AddScript($workerScript.ToString())
[void]$script:PowerShellInstance.AddArgument($script:UiQueue)
$context = [pscustomobject]@{ LogPath=$logPath; TaskDir=$taskDir; Root=$root; BackupDir=$backupDir; Stamp=$stamp; CurrentStage='' }
[void]$script:PowerShellInstance.AddArgument($context)

$uiTimer = New-Object System.Windows.Forms.Timer
$uiTimer.Interval = 200
$uiTimer.Add_Tick({
    $item = $null
    while ($script:UiQueue.TryDequeue([ref]$item)) {
        if ($item.Kind -eq 'Log') {
            $logBox.AppendText($item.Text + [Environment]::NewLine)
            $logBox.SelectionStart = $logBox.TextLength
            $logBox.ScrollToCaret()
        } else {
            $overallBar.Value = [Math]::Max(0,[Math]::Min(100,[int]$item.Overall))
            $overallLabel.Text = "Avanzamento complessivo: $($item.Overall)%"
            if ($item.Stage) { $phaseLabel.Text = "Fase $($item.Stage) di $($item.Total) — $($item.Name)" }
            $stepBar.Value = [Math]::Max(0,[Math]::Min(100,[int]$item.StepPercent))
            if ($item.Mode -eq 'Continuous') { $stepBar.Style = 'Continuous' } else { $stepBar.Style = 'Marquee' }
            $stepStatus.Text = $item.Status
        }
    }
    if ($script:AsyncResult -and $script:AsyncResult.IsCompleted) {
        $uiTimer.Stop()
        try {
            $results = $script:PowerShellInstance.EndInvoke($script:AsyncResult)
            $workerErrors = $script:PowerShellInstance.Streams.Error
            if ($workerErrors.Count -gt 0) {
                foreach ($err in $workerErrors) { Add-Content -LiteralPath $logPath -Value ('ERRORE POWERSHELL: ' + $err.ToString()) -Encoding UTF8 }
            }
            $result = $results | Select-Object -Last 1
            if (-not $result) { throw 'Il processo di manutenzione non ha restituito il riepilogo finale.' }
            $stepStatus.Text = "Completato — Errori: $($result.Errors) · Avvisi: $($result.Warnings)"
            $summary = "Manutenzione completata.`r`n`r`nErrori: $($result.Errors)`r`nAvvisi: $($result.Warnings)`r`n`r`nRegistro: $($result.Log)`r`n`r`nIl PC non verrà riavviato automaticamente."
            [System.Windows.Forms.MessageBox]::Show($summary,'Manutenzione PC','OK','Information') | Out-Null
        } catch {
            $stepStatus.Text = 'Si è verificato un errore imprevisto. Consulta il registro.'
            Add-Content -LiteralPath $logPath -Value ('ERRORE FINALE: ' + $_.Exception.Message) -Encoding UTF8
            [System.Windows.Forms.MessageBox]::Show(('Errore imprevisto: ' + $_.Exception.Message + "`r`nRegistro: $logPath"),'Manutenzione PC','OK','Error') | Out-Null
        } finally {
            $script:PowerShellInstance.Dispose()
            $script:RunspaceInstance.Dispose()
            # Gli script helper sono temporanei: resta da distribuire soltanto questo BAT.
            Remove-Item -LiteralPath $taskDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        $overallBar.Value = 100
        $overallLabel.Text = 'Avanzamento complessivo: 100%'
        $stepBar.Style = 'Continuous'
        $stepBar.Value = 100
        $phaseLabel.Text = 'Manutenzione terminata'
        $openLogButton.Enabled = $true
        $closeButton.Enabled = $true
        $progressHint.Text = 'Operazione completata. Consulta il registro per i dettagli e gli eventuali interventi manuali.'
    }
})

$form.Add_Shown({
    $logBox.AppendText("Avvio manutenzione...`r`n")
    $script:AsyncResult = $script:PowerShellInstance.BeginInvoke()
    $uiTimer.Start()
})
$form.Add_FormClosing({
    if ($script:AsyncResult -and -not $script:AsyncResult.IsCompleted) {
        $result = [System.Windows.Forms.MessageBox]::Show('La manutenzione è ancora in esecuzione. Vuoi davvero chiudere la finestra? Il processo in corso potrebbe essere interrotto.','Manutenzione PC','YesNo','Warning')
        if ($result -ne [System.Windows.Forms.DialogResult]::Yes) { $_.Cancel = $true }
    }
})

[void]$form.ShowDialog()
