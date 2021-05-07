#!/usr/bin/env bats

export BUILDKITE_PLUGIN_COPPERMIND_S3_PREFIX="s3://julialang-buildkite-artifacts/testing"

load "$BATS_PATH/load.bash"
source "/plugin/lib/common.sh"

function create_test_tree() {
    mkdir -p "A"
    echo "Hello There" > "A/general_kenobi.txt"
    mkdir -p "B/empty_dir"
    echo "For Science" > "B/you_monster.exe"
    echo "1554" > "black_mesa_east.password"
}


@test "collect_glob_pattern (dir)" {
    dir="$(mktemp -d)"
    pushd "${dir}"
    create_test_tree

    # ${dir} finds all files within the prefix
    run collect_glob_pattern "${dir}"
    assert_output --partial "${dir}/A/general_kenobi.txt"
    assert_output --partial "${dir}/B/you_monster.exe"
    assert_output --partial "${dir}/black_mesa_east.password"
    refute_output --partial "${dir}/B/empty_dir"
    assert_success

    # ${dir}/**/* also finds all files within the prefix
    run collect_glob_pattern "${dir}/**/*"
    assert_output --partial "${dir}/A/general_kenobi.txt"
    assert_output --partial "${dir}/B/you_monster.exe"
    assert_output --partial "${dir}/black_mesa_east.password"
    refute_output --partial "${dir}/B/empty_dir"
    assert_success

    # ./**/* also finds all files within the prefix
    run collect_glob_pattern "./**/*"
    assert_output --partial "./A/general_kenobi.txt"
    assert_output --partial "./B/you_monster.exe"
    assert_output --partial "./black_mesa_east.password"
    refute_output --partial "./B/empty_dir"
    assert_success

    # ${dir}/* only finds a top-level file
    run collect_glob_pattern "${dir}/*"
    refute_output --partial "${dir}/A/general_kenobi.txt"
    refute_output --partial "${dir}/B/you_monster.exe"
    assert_output --partial "${dir}/black_mesa_east.password"
    refute_output --partial "${dir}/B/empty_dir"
    assert_success

    # ${dir}/* only finds a top-level file
    run collect_glob_pattern "*"
    refute_output --partial "A/general_kenobi.txt"
    refute_output --partial "B/you_monster.exe"
    assert_output --partial "black_mesa_east.password"
    refute_output --partial "B/empty_dir"
    assert_success

    # Advanced globbing!
    run collect_glob_pattern "${dir}/**/*.txt"
    assert_output --partial "${dir}/A/general_kenobi.txt"
    refute_output --partial "${dir}/B/you_monster.exe"
    refute_output --partial "${dir}/black_mesa_east.password"
    refute_output --partial "${dir}/B/empty_dir"
    assert_success

    run collect_glob_pattern "./**/*.txt"
    assert_output --partial "./A/general_kenobi.txt"
    refute_output --partial "./B/you_monster.exe"
    refute_output --partial "./black_mesa_east.password"
    refute_output --partial "./B/empty_dir"
    assert_success

    popd
    rm -rf "${dir}"
}

function collect_treehash() {
    collect_glob_pattern "${1}" | calc_treehash
}

@test "calc_treehash" {
    dir="$(mktemp -d)"
    pushd "${dir}"
    create_test_tree

    # "." finds all files within the prefix
    run collect_treehash "."
    assert_output "a0cff14ce10cd97a1c867ca3659cb17571b6b6824e9c33facd15206e4bf19f42"
    assert_success

    # Grabbing the whole directory by name works too
    run collect_treehash "${dir}"
    assert_output "a0cff14ce10cd97a1c867ca3659cb17571b6b6824e9c33facd15206e4bf19f42"
    assert_success

    # Globbing differently gives exactly the same treehash
    run collect_treehash "**/*"
    assert_output "a0cff14ce10cd97a1c867ca3659cb17571b6b6824e9c33facd15206e4bf19f42"
    assert_success

    # We can glob to grab only one ".txt" file
    run collect_treehash "**/*.txt"
    assert_output "a03e24f55465ee4ec2bf2f75391b180a78c0d0c31ab8f3d94fc81b2232533021"
    assert_success

    # We can glob something that has no files/doesn't exist
    run collect_treehash "**/*.null"
    assert_output "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    assert_success
    run collect_treehash "${dir}/null"
    assert_output "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    assert_success

    # If we change just the filename of something, the treehash changes
    mv "${dir}/A/general_kenobi.txt" "${dir}/A/general_kenobi2.txt"
    run collect_treehash "${dir}"
    assert_output "1618b3f9a994dd6766126ce477e4fc6dce069b579abda49f0dc9122db9d291b1"
    assert_success

    # If we change just the content of something, the treehash changes
    echo >> "${dir}/A/general_kenobi2.txt"
    run collect_treehash "${dir}"
    assert_output "dcb37464ecec60c13cfab999be869862717b71c9eeaa0ba32c4638b8593b0f40"
    assert_success

    popd
}
