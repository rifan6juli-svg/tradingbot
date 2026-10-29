<#
.SYNOPSIS
    Setup VPS Windows baru untuk TradingBot AI (F-10, TRD bagian 6a).

.DESCRIPTION
    Memasang Python 3.14, Git for Windows, dan MetaTrader 5; clone/update repo; membuat
    virtualenv dan memasang dependensi; membuat .env; mengatur Windows untuk uptime;
    mendaftarkan Task Scheduler; lalu menjalankan cek akhir.
    Aman dijalankan ulang: komponen yang sudah ada dilewati, dan menjalankan ulang skrip
    sekaligus menjadi cara update bot.

    Jalankan di PowerShell sebagai Administrator, dengan akun Windows yang nanti dipakai
    login lewat RDP (task dijalankan atas nama akun ini).

.EXAMPLE
    # Repo publik:
    Set-ExecutionPolicy -Scope Process Bypass -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest https://raw.githubusercontent.com/rifan6juli-svg/tradingbot/main/scripts/setup_vps.ps1 -OutFile "$env:TEMP\setup_vps.ps1" -UseBasicParsing
    & "$env:TEMP\setup_vps.ps1"

.EXAMPLE
    # Repo privat (salin skrip ke VPS lewat RDP terlebih dahulu):
    & .\setup_vps.ps1 -PrivateRepo
#>
[CmdletBinding()]
param(
    [string]$InstallDir = 'C:\tradingbot',
    [string]$RepoUrl = 'https://github.com/rifan6juli-svg/tradingbot.git',
    [string]$Branch = 'main',
    # Kosong = patch 3.14 terbaru yang punya installer Windows di python.org.
    [string]$PythonVersion = '',
    [string]$Mt5InstallerUrl = 'https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe',
    [string]$Mt5SignerPattern = 'MetaQuotes',
    [switch]$PrivateRepo,
    [switch]$ReconfigureEnv,
    [switch]$NoDev,
    [switch]$SkipWindowsTweaks
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$PythonDir = 'C:\Python314'
$PythonExe = Join-Path $PythonDir 'python.exe'
$BotUser = "$env:USERDOMAIN\$env:USERNAME"
$EnvPath = Join-Path $InstallDir '.env'
$script:Results = New-Object System.Collections.ArrayList

function Write-Step([string]$Message) {
    Write-Host ''
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Add-Result([string]$Name, [string]$Status, [string]$Detail = '') {
    [void]$script:Results.Add([pscustomobject]@{ Cek = $Name; Status = $Status; Detail = $Detail })
}

function Test-Ok([bool]$Condition) {
    if ($Condition) { return 'LOLOS' }
    return 'GAGAL'
}

# Menjalankan installer dan hanya menunggu proses installer itu sendiri. Start-Process -Wait di
# PowerShell 5.1 ikut menunggu proses turunan (mis. terminal MT5 yang dibuka installer) sehingga bisa macet.
function Invoke-Installer([string]$Path, [string[]]$Arguments) {
    $process = Start-Process -FilePath $Path -ArgumentList $Arguments -PassThru
    # Membaca Handle sejak awal agar ExitCode tetap tersedia setelah proses selesai.
    $null = $process.Handle
    $process.WaitForExit()
    return $process.ExitCode
}

# Menjalankan program eksternal; output ke layar (bukan ke nilai kembalian), gagal -> throw.
function Invoke-Checked([string]$Exe, [string[]]$Arguments, [string]$ErrorMessage) {
    & $Exe @Arguments | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "$ErrorMessage (kode $LASTEXITCODE)" }
}

function Assert-Prerequisites {
    Write-Step 'Cek prasyarat'
    if ($env:OS -ne 'Windows_NT') { throw 'Skrip ini hanya untuk Windows.' }
    if (-not [Environment]::Is64BitOperatingSystem) { throw 'Windows harus 64-bit.' }
    if ($PSVersionTable.PSVersion.Major -lt 5) { throw 'Butuh PowerShell 5.1 atau lebih baru.' }
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Jalankan PowerShell sebagai Administrator.'
    }
    Write-Host "Windows 64-bit, PowerShell $($PSVersionTable.PSVersion), Administrator. User bot: $BotUser"
}

