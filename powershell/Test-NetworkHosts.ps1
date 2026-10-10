<#
.SYNOPSIS
    Checks reachability (ICMP) and TCP ports for a list of hosts.

.EXAMPLE
    .\Test-NetworkHosts.ps1 -Hosts 192.168.1.1,192.168.1.10 -Ports 22,80,443
.EXAMPLE
    .\Test-NetworkHosts.ps1 -HostFile .\hosts.txt -Ports 3389 -ExportCsv .\report.csv
#>
param(
    [string[]]$Hosts,
    [string]$HostFile,
    [int[]]$Ports = @(22, 80, 443, 3389),
    [int]$TimeoutMs = 1000,
    [string]$ExportCsv
)

if ($HostFile) { $Hosts += Get-Content $HostFile | Where-Object { $_ -and $_ -notmatch '^\s*#' } }
if (-not $Hosts) { throw "Provide -Hosts or -HostFile." }

function Test-TcpPort {
    param([string]$Target, [int]$Port, [int]$Timeout)
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $task = $client.ConnectAsync($Target, $Port)
        return ($task.Wait($Timeout) -and $client.Connected)
    } catch { return $false }
    finally { $client.Dispose() }
}

$report = foreach ($h in $Hosts) {
    $ping = Test-Connection -ComputerName $h -Count 1 -Quiet -ErrorAction SilentlyContinue
    $row  = [ordered]@{ Host = $h; Ping = if ($ping) { 'UP' } else { 'DOWN' } }
    foreach ($p in $Ports) {
        $row["TCP$p"] = if (Test-TcpPort -Target $h -Port $p -Timeout $TimeoutMs) { 'open' } else { '-' }
    }
    [pscustomobject]$row
}

$report | Format-Table -AutoSize
if ($ExportCsv) {
    $report | Export-Csv -Path $ExportCsv -NoTypeInformation -Encoding UTF8
    Write-Host "Report exported to $ExportCsv"
}
