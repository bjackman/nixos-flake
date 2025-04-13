{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelPackages = pkgs.linuxPackages_custom {
      version = "6.14";
      src = pkgs.fetchgit {
        url = "https://github.com/torvalds/linux.git";
        rev = "v6.14";
        hash = "sha256-5Fkx6y9eEKuQVbDkYh3lxFQrXCK4QJkAZcIabj0q/YQ=";
      };
      configfile = ./qemu_config;
    };

    # Desperately trying to get the build to not fail because of missing
    # modules. I have deliberately disabled those modules to make the build
    # faster. But this doesn't work.
    initrd.availableKernelModules = [ ];
    initrd.kernelModules = [ ];
    kernelModules = [ ];
    extraModulePackages = [ ];
  };

  time.timeZone = "Europe/Zurich";
  i18n.defaultLocale = "en_US.UTF-8";

  users.users.brendan = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    packages = with pkgs; [
      tree
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINI/kH+QS+z6PrwR/MqRlbUklUowEZiDPwpyMa+6Kb9k jackmanb@jackmanb01"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMaakNfELyvjLLCRwH2U/yQ35HkEW+hEShAD7sn0mCmH brendan@chungito"
    ];
  };
  nix.settings.trusted-users = [ "root" "@wheel" "brendan" ];
  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    vim wget neofetch
  ];
  services.openssh.enable = true;
  networking.firewall.enable = false;

  virtualisation = {
    forwardPorts = [ { from = "host"; host.port = 2222; guest.port = 22; } ];
    graphics = false;
  };

  system.stateVersion = "24.11"; # DO NOT CHANGE IT! NEVER CHANGE IT!
}