# Unduh installer lalu wajibkan tanda tangan digital valid dari penerbit yang diharapkan.
function Get-VerifiedInstaller([string]$Url, [string]$FileName, [string]$SignerPattern) {
    $dir = Join-Path $env:TEMP 'tradingbot-setup'
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    $path = Join-Path $dir $FileName
    Write-Host "Mengunduh $Url"
    Invoke-WebRequest -Uri $Url -OutFile $path -UseBasicParsing
    $signature = Get-AuthenticodeSignature -FilePath $path
    $subject = ''
    if ($null -ne $signature.SignerCertificate) { $subject = $signature.SignerCertificate.Subject }
    if ($signature.Status -ne 'Valid' -or $subject -notmatch $SignerPattern) {
        Remove-Item -Path $path -Force
        throw "Tanda tangan digital $FileName tidak valid atau penerbit tidak sesuai (status: $($signature.Status); penerbit: $subject). Instalasi dibatalkan."
    }
    Write-Host "Tanda tangan valid: $subject"
    return $path
}

function Resolve-PythonVersion {
    if ($PythonVersion) { return $PythonVersion }
    $index = Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/' -UseBasicParsing
    $versions = [regex]::Matches($index.Content, 'href="(3\.14\.\d+)/"') |
        ForEach-Object { [version]$_.Groups[1].Value } |
        Sort-Object -Descending
    foreach ($version in $versions) {
        $url = "https://www.python.org/ftp/python/$version/python-$version-amd64.exe"
        try {
            Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing | Out-Null
            return $version.ToString()
        } catch {
            continue
        }
    }
    throw 'Installer Python 3.14 untuk Windows tidak ditemukan di python.org. Isi -PythonVersion secara manual.'
}

