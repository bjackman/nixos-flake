{ config, lib, pkgs, ... }:
{
  imports = [ ./aethelred-hardware-configuration.nix ];
  networking.hostName = "aethelred";
  services.tailscale.enable = true;
}