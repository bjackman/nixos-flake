# Stuff for doing kernel development.
{ kernelPackages, kernelParams, pkgs, config, ... }:
{
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

  environment.systemPackages = [ pkgs.bpftrace ];

  # Make the kernel build tree visible in /run/booted-system/kernel-build.
  # Not sure if this is actually useful, there are no headers in there. But it's
  # interesting so dropping this code in while I have it.
  system.extraSystemBuilderCmds =
    let
      kernelDevPath = config.boot.kernelPackages.kernel.dev;
      kernelModDirVersion = config.boot.kernelPackages.kernel.modDirVersion;
      kernelBuildActualPath = "${kernelDevPath}/lib/modules/${kernelModDirVersion}/build";
    in ''
      ln -s "${kernelBuildActualPath}" $out/kernel-build
    '';
}