function Install-Python {
    Write-Step 'Python 3.14'
    if (Test-Path $PythonExe) {
        $current = & $PythonExe -c "import sys; print('%d.%d.%d' % sys.version_info[:3])"
        Write-Host "Sudah terpasang: Python $current di $PythonDir"
        return
    }
    $version = Resolve-PythonVersion
    $installer = Get-VerifiedInstaller -Url "https://www.python.org/ftp/python/$version/python-$version-amd64.exe" `
        -FileName "python-$version-amd64.exe" -SignerPattern 'Python Software Foundation'
    $installArgs = @('/quiet', 'InstallAllUsers=1', "TargetDir=$PythonDir", 'PrependPath=0',
        'Include_test=0', 'Include_launcher=1', 'Shortcuts=0')
    $exitCode = Invoke-Installer $installer $installArgs
    if ($exitCode -ne 0) { throw "Installer Python gagal (kode $exitCode)." }
    if (-not (Test-Path $PythonExe)) { throw "Python tidak ditemukan di $PythonDir setelah instalasi." }
    Write-Host "Python $version terpasang di $PythonDir"
}

function Find-Git {
    $command = Get-Command git.exe -ErrorAction SilentlyContinue
    if ($command) { return $command.Path }
    $default = 'C:\Program Files\Git\cmd\git.exe'
    if (Test-Path $default) { return $default }
    return $null
}

function Install-Git {
    Write-Step 'Git for Windows'
    $git = Find-Git
    if ($git) {
        Write-Host "Sudah terpasang: $git"
        return $git
    }
    $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/git-for-windows/git/releases/latest' `
        -Headers @{ 'User-Agent' = 'tradingbot-setup' } -UseBasicParsing
    $asset = $release.assets | Where-Object { $_.name -match '^Git-[\d\.]+-64-bit\.exe$' } | Select-Object -First 1
    if (-not $asset) { throw 'Installer Git 64-bit tidak ditemukan di rilis terbaru git-for-windows.' }
    $installer = Get-VerifiedInstaller -Url $asset.browser_download_url -FileName $asset.name `
        -SignerPattern 'Johannes Schindelin'
    $exitCode = Invoke-Installer $installer @('/VERYSILENT', '/NORESTART', '/NOCANCEL', '/SP-', '/SUPPRESSMSGBOXES')
    if ($exitCode -ne 0) { throw "Installer Git gagal (kode $exitCode)." }
    $git = Find-Git
    if (-not $git) { throw 'Git terpasang tetapi git.exe tidak ditemukan.' }
    Write-Host "Git terpasang: $git"
    return $git
}

function Find-Mt5 {
    $default = 'C:\Program Files\MetaTrader 5\terminal64.exe'
    if (Test-Path $default) { return $default }
    # Installer broker biasanya memasang ke 'C:\Program Files\<Broker> MT5 Terminal\'.
    $found = Get-ChildItem -Path 'C:\Program Files\*\terminal64.exe' -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($found) { return $found.FullName }
    return $null
}

function Install-Mt5 {
    Write-Step 'MetaTrader 5'
    $mt5 = Find-Mt5
    if ($mt5) {
        Write-Host "Sudah terpasang: $mt5"
        return $mt5
    }
    $installer = Get-VerifiedInstaller -Url $Mt5InstallerUrl -FileName 'mt5setup.exe' -SignerPattern $Mt5SignerPattern
    # Kode keluar installer MT5 tidak dipakai; keberhasilan dicek dari munculnya terminal64.exe.
    Invoke-Installer $installer @('/auto') | Out-Null
    # Installer MT5 mengunduh file terminal; tunggu sampai terminal64.exe muncul (maks 5 menit).
    for ($i = 0; $i -lt 60; $i++) {
        $mt5 = Find-Mt5
        if ($mt5) { break }
        Start-Sleep -Seconds 5
    }
    if (-not $mt5) {
        throw 'MT5 tidak ditemukan setelah instalasi. Pasang MT5 dari broker secara manual, lalu jalankan skrip ini lagi.'
    }
    Write-Host "MT5 terpasang: $mt5"
    return $mt5
}

function Read-Secret([string]$Prompt) {
    $secure = Read-Host -Prompt $Prompt -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Sync-Repo([string]$Git) {
    Write-Step 'Repo'
    if ($PrivateRepo) {
        # Token disimpan di Windows Credential Manager lewat Git Credential Manager, bukan di file atau URL.
        $token = Read-Secret 'Token GitHub read-only untuk repo privat'
        $credential = "protocol=https`nhost=github.com`nusername=x-access-token`npassword=$token`n`n"
        $credential | & $Git credential approve
        if ($LASTEXITCODE -ne 0) { throw 'Gagal menyimpan token GitHub ke Credential Manager.' }
        $token = $null
        $credential = $null
    }
    if (Test-Path (Join-Path $InstallDir '.git')) {
        Invoke-Checked $Git @('-C', $InstallDir, 'fetch', 'origin', $Branch) 'git fetch gagal'
        Invoke-Checked $Git @('-C', $InstallDir, 'checkout', $Branch) 'git checkout gagal'
        Invoke-Checked $Git @('-C', $InstallDir, 'pull', '--ff-only', 'origin', $Branch) 'git pull gagal (ada perubahan lokal?)'
    } else {
        $message = 'git clone gagal. Untuk repo privat, jalankan ulang dengan -PrivateRepo'
        Invoke-Checked $Git @('clone', '--branch', $Branch, $RepoUrl, $InstallDir) $message
    }
}

function Install-Venv {
    Write-Step 'Virtualenv dan dependensi'
    $venvDir = Join-Path $InstallDir '.venv'
    $venvPython = Join-Path $venvDir 'Scripts\python.exe'
    if (Test-Path $venvPython) {
        $isPy314 = & $venvPython -c "import sys; print(sys.version_info[:2] == (3, 14))"
        if ($isPy314 -ne 'True') {
            Write-Host 'Virtualenv lama bukan Python 3.14; dibuat ulang.'
            Remove-Item -Path $venvDir -Recurse -Force
        }
    }
    if (-not (Test-Path $venvPython)) {
        Invoke-Checked $PythonExe @('-m', 'venv', $venvDir) 'Gagal membuat virtualenv'
    }
    Invoke-Checked $venvPython @('-m', 'pip', 'install', '--upgrade', 'pip') 'Gagal memperbarui pip'
    $target = '.[dev]'
    if ($NoDev) { $target = '.' }
    Push-Location $InstallDir
    try {
        Invoke-Checked $venvPython @('-m', 'pip', 'install', '-e', $target) 'Gagal memasang dependensi'
    } finally {
        Pop-Location
    }
    return $venvPython
}

