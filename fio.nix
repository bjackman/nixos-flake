{ pkgs, ... }:
let
  fio-wrapper-pkg = pkgs.writeShellApplication {
    name = "fio-wrapper";
    runtimeInputs = [ pkgs.fio ];
    text = ''
      set -eux

      OUT_DIR=/var/spool/fio/"$(date +%Y%m%d-%H%M%S-%N)"
      mkdir -p "$OUT_DIR"

      # We'll record the version of the system, to be as hermetic as possible,
      # bail if there have been configuration changes since the last reboot.
      if [ "$(readlink /run/current-system)" != "$(readlink /run/booted-system)" ]; then
        echo "current-system not the same as booted-system, not capturing system data"
      else
        cp /etc/os-release "$OUT_DIR"/etc_os-release
        nixos-version --json > "$OUT_DIR"/nixos-version.json
      fi

      exec ${pkgs.fio}/bin/fio --name=randread \
        --rw=randread --size=64M --blocksize=4K --directory=/tmp \
        --output="$OUT_DIR"/fio_output.json --output-format=json+
    '';
  };
in {
  environment.systemPackages = [ fio-wrapper-pkg ];

  # Run the benchmark on boot.
  systemd.services.fio = {
    wantedBy = [ "multi-user.target" ];
    # This doesn't currently depend on either of these conditions, but this is
    # just a dumb way to try and reduce interference from incomplete boot stuff.
    after = [ "network.target" "multi-user.target" ];
    description = "Run FIO benchmark";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${fio-wrapper-pkg}/bin/fio-wrapper";
    };
  };
}
