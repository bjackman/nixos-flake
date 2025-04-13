{ config, lib, pkgs, ... }:
{
  imports = [ ./aethelred-hardware-configuration.nix ];
  networking = {
    hostName = "aethelred";
    interfaces.eno2.useDHCP = true;
    interfaces.eno1.ipv4.addresses = [{
      address = "192.168.2.3";
      prefixLength = 24;
    }];
  };
}