function Read-EnvFile([string]$Path) {
    $values = @{}
    if (-not (Test-Path $Path)) { return $values }
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        if ($line -match '^\s*([A-Z0-9_]+)=(.*)$') { $values[$Matches[1]] = $Matches[2] }
    }
    return $values
}

function New-RandomToken {
    $bytes = New-Object byte[] 32
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    return (($bytes | ForEach-Object { $_.ToString('x2') }) -join '')
}

function Write-EnvFile([string]$Mt5Path) {
    Write-Step 'File .env'
    if ((Test-Path $EnvPath) -and -not $ReconfigureEnv) {
        Write-Host '.env sudah ada; dilewati (pakai -ReconfigureEnv untuk mengisi ulang).'
        return
    }
    $existing = Read-EnvFile $EnvPath
    Write-Host 'Isi nilai berikut. Input secret tidak ditampilkan. Kosongkan untuk melewati yang opsional.'
    $answers = @{}
    $answers['ANTHROPIC_API_KEY'] = Read-Secret 'ANTHROPIC_API_KEY'
    $answers['OPENAI_API_KEY'] = Read-Secret 'OPENAI_API_KEY'
    $anthropicModel = Read-Host 'ANTHROPIC_MODEL (Enter = claude-sonnet-5-5)'
    if ($anthropicModel) { $answers['ANTHROPIC_MODEL'] = $anthropicModel }
    $answers['OPENAI_MODEL'] = Read-Host 'OPENAI_MODEL (ID model OpenAI, wajib)'
    $answers['MT5_LOGIN'] = Read-Host 'MT5_LOGIN (nomor akun demo; kosong = login manual di terminal)'
    if ($answers['MT5_LOGIN']) {
        $answers['MT5_PASSWORD'] = Read-Secret 'MT5_PASSWORD'
        $answers['MT5_SERVER'] = Read-Host 'MT5_SERVER (nama server broker, mis. Broker-Demo)'
    }
    $answers['TELEGRAM_BOT_TOKEN'] = Read-Secret 'TELEGRAM_BOT_TOKEN (opsional)'
    $answers['TELEGRAM_CHAT_ID'] = Read-Host 'TELEGRAM_CHAT_ID (opsional)'
    $answers['MT5_PATH'] = $Mt5Path
    $answers['DASHBOARD_TOKEN'] = New-RandomToken
    if ($existing.ContainsKey('DASHBOARD_TOKEN') -and $existing['DASHBOARD_TOKEN']) {
        $answers['DASHBOARD_TOKEN'] = $existing['DASHBOARD_TOKEN']
    }
    # Mode live tidak pernah diaktifkan oleh skrip (TRD bagian 5).
    $answers['LIVE_ENABLED'] = 'false'

    $lines = New-Object System.Collections.ArrayList
    foreach ($line in [System.IO.File]::ReadAllLines((Join-Path $InstallDir '.env.example'))) {
        if ($line -match '^\s*([A-Z0-9_]+)=(.*)$') {
            $key = $Matches[1]
            $value = $Matches[2]
            if ($answers.ContainsKey($key) -and $answers[$key]) {
                $value = $answers[$key]
            } elseif ($existing.ContainsKey($key) -and $existing[$key]) {
                $value = $existing[$key]
            }
            if ($key -eq 'LIVE_ENABLED') { $value = 'false' }
            [void]$lines.Add("$key=$value")
        } else {
            [void]$lines.Add($line)
        }
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($EnvPath, [string[]]$lines.ToArray(), $utf8NoBom)
    $answers.Clear()
    # Hanya user bot, SYSTEM, dan Administrators yang boleh membaca .env.
    Invoke-Checked 'icacls.exe' @($EnvPath, '/inheritance:r', '/grant:r', "${BotUser}:(R,W)",
        '*S-1-5-18:(F)', '*S-1-5-32-544:(F)') 'Gagal membatasi akses .env'
    Write-Host '.env dibuat dan aksesnya dibatasi.'
}

function Initialize-Folders([string]$VenvPython) {
    Write-Step 'Folder data dan log'
    foreach ($name in @('data', 'logs')) {
        $path = Join-Path $InstallDir $name
        if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path | Out-Null }
    }
    # Bot berjalan tanpa hak admin, jadi user bot perlu izin tulis di folder instalasi.
    Invoke-Checked 'icacls.exe' @($InstallDir, '/grant', "${BotUser}:(OI)(CI)M") 'Gagal memberi izin folder instalasi'
    if (Test-Path (Join-Path $InstallDir 'alembic.ini')) {
        Push-Location $InstallDir
        try {
            Invoke-Checked $VenvPython @('-m', 'alembic', 'upgrade', 'head') 'Migrasi database gagal'
        } finally {
            Pop-Location
        }
    } else {
        Write-Host 'Belum ada migrasi database (dibuat di langkah 2); dilewati.'
    }
}

