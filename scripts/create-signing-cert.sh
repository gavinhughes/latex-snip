#!/bin/bash
# One-time: create a self-signed code-signing identity in the login keychain
# so install-macos-app.sh can sign with a stable certificate and macOS keeps
# Screen Recording / Accessibility grants across rebuilds.
set -euo pipefail
NAME="${SIGN_IDENTITY:-LaTeX Snip Local Signing}"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
# System LibreSSL writes a PKCS#12 that `security import` accepts.
OPENSSL=/usr/bin/openssl

if security find-identity -p codesigning | grep -qF "\"$NAME\""; then
  echo "Identity '$NAME' already exists."
  exit 0
fi

TMP="$(mktemp -d)"
chmod 700 "$TMP"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

"$OPENSSL" req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -config "$TMP/cert.cnf" -keyout "$TMP/key.pem" -out "$TMP/cert.pem"
PASS="$("$OPENSSL" rand -hex 16)"
"$OPENSSL" pkcs12 -export -name "$NAME" -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -out "$TMP/id.p12" -passout pass:"$PASS"
# -T lets codesign use the private key without a prompt on every build.
security import "$TMP/id.p12" -k "$KEYCHAIN" -P "$PASS" -T /usr/bin/codesign

echo "Created:"
security find-identity -p codesigning | grep -F "\"$NAME\""
