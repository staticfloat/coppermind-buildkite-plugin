#!/bin/bash

# This script gratefully adapted from https://gist.github.com/vszakats/2917d28a951844ab80b1

# To the extent possible under law, Viktor Szakats
# has waived all copyright and related or neighboring rights to this
# script.
# CC0 - https://creativecommons.org/publicdomain/zero/1.0/
# SPDX-License-Identifier: CC0-1.0

# THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Upload a file to Amazon AWS S3 (and compatible) using Signature Version 4
#
# docs:
#   https://docs.aws.amazon.com/general/latest/gr/sigv4-create-canonical-request.html
#   https://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-query-string-auth.html
#
# requires:
#   curl, openssl 1.x or newer, GNU sed, LF EOLs in this file

set -euo pipefail

COPPERMIND_REPO="$(dirname $( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd ))"
source "${COPPERMIND_REPO}/lib/s3.sh"

# Download target, of the form `s3://bucket/prefix/file`
downloadTarget="${1}"
if [[ ! "${downloadTarget}" =~ ^s3://.*/.+[^/]$ ]]; then
  echo "ERROR: upload target _MUST_ be of the form 's3://bucket/path/file'!" >&2
  exit 1
fi

fileLocal="${2}"
if [[ ! -d "$(dirname ${fileLocal})" ]]; then
    echo "ERROR: Must create directory to store '${fileLocal}'" >&2
    exit 1
fi

# Extract `bucket` and `pathRemote`:
bucket="$(cut -d/ -f3 <<<"${downloadTarget}")"
pathRemote="$(cut -d/ -f4- <<<"${downloadTarget}")"

# URL-encode the filename we pass
fileRemote="$(basename "${pathRemote}")"
#$({ curl --silent --get / --data-urlencode "=$(basename ${pathRemote})" --write-out '%{url}' || true; } | cut -c 3- | sed 's/+/%20/g')"

# Chop the file off the end of `pathRemote`
pathRemote="$(dirname "${pathRemote}")/"
if [[ "${pathRemote}" == "./" ]]; then
  pathRemote=""
fi

# Initialize helper variables
httpReq='GET'
authType='AWS4-HMAC-SHA256'
service='s3'
host="${bucket}.${service}.${awsRegion}.amazonaws.com"
fullUrl="https://${host}/${pathRemote}${fileRemote}"
dateValueS=$(date -u +'%Y%m%d')
dateValueL=$(date -u +'%Y%m%dT%H%M%SZ')

# 0. Hash the payload (in this case, the empty file)
payloadHash=$("${OPENSSL}" dgst -sha256 -hex </dev/null 2>/dev/null | sed 's/^.* //')

# 1. Create canonical request
# NOTE: order significant in ${headerList} and ${canonicalRequest}
headerList='host;x-amz-content-sha256;x-amz-date'
canonicalRequest="\
${httpReq}
/${pathRemote}${fileRemote}

host:${host}
x-amz-content-sha256:${payloadHash}
x-amz-date:${dateValueL}

${headerList}
${payloadHash}"

# Hash it
canonicalRequestHash=$(printf '%s' "${canonicalRequest}" | "${OPENSSL}" dgst -sha256 -hex 2>/dev/null | sed 's/^.* //')

# 2. Create string to sign
stringToSign="\
${authType}
${dateValueL}
${dateValueS}/${awsRegion}/${service}/aws4_request
${canonicalRequestHash}"

# 3. Sign the string
signature=$(awsStringSign4 "${awsSecret}" "${dateValueS}" "${awsRegion}" "${service}" "${stringToSign}")

# Upload
if [[ $@ != *--quiet* ]]; then
  echo "${fullUrl} -> ${fileLocal}"
fi
curl --fail --location --proto-redir =https --request "${httpReq}" -o "${fileLocal}" \
  --header "Host: ${host}" \
  --header "X-Amz-Content-SHA256: ${payloadHash}" \
  --header "X-Amz-Date: ${dateValueL}" \
  --header "Authorization: ${authType} Credential=${awsAccess}/${dateValueS}/${awsRegion}/${service}/aws4_request, SignedHeaders=${headerList}, Signature=${signature}" \
  "${fullUrl}"
