#!/usr/bin/env bash
# Create a throwaway local certificate authority for the HTTPS static test
# server. Never use these files outside local development.
#
# Output (gitignored): app/.local-https/{ca.pem,server.pem,server.key}
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$root/.local-https"
validity_days="${DEV_CERT_DAYS:-2}"

command -v openssl >/dev/null 2>&1 ||
  { echo "openssl is required to create the local test certificate." >&2; exit 1; }

mkdir -p "$out"
chmod 700 "$out"

# Reuse the certificate while it is valid for at least a day.
if [ -s "$out/server.pem" ] && [ -s "$out/server.key" ] && [ -s "$out/ca.pem" ] &&
  openssl x509 -checkend 86400 -noout -in "$out/server.pem" >/dev/null 2>&1; then
  exit 0
fi

rm -f "$out"/ca.pem "$out"/ca.key "$out"/server.pem "$out"/server.key \
  "$out"/server.csr "$out"/ca.srl "$out"/server.ext

openssl genrsa -out "$out/ca.key" 2048 >/dev/null 2>&1
openssl req -x509 -new -key "$out/ca.key" -sha256 -days "$validity_days" \
  -subj "/CN=Local First App Development CA" \
  -out "$out/ca.pem" >/dev/null 2>&1

openssl genrsa -out "$out/server.key" 2048 >/dev/null 2>&1
openssl req -new -key "$out/server.key" \
  -subj "/CN=localhost" -out "$out/server.csr" >/dev/null 2>&1

cat >"$out/server.ext" <<'EOF'
basicConstraints = critical, CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = DNS:localhost, IP:127.0.0.1
EOF

openssl x509 -req -in "$out/server.csr" -CA "$out/ca.pem" -CAkey "$out/ca.key" \
  -CAserial "$out/ca.srl" -CAcreateserial -days "$validity_days" -sha256 \
  -extfile "$out/server.ext" -out "$out/server.pem" >/dev/null 2>&1

rm -f "$out/server.csr" "$out/server.ext" "$out/ca.srl"
chmod 600 "$out/ca.key" "$out/server.key"

echo "created local development certificate in $out"
