#!/bin/bash
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
#     <benchmark>                                Either 'fio' or 'compile-kernel'

set -e

source docopts.sh --auto -G "$@"

# Get the type of the filesystem that a file is on.
function findmnt_fstype() {
    findmnt --target "$1" --json | jq --raw-output "
      if (.filesystems | length) == 1 then
        .filesystems[0].fstype
      else
        error(\"Not exactly one fstype found for $1\")
      end"
}

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

ITERATIONS="$ARGS_iterations"
if [ -z "$ITERATIONS" ]; then
    if [ "$ARGS_benchmark" = "fio" ]; then
        ITERATIONS=10
    else
        ITERATIONS=3
    fi
fi

# We'll record the version of the system, to be as hermetic as possible,
# bail if there have been configuration changes since the last reboot.
if [ ! -d /run/current-system ]; then
    echo "No /run/current-system - not NixOS? Not capturing system data"
elif [ "$(readlink /run/current-system)" != "$(readlink /run/booted-system)" ]; then
    echo "current-system not the same as booted-system, not capturing system data"
else
    cp /etc/os-release "$OUT_DIR"/etc_os-release
    nixos-version --json > "$OUT_DIR"/nixos-version.json
    readlink /run/current-system > "$OUT_DIR"/nixos-system.txt
fi

if "$ARGS_instrument"; then
    # shellcheck disable=SC2024
    sudo bpftrace_asi_exits &> "$OUT_DIR"/bpftrace_asi_exits.log &
    bpftrace_pid=$!
fi

for i in $(seq "$ITERATIONS"); do
    if [ "$ARGS_benchmark" == "fio" ]; then
        # This script encodes assumptions about the host system, check them.
        if [ "$(findmnt_fstype /tmp)" != "tmpfs" ]; then
            echo "/tmp is not a tmpfs"
            exit 1
        fi
        fio --name=randread_tmpfs \
            --rw=randread --size=1G --blocksize=4K --directory=/tmp \
            --output="$OUT_DIR/fio_output_tmpfs_$i.json" --output-format=json+

        if [ "$(findmnt_fstype /var/tmp)" != "ext4" ]; then
            echo "/tmp is not a tmpfs"
            exit 1
        fi
        fio --name=randread_ext4 \
            --rw=randread --size=1G --blocksize=4K --directory=/tmp \
            --output="$OUT_DIR/fio_output_ext4_$i.json" --output-format=json+
    else
        before_ns="$(date +%s%N)"
        compile-kernel
        after_ns="$(date +%s%N)"
        echo "$(( after_ns - before_ns ))" > "$OUT_DIR/compile-kernel_elapsed_ns_$i"
    fi
done

if "$ARGS_instrument"; then
    sudo kill -SIGINT "$bpftrace_pid"
fi

echo FIO results in "$OUT_DIR"