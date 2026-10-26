#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p logs evidence
bash certs.sh 2>&1 | tee evidence/certificates.txt
bash generate.sh 2>&1 | tee evidence/build.txt
python manage.py check | tee evidence/django-check.txt
go test -race ./server/... -v | tee evidence/go-test.txt
nginx -p "$PWD/" -c nginx.conf -t 2>&1 | tee evidence/nginx-check.txt
./dice-server >logs/go.log 2>&1 & server_pid=$!
python manage.py runserver 127.0.0.1:8000 --noreload >logs/django.log 2>&1 & web_pid=$!
python manage.py runserver 127.0.0.1:8001 --noreload >logs/django-8001.log 2>&1 & web1_pid=$!
python manage.py runserver 127.0.0.1:8002 --noreload >logs/django-8002.log 2>&1 & web2_pid=$!
cleanup() {
    nginx -p "$PWD/" -c nginx.conf -s quit || true
    kill "$server_pid" "$web_pid" "$web1_pid" "$web2_pid" 2>/dev/null || true
}
trap cleanup EXIT
nginx -p "$PWD/" -c nginx.conf
python - <<'PY'
import socket, time
for port in (8443, 9448, 8000, 8001, 8002):
    for attempt in range(100):
        try:
            with socket.create_connection(("127.0.0.1", port), timeout=1):
                break
        except OSError:
            time.sleep(0.1)
    else:
        raise RuntimeError(f"Port {port} did not become ready")
PY
python -u check.py 2>&1 | tee evidence/integration.txt
if [[ "${CAPTURE:-0}" == "1" ]]; then python capture.py; fi
cp logs/*.log evidence/
