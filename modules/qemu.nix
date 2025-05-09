{ modulesPath, ... }:
{
  imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];

  virtualisation = {
    forwardPorts = [{
      from = "host";
      host.port = 2222;
      guest.port = 22;
    }];
    graphics = false;
  };
}
