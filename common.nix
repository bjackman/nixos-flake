{ config, lib, pkgs, modulesPath, ... }:

{
  nixpkgs = {
    # Configure ccache. I believe this is configuring something which nixpkgs
    # will set up as ccacheStdenv. You could configure this to be used for _all_
    # builds with:
    # config = { replaceStdenv = { pkgs }: pkgs.ccacheStdenv; };
    # But, that's a bad idea since you then lose the remote shared cache, plus
    # some builds seem to be incompatible with it and they fail.
    # How to actually apply the ccacheStdenv is a little confusing. See my notes
    # about figuring this out here:
    # https://discourse.nixos.org/t/help-using-ccache-for-kernel-build/63010
    # TODO: This will just fail the build if you haven't created
    # /var/cache/ccache or you haven't exposed it into the build sandbox by
    #   setting:
    #   extra-sandbox-paths = /var/cache/ccache
    #   in /etc/nix/nix.conf. Furthermore, the kernel build fails very
    #   confusingly because the wrapper script doesn't look like a C compiler at
    #   all if it's printing those messages, and kbuild doesn't print the
    #   messages. It should ideally be both fairly obvious, and also optional.
    # I cargo-culted this from:
    # https://github.com/linyinfeng/nixos-musl-example/blob/ad0973d37a4ed7c1f03d8988d1e0f946b39b5aa9/flake.nix#L12
    # config = { replaceStdenv = { pkgs }: pkgs.ccacheStdenv; };
    # TODO: It would probably be better to cargo-cult from the NixOS wiki
    # instead.
    overlays = [
      (final: prev: {
        ccacheWrapper = prev.ccacheWrapper.override {
          extraConfig = ''
            export CCACHE_COMPRESS=1
            export CCACHE_DIR="/var/cache/ccache"
            export CCACHE_UMASK=007
            if [ ! -d "$CCACHE_DIR" ]; then
              echo "====="
              echo "Directory '$CCACHE_DIR' does not exist"
              echo "Please create it with:"
              echo "  sudo mkdir -m0770 '$CCACHE_DIR'"
              echo "  sudo chown root:nixbld '$CCACHE_DIR'"
              echo "====="
              exit 1
            fi
            if [ ! -w "$CCACHE_DIR" ]; then
              echo "====="
              echo "Directory '$CCACHE_DIR' is not accessible for user $(whoami)"
              echo "Please verify its access permissions"
              echo "====="
              exit 1
            fi
          '';
        };
      })
    ];
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelPackages = pkgs.recurseIntoAttrs (pkgs.linuxPackagesFor
      (pkgs.buildLinux {
        version = "6.14";
        src = pkgs.fetchgit {
          url = "https://github.com/torvalds/linux.git";
          rev = "v6.14";
          hash = "sha256-5Fkx6y9eEKuQVbDkYh3lxFQrXCK4QJkAZcIabj0q/YQ=";
        };
        stdenv = pkgs.ccacheStdenv;
      }));
  };

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
