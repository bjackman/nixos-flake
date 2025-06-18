{ config, lib, pkgs, ... }:
{
  imports = [ ./aethelred-hardware-configuration.nix ];
  networking.hostName = "aethelred";

  virtualisation.vmVariant.virtualisation = {
    # Approximate actual size of Aethelred (`free -m`). This doesn't actually
    # result in the exact amount of RAM being available though, maybe because of
    # BIOS type changes.
    memorySize = 63817;
    cores = 12;  # This is presumably actually logical CPUs.
  };
}