#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/certs"
umask 077
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json \
  -hostname=127.0.0.1,localhost -profile=server server-csr.json | cfssljson -bare server
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json \
  -profile=client client-csr.json | cfssljson -bare client
openssl verify -CAfile ca.pem -purpose sslserver server.pem
openssl verify -CAfile ca.pem -purpose sslclient client.pem
