{ pkgs, ... }:
{
  # I don't really understand this, how to best set it for new installs is a
  # mystery to me.
  system.stateVersion = "24.11";

  boot = {
    loader.timeout = 2; # enspeeden tha boot

    tmp.useTmpfs = true;
  };
}
