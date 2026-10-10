<#
.SYNOPSIS
    Lists enabled AD user accounts that have not logged on for a given number of days.

.EXAMPLE
    .\Get-InactiveADUsers.ps1 -Days 90 -ExportCsv .\inactive.csv
#>
param(
    [int]$Days = 90,
    [string]$SearchBase,
    [string]$ExportCsv
)

Import-Module ActiveDirectory -ErrorAction Stop

$cutoff = (Get-Date).AddDays(-$Days)
$params = @{
    Filter     = "Enabled -eq 'True'"
    Properties = 'LastLogonDate', 'whenCreated', 'Department'
}
if ($SearchBase) { $params.SearchBase = $SearchBase }

$inactive = Get-ADUser @params |
    Where-Object { -not $_.LastLogonDate -or $_.LastLogonDate -lt $cutoff } |
    Select-Object SamAccountName, Name, Department, LastLogonDate, whenCreated |
    Sort-Object LastLogonDate

Write-Host "$($inactive.Count) enabled account(s) inactive for more than $Days days." -ForegroundColor Yellow
$inactive | Format-Table -AutoSize

if ($ExportCsv) {
    $inactive | Export-Csv -Path $ExportCsv -NoTypeInformation -Encoding UTF8
    Write-Host "Report exported to $ExportCsv"
}
