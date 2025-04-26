# Stuff for doing kernel development.
{ kernelPackages, kernelParams, ... }:
{
  imports = [ ./fio.nix ];
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    inherit kernelPackages;
    inherit kernelParams;
    # Desperately trying to get the build to not fail because of missing
    # modules. I have deliberately disabled those modules to make the build
    # faster. But this doesn't work.
    initrd = {
      availableKernelModules = [ ];
      kernelModules = [ ];
      includeDefaultModules = false;
    };
  };
  hardware.enableAllHardware = false;
}