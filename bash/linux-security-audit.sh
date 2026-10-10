#!/usr/bin/env bash
# linux-security-audit.sh - quick, read-only security overview of a Linux host.
# Usage: sudo ./linux-security-audit.sh [report-file]
set -u

REPORT="${1:-audit-$(hostname)-$(date +%F).txt}"
exec > >(tee "$REPORT") 2>&1

section() { printf '\n==== %s ====\n' "$1"; }
warn()    { printf '[!] %s\n' "$1"; }
ok()      { printf '[+] %s\n' "$1"; }

[ "$(id -u)" -eq 0 ] || warn "Not running as root: some checks will be incomplete."

section "System"
echo "Host:   $(hostname)"
echo "Kernel: $(uname -r)"
[ -r /etc/os-release ] && . /etc/os-release && echo "OS:     ${PRETTY_NAME:-unknown}"
echo "Uptime: $(uptime -p 2>/dev/null || uptime)"

section "Accounts with UID 0"
awk -F: '$3 == 0 {print $1}' /etc/passwd | while read -r u; do
    [ "$u" = "root" ] && ok "root" || warn "Extra UID 0 account: $u"
done

section "Accounts with an empty password"
if [ -r /etc/shadow ]; then
    empty=$(awk -F: '$2 == "" {print $1}' /etc/shadow)
    [ -z "$empty" ] && ok "None" || warn "Empty password: $empty"
fi

section "Users with a login shell"
grep -Ev '(nologin|false)$' /etc/passwd | cut -d: -f1,7

section "Sudo privileges"
getent group sudo wheel 2>/dev/null
grep -rhE '^[^#].*ALL' /etc/sudoers /etc/sudoers.d/ 2>/dev/null
grep -rh 'NOPASSWD' /etc/sudoers /etc/sudoers.d/ 2>/dev/null | grep -v '^#' && warn "NOPASSWD rules found"

section "SSH configuration"
if command -v sshd >/dev/null 2>&1; then
    cfg=$(sshd -T 2>/dev/null)
    check() {
        val=$(echo "$cfg" | awk -v k="$1" '$1 == k {print $2}')
        if [ "$val" = "$2" ]; then ok "$1 $val"; else warn "$1 is '${val:-unset}' (recommended: $2)"; fi
    }
    check permitrootlogin no
    check passwordauthentication no
    check x11forwarding no
    check maxauthtries 3
else
    echo "sshd not installed"
fi

section "Listening ports"
(ss -tulpn 2>/dev/null || netstat -tulpn 2>/dev/null) | sed -n '1,40p'

section "Firewall"
if command -v ufw >/dev/null 2>&1; then ufw status verbose
elif command -v firewall-cmd >/dev/null 2>&1; then firewall-cmd --list-all
elif command -v nft >/dev/null 2>&1; then nft list ruleset | head -40
else warn "No firewall tool found"; fi

section "World-writable files in /etc"
ww=$(find /etc -xdev -type f -perm -0002 2>/dev/null)
[ -z "$ww" ] && ok "None" || { warn "World-writable:"; echo "$ww"; }

section "SUID binaries"
find / -xdev -type f -perm -4000 2>/dev/null | sort

section "Pending updates"
if command -v apt >/dev/null 2>&1; then
    apt list --upgradable 2>/dev/null | tail -n +2 | wc -l | xargs -I{} echo "{} package(s) upgradable"
elif command -v dnf >/dev/null 2>&1; then
    dnf -q check-update | grep -c '^[a-zA-Z0-9]' | xargs -I{} echo "{} package(s) upgradable"
fi

section "Recent failed logins"
(lastb -n 10 2>/dev/null || journalctl -u ssh -u sshd --since "24 hours ago" 2>/dev/null | grep -i 'failed' | tail -10)

printf '\nReport saved to %s\n' "$REPORT"
