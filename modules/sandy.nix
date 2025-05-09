{ modulesPath, ... }:
{
  imports = [ "${modulesPath}/installer/sd-card/sd-image-aarch64.nix" ];

  # Hmm, seems like cross-compilation is a bit of a mess, so here we just
  # assume that this will always be built on a proper american computer
  nixpkgs.buildPlatform = "x86_64-linux";
  nixpkgs.hostPlatform = "aarch64-linux";
  networking.hostName = "sandy";
}