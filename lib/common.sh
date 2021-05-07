#!/bin/bash

# For debugging
#set | grep BUILDKITE_PLUGIN_COPPERMIND

# Initialize the features we need
set -eou pipefail
shopt -s extglob
shopt -s globstar

function collect_glob_pattern() {
    # First argument is either a glob pattern, or a directory.  If it is a directory,
    # we add `/**/*` to it in order to select everything underneath it.
    local target="${1}"
    local prefix="${1}"
    if [[ -d "${target}" ]]; then
        target="${target}/**/*"
    fi

    # Iterate over the glob pattern
    for f in ${target}; do
        # Ignore directories, only list files
        if [[ -f ${f} ]]; then
            printf "%s\0" "${f}"
        fi
    done
}

# Figure out which shasum program to use
if [[ -n $(which sha256sum 2>/dev/null) ]]; then
    SHASUM="sha256sum"
elif [[ -n $(which shasum 2>/dev/null) ]]; then
    SHASUM="shasum -a 256"
else
    echo "ERROR: No sha256sum/shasum available!" >&2
    buildkite-agent annotate --style error "No sha256sum/shasum available!"
    exit 1
fi

function calc_shasum() {
    ${SHASUM} "$@" | awk '{ print $1 }'
}

# poor man's treehash of a set of files; use with `collect_glob_pattern`
function calc_treehash() {
    # Fill `FILES` with all the files we're calculating the treehash over
    readarray -d '' FILES

    # If we have no files, exit early!
    if [[ "${#FILES[@]}" == 0 ]]; then
        calc_shasum < /dev/null | awk '{ print $1 }'
        return
    fi

    # Next, we fold things up into directories
    declare -A DIR_HASHES
    for f in $(sort <<< "${FILES[@]}"); do
        hash=$(calc_shasum "${f}" | awk '{ print $1 }')
        dir=$(dirname "${f}")
        DIR_HASHES["${dir}"]+=" $(basename ${f}) ${hash}"
    done

    # Collapse directories into their parents until none survive
    while [[ ${#DIR_HASHES[@]} -gt 1 ]]; do
        DIRS=$(tr ' ' '\n' <<< "${!DIR_HASHES[@]}")
        for f in $(sort <<< "${DIRS}"); do
            # If this directory appears only once, move it up to its parent
            if [[ "$(egrep "^${f}" <<< "${DIRS}")" == "${f}" ]]; then
                dir=$(dirname "${f}")
                hash=$( calc_shasum <<< "${DIR_HASHES["${f}"]}" | awk '{ print $1 }')
                DIR_HASHES["${dir}"]+=" $(basename ${f}) ${hash}"
                unset DIR_HASHES["${f}"]
            fi
        done
    done

    calc_shasum <<< ${DIR_HASHES[@]} | awk '{ print $1 }'
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
