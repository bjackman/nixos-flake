#!/bin/bash
#
# Usage:
#     benchmarks-guest --out-dir DIR <benchmark>
#     benchmarks-guest --help
#
# Options:
#     -h --help                                  Show this screen.
#     -o DIR --out-dir <dir>                     Directory to dump results in. Default uses mktemp.

set -eu -o pipefail

source docopts.sh --auto -G "$@"

if [ ! -d "$ARGS_out_dir" ]; then
    echo "$ARGS_out_dir not a directory"
    exit 1
fi
if [ -n "$( ls -A "$ARGS_out_dir" )" ]; then
    echo "$ARGS_out_dir not empty"
    exit 1
fi

# This tells the NixOS QEMU runner script to use the existint TMPDIR for its
# xchg shared directory.
export USE_TMPDIR=1
TMPDIR="$(mktemp -d)"
export TMPDIR
# This tells systemd in the guest to just run the benchmarks-wrapper and then
# shut down. I'm not sure why systemd.unit= is needed, maybe some foible of
# NixOS. The quotes need to make it literally into the kcmdline, they are parsed
# by systemd. /tmp/xchg is created by NixOS and setup by run-nixos-vm (by
# default) as a shared directory.
export QEMU_KERNEL_PARAMS="systemd.run=\"/run/current-system/sw/bin/benchmarks-wrapper --out-dir /tmp/xchg $ARGS_benchmark \" systemd.unit=kernel-command-line.service"

# This should run the 'guest' nixosConfiguration then shut down.
run-nixos-vm

cp -R "$TMPDIR"/xchg/* "$ARGS_out_dir"