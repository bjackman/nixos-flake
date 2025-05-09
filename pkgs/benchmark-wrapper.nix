{ writeShellApplication, pkgs }:
writeShellApplication {
  name = "benchmarks-wrapper";
  runtimeInputs = [ pkgs.docopts pkgs.fio ];
  excludeShellChecks =
    [ "SC2154" "SC1091" ]; # Shellcheck can't tell ARGS_* is set.
  text = ''
    DOC="
    Usage:
        benchmarks-wrapper [--out-dir DIR]
        benchmarks-wrapper --help

    Options:
        -h --help              Show this screen.
        -o DIR --out-dir DIR   Directory to dump results in. Default uses mktemp.
    "
    eval "$(docopts -G ARGS -h "$DOC" : "$@")"

    set -e

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
        echo "No /run/current-system - not NodeOS? Not capturing system data"
    elif [ "$(readlink /run/current-system)" != "$(readlink /run/booted-system)" ]; then
        echo "current-system not the same as booted-system, not capturing system data"
    else
        cp /etc/os-release "$OUT_DIR"/etc_os-release
        nixos-version --json > "$OUT_DIR"/nixos-version.json
    fi

    exec fio --name=randread \
    --rw=randread --size=64M --blocksize=4K --directory=/tmp \
        --output="$OUT_DIR"/fio_output.json --output-format=json+
  '';
}
