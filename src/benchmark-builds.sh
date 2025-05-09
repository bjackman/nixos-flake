set -eux -o pipefail

DOC="
Usage:
    benchmark-builds HOST BUILD [BUILD...]
    benchmark-builds --help

Options:
    -h --help  Show this screen.
    HOST       Hostname/IP of target. All other options (port, user) hardcoded.
    BUILD      Flake reference to use for nixos-rebuild (e.g. .#aethelred-asi-off).
"
eval "$(docopts -G ARGS -h "$DOC" : "$@")"

USER=brendan  # good user, good 2 hard code
HOST_SSH_PORT=22

for build in "${ARGS_BUILD[@]}"; do
    nixos-rebuild --flake "$build" --target-host "$USER@$ARGS_HOST" --use-remote-sudo switch
    ssh "$USER@$ARGS_HOST" sudo reboot

    # Wait until the SSH port becomes visible.
    # -z = scan only,  -w5 = 5s timeout
    deadline_s=$(($(date +%s) + 120))
    while ! ssh -o ConnectTimeout=5 "$USER@$ARGS_HOST" echo; do
        current_time_s=$(date +%s)
        if (( current_time_s > deadline_s )); then
            echo "Timed out after 2m waiting for host SSH port to appear"
            exit 1
        fi
        sleep 1
    done

    REMOTE_RESULTS_DIR=/tmp/benchmark-results
    mkdir -p ./results
    LOCAL_RESULTS_DIR=$(TMPDIR=./results mktemp -d)
    ssh "$USER@$ARGS_HOST" "rm -rf $REMOTE_RESULTS_DIR; mkdir $REMOTE_RESULTS_DIR"
    ssh "$USER@$ARGS_HOST" benchmarks-wrapper --out-dir "$REMOTE_RESULTS_DIR"
    scp -r "$USER@$ARGS_HOST":"$REMOTE_RESULTS_DIR" "$LOCAL_RESULTS_DIR"
done