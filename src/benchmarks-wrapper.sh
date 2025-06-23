#!/bin/bash
#
# Takes care of spinning up a VM if needed amd running instrumentation.
#
# Usage:
#     benchmarks-wrapper [--out-dir DIR] [--instrument] [--iterations <iterations>] <benchmark>
#     benchmarks-wrapper --help
#
# Options:
#     -h --help                                  Show this screen.
#     -i --instrument                            Run instrumentation for these benchmarks
#     -o DIR --out-dir <dir>                     Directory to dump results in. Default uses mktemp.
#     -n <iterations> --iterations <iterations>  Iterations to run. Default depends on benhchmark.
#     <benchmark>                                One of the benchmarks supported by run-benchmark

set -e

source docopts.sh --auto -G "$@"

OUT_DIR="$ARGS_out_dir"
if [ -z "$OUT_DIR" ]; then
    OUT_DIR="$(mktemp -d)"
    echo "Dumping results in $OUT_DIR, specify --out-dir to override"
fi

if [ ! -d "$OUT_DIR" ]; then
    echo "$OUT_DIR not a directory"
    exit 1
fi
if [ -n "$( ls -A "$OUT_DIR" )" ]; then
    echo "$OUT_DIR not empty"
    exit 1
fi

# We'll record the version of the system, to be as hermetic as possible,
# bail if there have been configuration changes since the last reboot.
if [ ! -d /run/current-system ]; then
    echo "No /run/current-system - not NixOS? Not capturing system data"
elif [ "$(readlink /run/current-system)" != "$(readlink /run/booted-system)" ]; then
    echo "current-system not the same as booted-system, not capturing system data"
else
    cp /etc/os-release "$OUT_DIR"/etc_os-release
    # Can't make this available via writeShellApplication as it's just something
    # baked into the NixOS system, not a package in nixpkgs.
    /run/current-system/sw/bin/nixos-version --json > "$OUT_DIR"/nixos-version.json
    readlink /run/current-system > "$OUT_DIR"/nixos-system.txt
fi

if "$ARGS_instrument"; then
    # shellcheck disable=SC2024
    sudo bpftrace_asi_exits &> "$OUT_DIR"/bpftrace_asi_exits.log &
    bpftrace_pid=$!
fi

run-benchmark --out-dir "$OUT_DIR" --iterations "$ARGS_iterations" "$ARGS_benchmark"

if "$ARGS_instrument"; then
    sudo kill -SIGINT "$bpftrace_pid"
fi

echo FIO results in "$OUT_DIR"