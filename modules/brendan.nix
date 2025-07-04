{ modulesPath, pkgs, ... }:
{
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
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDMi2QRJG+/nM2ekysSUT6h1uNlSmo31ubSK28DrGVezoh2MaPXz6XWMpJtDvr9FHHOVpsCTFxFQ9A7DTqgFy0NxwTHJhK5bevxaWYRkv43H8EMR9pJXYMDAtj7Gk+NNK5ssGZm2P+cTl9r5QZOm0PaVUUeoA/KxbVCNEenOCHM5Lv2RrXGufJL1ukRL6I83fl3ilfgEOz2RBG3QQGahVqYfZq/mfo07U0vad9RX7y6I+8Ap8XSCe33yfO0338yPf0A69p90xtpiJyYyAtVN+0KT552wpMtPjprXt5mrpYDLZvW6vBu0mFGkmDoz3ekb+MmWJVlE9f1VyjHpmA1bRn18gQ73egrGlVWvPHpAJ3gl5bKtc30Md/M4u3tyauDoAnqOs/FAqvClDz1Yav+5Ck5umnDSXXWH/WToX9AUsevjLQq1uB2QJU6oYeEIpEHWC4dUtgPXrX/SYDSGmqA5xOqboyn39oIcNWXTOrqnes52bBlOW3/zCX51EIx/tiG3LU= brendan@brendan-thinkpad"
    ];
  };

  nix = {
    settings.trusted-users = [ "root" "@wheel" "brendan" ];
    settings.experimental-features = [ "nix-command" "flakes" ];
  };

  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [ vim file ];
  services.openssh.enable = true;
  networking.firewall.enable = false;

  virtualisation.vmVariant.virtualisation = {
    forwardPorts = [{
      from = "host";
      host.port = 2222;
      guest.port = 22;
    }];
    graphics = false;
    # This BIOS doesn't mess up the terminal and is apparently faster.
    qemu.options = [ "-bios" "qboot.rom" ];
  };
}

