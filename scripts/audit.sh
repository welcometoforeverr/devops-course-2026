#!/usr/bin/env bash
set -uo pipefail
if (( EUID != 0 )); then
  exec sudo --preserve-env=AUDIT_LEVEL,AUDIT_HOME,AUDIT_CERT_SECONDS bash "$0" "$@"
fi
export LC_ALL=C
PASS=0; FAIL=0
check() {
  local description="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    printf '[OK] %s\n' "$description"; PASS=$((PASS+1))
  else
    printf '[FAIL] %s (expected=%s actual=%s)\n' "$description" "$expected" "$actual"
    FAIL=$((FAIL+1))
  fi
}
status() { if "$@" >/dev/null 2>&1; then printf ok; else printf fail; fi; }
level="${AUDIT_LEVEL:-3}"
account_home="${AUDIT_HOME:-/home/devops}"
if [[ -z "${AUDIT_LEVEL:-}" ]]; then
  [[ -L /etc/nginx/sites-enabled/devops-site ]] && level=4
  [[ -f "$account_home/app/docker-compose.yml" ]] && level=5
  [[ -f "$account_home/kr2/docker-compose.yml" ]] && level=6
fi
printf 'Configuration audit: %s\n' "$(hostname -f)"
echo '[1] SSH'
settings=$(sudo -n /usr/sbin/sshd -T 2>/dev/null) || settings=''
value() { awk -v key="$1" '$1==key {print $2}' <<<"$settings"; }
check 'Root login disabled' no "$(value permitrootlogin)"
check 'Password authentication disabled' no "$(value passwordauthentication)"
check 'Public key authentication enabled' yes "$(value pubkeyauthentication)"
check 'SSH port' 2222 "$(value port)"
check 'MaxAuthTries' 3 "$(value maxauthtries)"
echo '[2] Firewall'
firewall=$(sudo -n ufw status verbose 2>/dev/null) || firewall=''
check 'UFW active' active "$(awk '/^Status:/{print $2}' <<<"$firewall")"
check 'Default incoming deny' ok "$(grep -q 'Default: deny (incoming)' <<<"$firewall" && echo ok || echo fail)"
echo '[3] Accounts'
id devops
check 'devops in sudo group' ok "$(id -nG devops | tr ' ' '\n' | grep -qx sudo && echo ok || echo fail)"
printf 'PASS=%s FAIL=%s\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
