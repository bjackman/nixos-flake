{ pkgs, ... }:
{
  # I don't really understand this, how to best set it for new installs is a
  # mystery to me.
  system.stateVersion = "24.11";

  boot = {
    loader.timeout = 2; # enspeeden tha boot

    tmp.useTmpfs = true;
  };

  virtualisation.vmVariant.virtualisation = {
    # Approximate actual size of Aethelred (`free -m`). This doesn't actually
    # result in the exact amount of RAM being available though, maybe because of
    # BIOS type changes.
    memorySize = 63817;
    cores = 12;  # This is presumably actually logical CPUs.
  };
}
