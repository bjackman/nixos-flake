{ pkgs, ... }:
let
  fio-wrapper-pkg = pkgs.writeShellApplication {
    name = "fio-wrapper";
    runtimeInputs = [ pkgs.fio ];
    text = ''
      mkdir -p /var/spool/fio/
      exec ${pkgs.fio}/bin/fio --name=randread \
        --rw=randread --size=64M --blocksize=4K --directory=/tmp \
        --output=/var/spool/fio/"$(date +%Y%m%d-%H%M%S-%N)".json --output-format=json+
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
