{ pkgs, ... }: {
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "fio-wrapper";
      runtimeInputs = [ pkgs.fio ];
      text = ''
        exec ${pkgs.fio}/bin/fio --name=randread --rw=randread --size=64M --blocksize=4K --directory=/tmp
      '';
    })
  ];
}
