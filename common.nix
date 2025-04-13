{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    ./hardware-configuration.nix
    "${modulesPath}/virtualisation/qemu-vm.nix"
    ];

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelPackages = pkgs.linuxKernel.packages.linux_6_13;
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

