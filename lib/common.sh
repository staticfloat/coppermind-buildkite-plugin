#!/bin/bash

# For debugging
#set | grep BUILDKITE_PLUGIN_COPPERMIND

# Initialize the features we need
set -eou pipefail
shopt -s extglob
shopt -s globstar

function collect_glob_pattern() {
    # First argument is a glob pattern; we will output its result, with nulls at the end
    # We only pay attention to files, ignoring directories completely.
    for f in ${1}; do
        if [[ -f ${f} ]]; then
            printf "%s\0" "${f}"
        fi
    done
}

# poor man's treehash of a set of files; use with `collect_glob_pattern`
function calc_treehash() {
    sort -z | xargs -0 shasum -a 256 | shasum -a 256 | awk '{ print $1 }'
}

# array joining
function join_by {
    local IFS="$1"
    shift
    echo "$*"
}

# The prefix we'll upload/download stuff to/from
S3_PREFIX="${BUILDKITE_PLUGIN_COPPERMIND_S3_PREFIX}"
if [[ "${S3_PREFIX}" != s3://* ]]; then
    S3_PREFIX="s3://${S3_PREFIX}"
fi
BUILDKITE_S3_DEFAULT_REGION=${BUILDKITE_PLUGIN_COPPERMIND_S3_REGION:-us-east-1}
