# i hate some things
Clear-Host
$dnsCryptDir = "$env:windir\DNSCrypt"
$system32Dir = "$env:windir\System32"
Write-Host ""
Write-Host "  DDDD   N   N   SSS   CCC  RRRR   Y   Y  PPPP  TTTTT"
Write-Host "  D   D  NN  N  S     C     R   R   Y Y   P   P   T"
Write-Host "  D   D  N N N   SSS  C     RRRR     Y    PPPP    T"
Write-Host "  D   D  N  NN      S C     R R      Y    P       T"
Write-Host "  DDDD   N   N  SSSS   CCC  R  R     Y    P       T"
Write-Host "       sevcator.github.io - github.com/bol-van"
Write-Host ""
function Check-Admin {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}
if (-not (Check-Admin)) {
    Write-Host "! Run PowerShell with administrator rights!" -ForegroundColor Red
    return
}
$osVersion = [Environment]::OSVersion.Version
Write-Host "- Windows version: $osVersion"
$windows10Version = New-Object System.Version(10, 0)
if ($osVersion -lt $windows10Version) {
    Write-Host "* Your system is not compatible with Windows 10 or later." -ForegroundColor Red
    return
}
if (-not [Environment]::Is64BitOperatingSystem) {
    Write-Host "* Your system is not 64-bit" -ForegroundColor Red
    return
}
Write-Host "- Your system is 64-bit"
Write-Host "- Destroying services"
@("DNSCrypt", "dnscrypt-proxy") | ForEach-Object {
    try {
        Get-Process -Name $_ -ErrorAction SilentlyContinue | Stop-Process -Force
        $serviceName = $_
        if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
            Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue | Out-Null
            Start-Sleep -Seconds 1
            sc.exe stop $serviceName | Out-Null
            Start-Sleep -Seconds 3
            sc.exe delete $serviceName | Out-Null
        }
    } catch {
        Write-Host "! Failed to stop or delete service: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
Write-Host "- Flushing DNS cache"
try {
    ipconfig /flushdns | Out-Null
} catch {
    Write-Host "! Failed to flush DNS cache: $($_.Exception.Message)" -ForegroundColor Yellow
}
Write-Host "- Downloading files"
$baseFiles = @(
    "dnscrypt-proxy.exe",
    "dnscrypt-proxy.toml",
    "localhost.pem",
    "dnscrypt-redirect.cmd",
    "dnscrypt.cmd",
    "uninstall.ps1"
)
$baseUrl = "https://github.com/sevcator/dnscrypt-ps1/raw/refs/heads/main/files/"
function Download-Files($files, $baseUrl, $destination) {
    foreach ($file in $files) {
        try {
            $url = "$baseUrl/$file"
            $outFile = Join-Path $destination $file
            Invoke-WebRequest -Uri $url -OutFile $outFile -ErrorAction Stop
        } catch {
            Write-Host "! Error downloading ${file}: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
New-Item -ItemType Directory -Force -Path $dnsCryptDir | Out-Null
Download-Files $baseFiles $baseUrl $dnsCryptDir
try {
    Copy-Item "$dnsCryptDir\dnscrypt-redirect.cmd" "$system32Dir\dnscrypt.cmd" -Force
} catch {
    Write-Host "! Failed to copy file to system32: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host "- Creating service"
try {
    & "$dnsCryptDir\dnscrypt-proxy.exe" -service install *> $null
    & "$dnsCryptDir\dnscrypt-proxy.exe" -service start *> $null

    $service = Get-Service -Name "dnscrypt-proxy" -ErrorAction SilentlyContinue
    if ($service.Status -ne "Running") {
        Write-Host "! Failed to start DNSCrypt service" -ForegroundColor Red
    }
} catch {
    Write-Host "! Failed to create or start service: $($_.Exception.Message)" -ForegroundColor Red
}
function Check-NetworkAdapters {
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
    
    foreach ($adapter in $adapters) {
        try {
            $ipv4 = Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | 
                    Select-Object -ExpandProperty IPAddress -First 1
            
            if (-not $ipv4) {
                continue
            }
            
            $pingResult = ping -n 1 -S $ipv4 cloudflare.com
            if ($pingResult -match "Reply from") {
                Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses @(
                    "127.0.0.1",    # IPv4 local DNS
                    "1.0.0.1",      # IPv4 public DNS (Cloudflare)
                    "::1",          # IPv6 local DNS
                    "2606:4700:4700::6400" # IPv6 public DNS (Cloudflare)
                ) -Confirm:$false
            }
        } catch {
            Write-Host "! Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
Write-Host "- Setting DNS servers"
Check-NetworkAdapters
Write-Host "- Done!"
