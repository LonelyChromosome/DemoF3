#!/usr/bin/env bash
set -euo pipefail
umask 077

if [[ $# -ne 1 ]]; then
  echo 'Usage: bash tool/create_release_keys.sh /absolute/private/directory' >&2
  exit 2
fi

destination="$1"
if [[ "$destination" != /* || -e "$destination" ]]; then
  echo 'Choose a new absolute directory outside the repository.' >&2
  exit 2
fi

parent="$(dirname "$destination")"
if [[ ! -d "$parent" ]] || git -C "$parent" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo 'The parent must exist and must be outside every Git working tree.' >&2
  exit 2
fi

command -v keytool >/dev/null
command -v openssl >/dev/null
command -v base64 >/dev/null

read -r -s -p 'New private keystore password (16+ characters): ' release_password
echo
read -r -s -p 'Repeat password: ' repeat_password
echo
if [[ ${#release_password} -lt 16 || "$release_password" != "$repeat_password" ]]; then
  echo 'Password is too short or does not match.' >&2
  exit 2
fi
unset repeat_password
export COOC_KEYTOOL_PASSWORD="$release_password"
unset release_password
mkdir -m 700 "$destination"

keytool -genkeypair -alias cooc-release-v1 -keyalg RSA -keysize 4096 \
  -sigalg SHA256withRSA -validity 10000 -storetype PKCS12 \
  -storepass:env COOC_KEYTOOL_PASSWORD -keypass:env COOC_KEYTOOL_PASSWORD \
  -keystore "$destination/cooc-release-v1.jks" \
  -dname 'CN=Better Phenikaa cooc Release, O=Better Phenikaa'

openssl genpkey -algorithm Ed25519 -out "$destination/update-manifest-ed25519-private.pem"
chmod 600 "$destination/cooc-release-v1.jks" "$destination/update-manifest-ed25519-private.pem"

fingerprint="$(keytool -list -v -alias cooc-release-v1 \
  -storepass:env COOC_KEYTOOL_PASSWORD \
  -keystore "$destination/cooc-release-v1.jks" | \
  awk -F 'SHA256: ' '/SHA256: / {print $2; exit}' | tr -d ':' | tr 'A-F' 'a-f')"
unset COOC_KEYTOOL_PASSWORD
if [[ ! "$fingerprint" =~ ^[0-9a-f]{64}$ ]]; then
  echo 'Could not read the certificate fingerprint.' >&2
  exit 1
fi

public_key="$(openssl pkey -in "$destination/update-manifest-ed25519-private.pem" \
  -pubout -outform DER | tail -c 32 | base64 | tr -d '\n')"
echo "Alias: cooc-release-v1"
echo "EXPECTED_APK_CERT_SHA256=$fingerprint"
echo "UPDATE_PUBLIC_KEY_BASE64=$public_key"
echo "Private keys are in $destination. Keep this directory offline and backed up."
