{ config, lib, pkgs, modulesPath, ... }:

{
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelPackages = pkgs.linuxPackages_custom {
      version = "6.14";
      # This vs nixpkgs.fetchgit?? No fucking idea. This one is documented,
      # fetchgit isn't really. And this doesn't seem to require you to
      # pointlessly specify a hash of the contents.
      src = builtins.fetchGit {
        url = "https://github.com/torvalds/linux.git";
        # url = "https://github.com/googleprodkernel/linux-kvm.git";
        # ref = "asi-rfcv2-preview";
        ref = "refs/tags/v6.14";
        rev = "38fec10eb60d687e30c8c6b5420d86e8149f7557";
        shallow = true;
      };
      # TODO: I wanna set stdenv = pkgs.ccacheStdenv. Ultimately the definition
      # of the thing we're using here does allow doing that (see
      # manual-config.nix in nixpkgs), but the wrapper functions
      # (linux-kernels.nix) don't directly export that. I suspect that the
      # callPackage mechanism will have some general way to override this, but
      # I'm a bit too tired to understand this:
      # https://nixos.org/guides/nix-pills/13-callpackage-design-pattern.html
      # Gemini 2.5 gave me something that sounds kiinda plausible, but looks
      # pretty ugly:
      # https://g.co/gemini/share/41cb753acfd9
      configfile = kconfigs/v6.14_nix_based.config;
    };
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

  environment.systemPackages = with pkgs; [ vim wget neofetch ];
  services.openssh.enable = true;
  networking.firewall.enable = false;

  system.stateVersion = "24.11"; # DO NOT CHANGE IT! NEVER CHANGE IT!
}