function Set-RegistryDword([string]$Path, [string]$Name, [int]$Value) {
    # Jangan pakai New-Item -Force pada key yang sudah ada: itu menghapus isi key.
    if (-not (Test-Path $Path)) { New-Item -Path $Path | Out-Null }
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWord -Force | Out-Null
}

function Set-WindowsForUptime {
    Write-Step 'Pengaturan Windows untuk uptime'
    if ($SkipWindowsTweaks) {
        Write-Host 'Dilewati (-SkipWindowsTweaks).'
        return
    }
    & powercfg.exe /change standby-timeout-ac 0 | Out-Host
    & powercfg.exe /change hibernate-timeout-ac 0 | Out-Host
    & powercfg.exe /hibernate off | Out-Host
    Set-RegistryDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' 'NoAutoRebootWithLoggedOnUsers' 1
    # Jam aktif 05:00-23:00 UTC (mencakup sesi trading 07:00-20:00 UTC), dikonversi ke jam lokal VPS.
    $offset = [TimeZoneInfo]::Local.GetUtcOffset([DateTime]::UtcNow).TotalHours
    $start = [int][Math]::Floor(((5 + $offset) % 24 + 24) % 24)
    $end = [int][Math]::Floor(((23 + $offset) % 24 + 24) % 24)
    Set-RegistryDword 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' 'ActiveHoursStart' $start
    Set-RegistryDword 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' 'ActiveHoursEnd' $end
    Write-Host "Sleep/hibernate dimatikan; restart otomatis saat user login dicegah; jam aktif lokal $start-$end."
}

function Register-BotTasks([string]$Mt5Path) {
    Write-Step 'Task Scheduler'
    $principal = New-ScheduledTaskPrincipal -UserId $BotUser -LogonType Interactive -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
    $mt5Trigger = New-ScheduledTaskTrigger -AtLogOn -User $BotUser
    $mt5Action = New-ScheduledTaskAction -Execute $Mt5Path
    Register-ScheduledTask -TaskName 'TradingBot-MT5' -Action $mt5Action -Trigger $mt5Trigger `
        -Principal $principal -Settings $settings -Force | Out-Null
    $botTrigger = New-ScheduledTaskTrigger -AtLogOn -User $BotUser
    $botTrigger.Delay = 'PT60S'
    $botAction = New-ScheduledTaskAction -Execute (Join-Path $InstallDir 'start.bat') -WorkingDirectory $InstallDir
    Register-ScheduledTask -TaskName 'TradingBot-Bot' -Action $botAction -Trigger $botTrigger `
        -Principal $principal -Settings $settings -Force | Out-Null
    Write-Host "Task TradingBot-MT5 dan TradingBot-Bot terdaftar untuk $BotUser (saat login)."
}

