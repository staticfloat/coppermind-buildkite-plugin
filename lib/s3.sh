#!/bin/bash
set -eou pipefail

# Find OpenSSL, as on macOS we need a newer version than is shipped by default
OPENSSL="openssl"
for OPENSSL_HOME in /usr/local/opt/openssl@1.1 /opt/homebrew/opt/openssl@1.1 \
                    /usr/local/opt/openssl     /opt/homebrew/opt/openssl; do
  if [ -f "${OPENSSL_HOME}/bin/openssl" ]; then
    OPENSSL="${OPENSSL_HOME}/bin/openssl"
    break
  fi
done


# Get access keys from the environment
awsAccess="${AWS_ACCESS_KEY_ID}"
awsSecret="${AWS_SECRET_ACCESS_KEY}"
awsRegion="${AWS_DEFAULT_REGION:-us-east-1}"


# Helper function to sign the pieces of a request
awsStringSign4() {
  kSecret="AWS4$1"
  kDate=$(printf         '%s' "$2" | "${OPENSSL}" dgst -sha256 -hex -mac HMAC -macopt    "key:${kSecret}"  2>/dev/null | sed 's/^.* //')
  kRegion=$(printf       '%s' "$3" | "${OPENSSL}" dgst -sha256 -hex -mac HMAC -macopt "hexkey:${kDate}"    2>/dev/null | sed 's/^.* //')
  kService=$(printf      '%s' "$4" | "${OPENSSL}" dgst -sha256 -hex -mac HMAC -macopt "hexkey:${kRegion}"  2>/dev/null | sed 's/^.* //')
  kSigning=$(printf 'aws4_request' | "${OPENSSL}" dgst -sha256 -hex -mac HMAC -macopt "hexkey:${kService}" 2>/dev/null | sed 's/^.* //')
  signedString=$(printf  '%s' "$5" | "${OPENSSL}" dgst -sha256 -hex -mac HMAC -macopt "hexkey:${kSigning}" 2>/dev/null | sed 's/^.* //')
  printf '%s' "${signedString}"
}

# Automatically determine the MIME type using `file`, if it's available
if command -v file >/dev/null 2>&1; then
  get_mimetype() { file --brief --mime-type "${1}"; }
else
  get_mimetype() { echo "application/octet-stream"; }
fi
