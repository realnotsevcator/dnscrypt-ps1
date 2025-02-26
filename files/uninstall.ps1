$dnsToCheck = @(
    "127.0.0.1",    # IPv4 local DNS
    "1.0.0.1",      # IPv4 public DNS (Cloudflare)
)
Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | ForEach-Object {
    $adapter = $_

    $ipv4Dns = Get-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4
    if ($ipv4Dns.ServerAddresses -and ($ipv4Dns.ServerAddresses | Where-Object { $dnsToCheck -contains $_ })) {
        Write-Host "Forbidden DNS found in IPv4 on adapter $($adapter.Name). Resetting..."
        Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ResetServerAddresses -Confirm:$false
    }
}

Write-Host "DNS settings updated."