Clear-Host
$dnsCryptDir = "$env:windir\DNSCrypt"
$system32Dir = "$env:windir\System32"
Write-Host ""
Write-Host "  DDDD   N   N   SSS   CCC  RRRR   Y   Y  PPPP  TTTTT"
Write-Host "  D   D  NN  N  S     C     R   R   Y Y   P   P   T"
Write-Host "  D   D  N N N   SSS  C     RRRR     Y    PPPP    T"
Write-Host "  D   D  N  NN      S C     R R      Y    P       T"
Write-Host "  DDDD   N   N  SSSS   CCC  R  R     Y    P       T"
Write-Host "    sevcator.github.io - github.com/bol-van"
Write-Host ""
function Check-Admin {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}
if (-not (Check-Admin)) {
    Write-Host "! Run PowerShell with administrator rights!"
    return
}
$initialDirectory = Get-Location
$osVersion = [Environment]::OSVersion.Version
Write-Host "- Windows version: $osVersion"
$windows10Version = New-Object System.Version(10, 0)
function Check-ProcessorArchitecture {
    $processor = Get-WmiObject -Class Win32_Processor
    return $processor.AddressWidth -eq 64
}
if (-not [Environment]::Is64BitOperatingSystem) {
    Write-Host "* Your system is not 64-bit"
    return
}
Write-Host "- Your system is 64-bit"
Write-Host "- Destroying services"
@("DNSCrypt", "dnscrypt-proxy") | ForEach-Object {
    Get-Process -Name $_ -ErrorAction SilentlyContinue | Stop-Process -Force

    $serviceName = $_
    try {
        if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
            Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
            
            $null = cmd /c "sc.exe stop $serviceName 2>&1"
            Start-Sleep -Seconds 3
            
            $null = cmd /c "sc.exe delete $serviceName 2>&1"
            Start-Sleep -Seconds 1
            
            if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
                $null = cmd /c "sc.exe delete $serviceName 2>&1"
            }
        }
    } catch {
    }
}
Write-Host "- Flushing DNS cache"
ipconfig /flushdns -ErrorAction SilentlyContinue | Out-Null
Write-Host "- Downloading files"
$baseFiles = @(
    "dnscrypt-proxy.exe", 
    "dnscrypt-proxy.toml", 
    "localhost.pem", 
    "dnscrypt-redirect.cmd"
)
$baseUrl = "https://github.com/sevcator/dnscrypt-ps1/raw/refs/heads/main/files/"
function Download-Files($files, $baseUrl, $destination) {
    foreach ($file in $files) {
        try {
            $url = "$baseUrl/$file"
            $outFile = Join-Path $destination $file
            Invoke-WebRequest -Uri $url -OutFile $outFile -ErrorAction Stop
            Write-Host "Downloaded $file"
        } catch {
            Write-Host "* Error downloading $file: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
if (!(Test-Path $dnsCryptDir)) {
    New-Item -ItemType Directory -Force -Path $dnsCryptDir | Out-Null
}
Download-Files $baseFiles $baseUrl $dnsCryptDir
Copy-Item "$dnsCryptDir\dnscrypt-redirect.cmd" "$system32Dir\zapret.cmd" -Force
Write-Host "- Creating service"
try {
    & "$dnsCryptDir\dnscrypt-proxy.exe" -service install
    & "$dnsCryptDir\dnscrypt-proxy.exe" -service start
} catch {
    Write-Host ("! Failed to create or start service: {0}" -f $_.Exception.Message) -ForegroundColor Red
}
Write-Host "- Checking network adapters and setting DNS if Cloudflare is reachable"
function Check-NetworkAdapters {
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }

    foreach ($adapter in $adapters) {
        Write-Host "  Checking adapter:" $adapter.Name
        $ping = Test-Connection -ComputerName "cloudflare.com" -Count 1 -Source $adapter.Name -ErrorAction SilentlyContinue
        
        if ($ping) {
            Write-Host "    Cloudflare is reachable. Setting DNS to 127.0.0.1 and 1.0.0.1."
            Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses 127.0.0.1,1.0.0.1
        } else {
            Write-Host "    Cloudflare is NOT reachable on this adapter."
        }
    }
}
Check-NetworkAdapters
Write-Host "- Done!"
