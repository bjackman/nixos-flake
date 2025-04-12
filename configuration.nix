{ config, lib, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelPackages = pkgs.linuxKernel.packages.linux_6_13;
  };

  networking = {
    hostName = "aethelred";
    interfaces.eno2.useDHCP = true;
    interfaces.eno1.ipv4.addresses = [{
      address = "192.168.2.3";
      prefixLength = 24;
    }];
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
    ];
  };
  nix.settings.trustedUsers = [ "root" "@wheel" "brendan" ];
  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    vim wget neofetch
  ];
  services.openssh.enable = true;
  networking.firewall.enable = false;

  system.stateVersion = "24.11"; # DO NOT CHANGE IT! NEVER CHANGE IT!
}

