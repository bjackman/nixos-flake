{ config, lib, pkgs, ... }:
{
  imports = [ ./aethelred-hardware-configuration.nix ];
  networking.hostName = "aethelred";
  environment.systemPackages = [ pkgs.phoronix-test-suite ];
}