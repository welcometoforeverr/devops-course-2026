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
if (( level >= 4 )); then
  echo '[4] Web server'
  check 'nginx active' active "$(systemctl is-active nginx 2>/dev/null)"
  check 'nginx syntax' ok "$(status sudo -n nginx -t)"
  check 'Certificate valid for threshold' ok "$(status openssl x509 -checkend "${AUDIT_CERT_SECONDS:-2592000}" -noout -in /etc/ssl/certs/devops.crt)"
  writable=$(find /var/www/devops-site -type f -perm -o+w -print 2>/dev/null) || writable=ERROR
  check 'No world-writable web files' '' "$writable"
  check 'TLS key mode' 600 "$(sudo -n stat -c '%a' /etc/ssl/private/devops.key 2>/dev/null)"
fi
if (( level >= 5 )); then
  echo '[5] Containers'
  check 'Docker active' active "$(systemctl is-active docker 2>/dev/null)"
  compose=(docker compose --project-directory "$account_home/app")
  db_id=$("${compose[@]}" ps -q db 2>/dev/null)
  check 'PostgreSQL healthy' healthy "$(docker inspect -f '{{.State.Health.Status}}' "$db_id" 2>/dev/null)"
  check 'App published only on loopback' '127.0.0.1:5000' "$("${compose[@]}" port app 5000 2>/dev/null)"
  db_ports=$(docker inspect -f '{{json .NetworkSettings.Ports}}' "$db_id" 2>/dev/null)
  check 'Database has no published host port' ok "$(grep -q '"5432/tcp":null' <<<"$db_ports" && echo ok || echo fail)"
  exposed=$(ss -H -tln | awk '$4 ~ /:(5000|5432)$/ && $4 !~ /^127\.0\.0\.1:/ {print $4}')
  check 'No external 5000/5432 listener' '' "$exposed"
  check 'App environment mode' 600 "$(stat -c '%a' "$account_home/app/.env" 2>/dev/null)"
fi
if (( level >= 6 )); then
  echo '[6] Control work 2'
  compose=(docker compose --project-directory "$account_home/kr2")
  redis_id=$("${compose[@]}" ps -q redis 2>/dev/null)
  check 'Redis healthy' healthy "$(docker inspect -f '{{.State.Health.Status}}' "$redis_id" 2>/dev/null)"
  check 'KR2 published only on loopback' '127.0.0.1:8002' "$("${compose[@]}" port app 8002 2>/dev/null)"
  check 'KR2 environment mode' 600 "$(stat -c '%a' "$account_home/kr2/.env" 2>/dev/null)"
  check 'KR2 certificate validity' ok "$(status openssl x509 -checkend 2592000 -noout -in /etc/ssl/certs/kr2.crt)"
  check 'KR2 site enabled' ok "$(test -L /etc/nginx/sites-enabled/kr2 && echo ok || echo fail)"
fi
printf 'PASS=%s FAIL=%s\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
