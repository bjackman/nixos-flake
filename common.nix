{ config, lib, pkgs, modulesPath, kernelPackages, kernelParams, ... }:
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

  time.timeZone = "Europe/Zurich";
  i18n.defaultLocale = "en_US.UTF-8";

  users.users.brendan = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    packages = with pkgs; [ tree ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINI/kH+QS+z6PrwR/MqRlbUklUowEZiDPwpyMa+6Kb9k jackmanb@jackmanb01"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMaakNfELyvjLLCRwH2U/yQ35HkEW+hEShAD7sn0mCmH brendan@chungito"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDLVpV3PnFV5AW4G0aizNgoVu0Wtn3A3arUEJHaEsxy3iFgvvENBcYb+I00HRnYV4FZX1EGD0Fh6lIJcm9YUCm2EKkv9V/mMfV5xaiKcKGZYOLLpaIZw8J3tsuc+iIrl/8Qk1++l6pYIgOCpAgRAY1MxSD/Syg7rZMKiIH2/3CAzzjQej3SCf0Wc2I2/Sv1YUUhNxKGkMi7P4lG8R2erRG8DuPsglEhHW0ua3Hkygy3lfBO9j32JdOXB6+xswWOljiUwnVMt4AbBrZPxn/29BlS/olEgdfxt+jBNM33h9ofKwM+h5oGXomNedgr9qQVha4xj+dbqD7YB/lB/9HMjd1X jackmanb@jackmanb.zrh.corp.google.com"
    ];
  };
  nix.settings.trusted-users = [ "root" "@wheel" "brendan" ];
  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [ vim ];
  services.openssh.enable = true;
  networking.firewall.enable = false;

  system.stateVersion = "24.11"; # DO NOT CHANGE IT! NEVER CHANGE IT!
}
