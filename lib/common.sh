#!/bin/bash

## This script requires:
#    - openssl
#    - tar
#    - zstd

COPPERMIND_REPO="$( cd "$( dirname "$( dirname "${BASH_SOURCE[0]}" )" )" &> /dev/null && pwd )"

# Load in our bash-tools
source "${COPPERMIND_REPO}/lib/bash-tools/lib/buildkite.sh"
source "${COPPERMIND_REPO}/lib/bash-tools/lib/glob.sh"
source "${COPPERMIND_REPO}/lib/bash-tools/lib/treehash.sh"

# The prefix and bucket we'll upload/download stuff to/from
S3_BUCKET="${BUILDKITE_PLUGIN_COPPERMIND_S3_PREFIX#s3://}"
S3_BUCKET="${S3_BUCKET%%/*}"
S3_PREFIX="${BUILDKITE_PLUGIN_COPPERMIND_S3_PREFIX#s3://${S3_BUCKET}/}"
S3_PREFIX="${S3_PREFIX%/}"

readarray -d '' -t INPUT_PATTERNS < <(collect_buildkite_array "BUILDKITE_PLUGIN_COPPERMIND_INPUTS")
if [[ "${#INPUT_PATTERNS[@]}" == 0 ]]; then
    die "No inputs specified!"
fi

# If we haven't already calculated the input hash, do so:
if [[ ! -v "BUILDKITE_PLUGIN_COPPERMIND_INPUT_HASH" ]]; then
    INPUT_TREEHASHES=()
    echo "-> Collecting ${#INPUT_PATTERNS[@]} patterns"
    for PATTERN in "${INPUT_PATTERNS[@]}"; do
        HASH="$(collect_glob_pattern "${PATTERN}" | calc_treehash)"
        echo "    + ${HASH} <- ${PATTERN}"
        INPUT_TREEHASHES+=( "${HASH}" )
    done
    # Hash all treehashes together
    export BUILDKITE_PLUGIN_COPPERMIND_INPUT_HASH="$(printf "%s" "${INPUT_TREEHASHES[@]}" | calc_shasum)"
    echo "    ∟ ${BUILDKITE_PLUGIN_COPPERMIND_INPUT_HASH}"
fi
INPUT_HASH="${BUILDKITE_PLUGIN_COPPERMIND_INPUT_HASH}"

# Receive the artifact name from the user
ARTIFACT_NAME="${BUILDKITE_PLUGIN_COPPERMIND_ARTIFACT_NAME:-${BUILDKITE_STEP_KEY:-}}"
if [[ -z "${ARTIFACT_NAME}" ]]; then
    die "Must provide either a buildkite step key or an artifact_name!"
fi
