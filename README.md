# sysadmin-scripts

Practical PowerShell and Bash scripts for everyday system administration and basic security auditing.

## Contents

| Script | Platform | What it does |
|---|---|---|
| [`powershell/New-BulkADUsers.ps1`](powershell/New-BulkADUsers.ps1) | Windows Server (AD) | Creates Active Directory users in bulk from a CSV file |
| [`powershell/Get-InactiveADUsers.ps1`](powershell/Get-InactiveADUsers.ps1) | Windows Server (AD) | Lists accounts that haven't logged on for N days |
| [`powershell/Test-NetworkHosts.ps1`](powershell/Test-NetworkHosts.ps1) | Windows | Pings a list of hosts and checks TCP ports, exports a report |
| [`bash/linux-security-audit.sh`](bash/linux-security-audit.sh) | Linux | Quick security audit: users, sudoers, SSH config, open ports, updates |
| [`bash/backup.sh`](bash/backup.sh) | Linux | Compressed, dated backups with automatic rotation |

## Usage

### PowerShell

```powershell
# AD scripts need the ActiveDirectory module (RSAT) and suitable rights
.\powershell\New-BulkADUsers.ps1 -CsvPath .\powershell\users-example.csv -OU "OU=Staff,DC=lab,DC=local" -WhatIf
.\powershell\Get-InactiveADUsers.ps1 -Days 90 -ExportCsv .\inactive.csv
.\powershell\Test-NetworkHosts.ps1 -Hosts 192.168.1.1,192.168.1.10 -Ports 22,80,443
```

### Bash

```bash
chmod +x bash/*.sh
sudo ./bash/linux-security-audit.sh
./bash/backup.sh /etc /var/backups/etc 7
```

## ⚠️ Disclaimer

Test in a lab first. Use `-WhatIf` on the PowerShell scripts that support it. Only scan systems you own or are allowed to test.
