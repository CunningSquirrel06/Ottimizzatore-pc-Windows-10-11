MANUTENZIONE AUTOMATICA PC v3.0
================================

UTILIZZO
1. Scarica Manutenzione_PC_Automatica_v3.bat.
2. Fai doppio clic sul file.
3. Conferma la richiesta UAC per i privilegi amministrativi.
4. Il programma esegue tutte le attivita' in sequenza senza menu o selezioni.
5. Al termine apre il registro dettagliato.

COSA ESEGUE
- Raccoglie informazioni di Windows.
- Tenta di creare un punto di ripristino (se Protezione sistema e' disponibile).
- Controlla la presenza e la firma digitale Microsoft di TrustedInstaller.exe.
- Verifica ImagePath di TrustedInstaller. Se non e' standard, crea prima un backup .reg e poi ripristina il percorso al file Windows firmato. Non esegue lo script PowerShell che era configurato in precedenza.
- Tenta l'avvio di TrustedInstaller.
- Se TrustedInstaller non e' disponibile, salta DISM/SFC per evitare di lanciare riparazioni sapendo che il servizio essenziale non parte.
- Esegue DISM RestoreHealth e SFC Scannow quando il servizio e' disponibile.
- Esegue CHKDSK /scan sull'unita' di sistema.
- Registra lo stato dei dischi, se esposto da Windows.
- Elimina soltanto file temporanei piu' vecchi di 7 giorni; gli elementi in uso vengono ignorati.
- Aggiorna le applicazioni gestite da WinGet in modalita' silenziosa. Alcuni installer possono non supportare la modalita' silenziosa o richiedere interventi successivi.
- Aggiorna le firme e avvia una scansione rapida di Microsoft Defender, se disponibile.
- Svuota la cache DNS.
- Esegue l'ottimizzazione corretta per il tipo di supporto sui volumi locali.
- Genera un report batteria, quando supportato.

DOVE TROVARE I RISULTATI
C:\ProgramData\ManutenzionePC\Logs
C:\ProgramData\ManutenzionePC\Backups
C:\ProgramData\ManutenzionePC\BatteryReport_*.html

NOTE DI SICUREZZA
- Non elimina Windows Logs, CBS.log, DISM.log o Prefetch.
- Non svuota SoftwareDistribution o Catroot2.
- Non disattiva servizi di Windows.
- Non forza aggiornamenti di Windows né installa automaticamente aggiornamenti del sistema operativo: questi restano gestiti da Windows Update.
- Non riavvia il computer automaticamente.
- Se il file TrustedInstaller.exe non e' presente o la firma Microsoft non risulta valida, non modifica il servizio.
- Il programma crea il backup del ramo di registro TrustedInstaller prima di correggere un ImagePath non standard.

LIMITI
Questa e' una procedura di manutenzione best-effort. WinGet, Defender, i report batteria e alcune informazioni SMART possono non essere disponibili su tutti i PC. Leggere il file di log per distinguere operazioni riuscite, avvisi e problemi da correggere.