function Invoke-FinalChecks([string]$VenvPython, [string]$Mt5Path) {
    Write-Step 'Cek akhir'
    $version = & $VenvPython -c "import sys; print('%d.%d.%d' % sys.version_info[:3])"
    Add-Result 'Python 3.14 di virtualenv' (Test-Ok ("$version" -like '3.14.*')) "$version"

    & $VenvPython -m pip check | Out-Host
    Add-Result 'pip check' (Test-Ok ($LASTEXITCODE -eq 0))

    $botVersion = & $VenvPython -m tradingbot --version
    Add-Result 'python -m tradingbot --version' (Test-Ok ($LASTEXITCODE -eq 0)) "$botVersion"

    if (-not $NoDev) {
        Push-Location $InstallDir
        try {
            & $VenvPython -m pytest -q | Out-Host
            Add-Result 'pytest' (Test-Ok ($LASTEXITCODE -eq 0))
        } finally {
            Pop-Location
        }
    }

    Add-Result 'MetaTrader 5 terpasang' (Test-Ok (Test-Path $Mt5Path)) $Mt5Path

    $values = Read-EnvFile $EnvPath
    $required = @('ANTHROPIC_API_KEY', 'OPENAI_API_KEY', 'OPENAI_MODEL', 'DASHBOARD_TOKEN', 'MT5_PATH')
    $missing = @($required | Where-Object { -not $values[$_] })
    Add-Result '.env: nilai wajib terisi' (Test-Ok ($missing.Count -eq 0)) ($missing -join ', ')
    $liveValue = "$($values['LIVE_ENABLED'])"
    Add-Result '.env: LIVE_ENABLED=false' (Test-Ok ($liveValue -eq 'false')) $liveValue

    $mt5Missing = @(@('MT5_LOGIN', 'MT5_PASSWORD', 'MT5_SERVER') | Where-Object { -not $values[$_] })
    if ($mt5Missing.Count -eq 0) {
        Add-Result '.env: login MT5 otomatis' 'LOLOS'
    } else {
        Add-Result '.env: login MT5 otomatis' 'PERINGATAN' 'kosong: login manual di terminal MT5'
    }
    if ($values['TELEGRAM_BOT_TOKEN'] -and $values['TELEGRAM_CHAT_ID']) {
        Add-Result '.env: Telegram' 'LOLOS'
    } else {
        Add-Result '.env: Telegram' 'PERINGATAN' 'kosong: notifikasi nonaktif'
    }

    $tasks = @(Get-ScheduledTask -TaskName 'TradingBot-MT5', 'TradingBot-Bot' -ErrorAction SilentlyContinue)
    Add-Result 'Task Scheduler terdaftar' (Test-Ok ($tasks.Count -eq 2)) "$($tasks.Count) dari 2"
}

function Write-Summary {
    Write-Step 'Ringkasan'
    $script:Results | Format-Table -AutoSize | Out-Host
    Write-Host 'Langkah manual yang tersisa:' -ForegroundColor Yellow
    Write-Host '  1. Buka MetaTrader 5: pastikan akun demo login (jika tidak memakai login otomatis) dan tombol Algo Trading berwarna hijau.'
    Write-Host '  2. Saat keluar dari RDP, pilih Disconnect (bukan Sign out) agar MT5 dan bot tetap berjalan.'
    Write-Host '  3. Opsional: aktifkan auto-logon dengan Sysinternals Autologon agar bot jalan lagi setelah VPS restart.'
    Write-Host '  4. Untuk update bot, jalankan ulang skrip ini.'
}

$logDir = Join-Path $env:ProgramData 'TradingBot'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$logPath = Join-Path $logDir ('setup-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
Start-Transcript -Path $logPath | Out-Null
$failed = $false
try {
    Assert-Prerequisites
    Install-Python
    $gitExe = Install-Git
    $mt5Path = Install-Mt5
    Sync-Repo $gitExe
    $venvPython = Install-Venv
    Write-EnvFile $mt5Path
    Initialize-Folders $venvPython
    Set-WindowsForUptime
    Register-BotTasks $mt5Path
    Invoke-FinalChecks $venvPython $mt5Path
    Write-Summary
} catch {
    $failed = $true
    Write-Host ''
    Write-Host "SETUP GAGAL: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Perbaiki penyebabnya lalu jalankan ulang skrip ini (aman dijalankan ulang).'
} finally {
    Stop-Transcript | Out-Null
    Write-Host "Log setup: $logPath"
}

if ($failed -or @($script:Results | Where-Object { $_.Status -eq 'GAGAL' }).Count -gt 0) { exit 1 }
exit 0
