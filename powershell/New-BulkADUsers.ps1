<#
.SYNOPSIS
    Creates Active Directory users in bulk from a CSV file.

.DESCRIPTION
    Expected CSV columns: FirstName,LastName,Department,Title
    The SamAccountName is built as first initial + last name (e.g. jdoe).
    A random initial password is generated for each user, who must change it at first logon.
    Generated credentials are written to a CSV file that you should store securely, then delete.

.EXAMPLE
    .\New-BulkADUsers.ps1 -CsvPath .\users-example.csv -OU "OU=Staff,DC=lab,DC=local" -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)] [string]$CsvPath,
    [Parameter(Mandatory)] [string]$OU,
    [string]$OutputPath = ".\created-users.csv"
)

Import-Module ActiveDirectory -ErrorAction Stop

function New-RandomPassword {
    param([int]$Length = 14)
    $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%&*?'
    $bytes = New-Object byte[] $Length
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    # Guarantee complexity: one upper, one lower, one digit, one symbol
    $pass = -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
    return $pass + 'Aa1!'
}

$domain  = (Get-ADDomain).DNSRoot
$results = @()

foreach ($row in Import-Csv -Path $CsvPath) {
    $first = $row.FirstName.Trim()
    $last  = $row.LastName.Trim()
    $sam   = ($first.Substring(0,1) + $last).ToLower() -replace '[^a-z0-9]', ''

    if (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue) {
        Write-Warning "User '$sam' already exists, skipping."
        continue
    }

    $password = New-RandomPassword
    $params = @{
        Name                  = "$first $last"
        GivenName             = $first
        Surname               = $last
        SamAccountName        = $sam
        UserPrincipalName     = "$sam@$domain"
        Department            = $row.Department
        Title                 = $row.Title
        Path                  = $OU
        AccountPassword       = (ConvertTo-SecureString $password -AsPlainText -Force)
        ChangePasswordAtLogon = $true
        Enabled               = $true
    }

    if ($PSCmdlet.ShouldProcess($sam, "Create AD user in $OU")) {
        try {
            New-ADUser @params -ErrorAction Stop
            Write-Host "[+] Created $sam" -ForegroundColor Green
            $results += [pscustomobject]@{ SamAccountName = $sam; InitialPassword = $password }
        } catch {
            Write-Warning "Failed to create ${sam}: $($_.Exception.Message)"
        }
    }
}

if ($results.Count -gt 0) {
    $results | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    Write-Host "`n$($results.Count) user(s) created. Credentials saved to $OutputPath (store securely, then delete)." -ForegroundColor Yellow
}
