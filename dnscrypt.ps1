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
    Write-Host "! Run PowerShell as administrator rights!"
    return
}
$initialDirectory = Get-Location
$osVersion = [Environment]::OSVersion.Version
Write-Host "- Windows version: $osVersion"
$windows10Version = New-Object System.Version(10, 0)
if ($osVersion.Major -lt 10) {
    Write-Host "* Enabling Test Mode for Windows less than 10" -ForegroundColor Yellow
    $testMode = bcdedit /enum | Select-String "testsigning" -Quiet
    
    if (-not $testMode) {
        bcdedit /set loadoptions DISABLE_INTEGRITY_CHECKS | Out-Null
        bcdedit /set TESTSIGNING ON | Out-Null
        Write-Host "* Reboot the system and run this script to countinue the installation" -ForegroundColor Yellow
        exit 1
    }
}
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
    "dnscrypt-proxy.exe", "dnscrypt-proxy.toml", "localhost.pem", "dnscrypt-redirect.cmd"
)
$baseUrl = "https://github.com/sevcator/dnscrypt-ps1/raw/refs/heads/main/files/"
function Download-Files($files, $baseUrl, $destination) {
    foreach ($file in $files) {
        try {
            $url = "$baseUrl/$file"
            $outFile = Join-Path $destination $file
            Invoke-WebRequest -Uri $url -OutFile $outFile -ErrorAction Stop
        } catch {
            Write-Host "* Error to download $file : $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
Download-Files $tacticsFiles $tacticsUrl $dnsCryptDir
Copy-Item "$dnsCryptDir\dnscrypt-redirect.cmd" "$system32Dir\zapret.cmd" -Force
foreach ($file in $files) {
    try {
        Invoke-WebRequest -Uri $file.Url -OutFile "$dnsCryptDir\$($file.Name)" -ErrorAction Stop | Out-Null
    } catch {
        Write-Host ("{0}: {1}" -f $($file.Name), $_.Exception.Message) -ForegroundColor Red
    }
}
Write-Host "- Creating service"
try {
    "$dnsCryptDir\dnscrypt-proxy.exe" -service install
    "$dnsCryptDir\dnscrypt-proxy.exe" -service start
} catch {
    Write-Host ("! Failed to create or start service: {0}" -f $_.Exception.Message) -ForegroundColor Red
}
Write-Host "- Done!"
