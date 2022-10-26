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

fileLocal="${1}"
if [ ! -f "${fileLocal}" ]; then
  echo "ERROR: '${fileLocal}' must be a file!" >&2
  exit 1
fi

# Upload target, of the form `s3://bucket/prefix/file`
uploadTarget="${2}"
if [[ ! "${uploadTarget}" =~ ^s3://.*/.+[^/]$ ]]; then
  echo "ERROR: upload target _MUST_ be of the form 's3://bucket/path/file'!" >&2
  exit 1
fi

# Extract `bucket` and `pathRemote`:
bucket="$(cut -d/ -f3 <<<"${uploadTarget}")"
pathRemote="$(cut -d/ -f4- <<<"${uploadTarget}")"

# URL-encode the filename we pass
fileRemote="$(basename "${pathRemote}")"
#$({ curl --silent --get / --data-urlencode "=$(basename ${pathRemote})" --write-out '%{url}' || true; } | cut -c 3- | sed 's/+/%20/g')"

# Chop the file off the end of `pathRemote`
pathRemote="$(dirname "${pathRemote}")/"
if [[ "${pathRemote}" == "./" ]]; then
  pathRemote=""
fi


# Initialize helper variables
httpReq='PUT'
authType='AWS4-HMAC-SHA256'
service='s3'
host="${bucket}.${service}.${awsRegion}.amazonaws.com"
fullUrl="https://${host}/${pathRemote}${fileRemote}"
dateValueS=$(date -u +'%Y%m%d')
dateValueL=$(date -u +'%Y%m%dT%H%M%SZ')


# 0. Hash the file to be uploaded
payloadHash=$("${OPENSSL}" dgst -sha256 -hex < "${fileLocal}" 2>/dev/null | sed 's/^.* //')

# 1. Create canonical request
# NOTE: order significant in ${headerList} and ${canonicalRequest}
contentType="$(get_mimetype "${fileLocal}")"
headerList='content-type;host;x-amz-content-sha256;x-amz-date;x-amz-storage-class'
canonicalRequest="\
${httpReq}
/${pathRemote}${fileRemote}

content-type:${contentType}
host:${host}
x-amz-content-sha256:${payloadHash}
x-amz-date:${dateValueL}
x-amz-storage-class:STANDARD

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
  echo "${fileLocal} -> ${fullUrl}"
fi
curl --silent --fail --location --proto-redir =https --request "${httpReq}" --upload-file "${fileLocal}" \
  --header "Content-Type: ${contentType}" \
  --header "Host: ${host}" \
  --header "X-Amz-Content-SHA256: ${payloadHash}" \
  --header "X-Amz-Date: ${dateValueL}" \
  --header "X-Amz-Storage-Class: STANDARD" \
  --header "Authorization: ${authType} Credential=${awsAccess}/${dateValueS}/${awsRegion}/${service}/aws4_request, SignedHeaders=${headerList}, Signature=${signature}" \
  "${fullUrl}"
