DOC="
Usage:
    benchmark-builds HOST BUILDS...
    benchmark-builds --help

Options:
    -h --help Show this screen.
    HOST      Host to run benchmarks on. Just the hostname/IP. Username and
              other SSH params are hardcoded.
"
eval "$(docopts -G ARGS -h "$DOC" : "$@")"
set -eux

HOST_SSH_PORT=22

host_ssh_visible() {
    nc -zw5 "$HOST" $HOST_SSH_PORT
}
echo "$ARGS_HOST"
for build in "${ARGS_BUILDS[@]}"; do
    nixos-rebuild --flake "$build" --target-host "$ARGS_HOST" --use-remote-sudo switch
    ssh "$ARGS_HOST" sudo reboot

    # Wait until the SSH port becomes visible.
    # -z = scan only,  -w5 = 5s timeout
    deadline_s=$(($(date +%s) + 120))
    while ! host_ssh_visible; do
        current_time_s=$(date +%s)
        if (( current_time_s > deadline_s )); then
            echo "Timed out after 2m waiting for host SSH port to appear"
            exit 1
        fi
        sleep 1
    done

    REMOTE_RESULTS_DIR=/tmp/benchmark-results
    ssh "$ARGS_HOST" rm -rf "$REMOTE_RESULTS_DIR"
    ssh "$ARGS_HOST" benchmarks-wrapper --out-dir "$REMOTE_RESULTS_DIR"
    scp -R "$ARGS_HOST":"$REMOTE_RESULTS_DIR" ./results
done