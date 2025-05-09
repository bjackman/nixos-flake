set -eux -o pipefail

DOC="
Usage:
    benchmark-builds [--result-db RESULT_DB] HOST BUILD [BUILD...]
    benchmark-builds --help

Options:
    -h --help              Show this screen.
    --result-db RESULT_DB  Magic result database to upload to [default: ./results].
    HOST                   Hostname/IP of target. All other options (port, user) hardcoded.
    BUILD                  Flake reference to use for nixos-rebuild (e.g. .#aethelred-asi-off).
"
eval "$(docopts -G ARGS -h "$DOC" : "$@")"

USER=brendan  # good user, good 2 hard code

RESULT_NAME=nixos-asi-benchmarks

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

    # Run the benchmarks
    REMOTE_RESULTS_DIR=/tmp/benchmark-results
    # shellcheck disable=SC2029
    ssh "$USER@$ARGS_HOST" "rm -rf $REMOTE_RESULTS_DIR; mkdir $REMOTE_RESULTS_DIR"
    ssh "$USER@$ARGS_HOST" benchmarks-wrapper --out-dir "$REMOTE_RESULTS_DIR"

    # Fetch the results
    local_results_dir=$(mktemp -d)
    scp -r "$USER@$ARGS_HOST":"$REMOTE_RESULTS_DIR/*" "$local_results_dir"

    # Hash them and store them in the format required by my cool secret
    # benchmarking result schema: $name:$hash.
    # For these results we consider all the artifacts to be part of the hash
    # input, if any file differs it must be a repeated run.
    result_hash=$(find "$local_results_dir" -type f -exec cat {} \; | sha256sum | awk '{ print substr($1, 1, 12) }')
    artifacts_dir="$ARGS_result_db/$RESULT_NAME:$result_hash/artifacts"
    if [ -e "$artifacts_dir" ]; then
        echo "$artifacts_dir already exists!"
        exit 1
    fi
    mkdir -p "$artifacts_dir"
    mv "$local_results_dir"/* "$artifacts_dir"
done