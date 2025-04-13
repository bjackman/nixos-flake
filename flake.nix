{
  inputs = {
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-24.11"; };
  };

  outputs = inputs: {
    nixosConfigurations = {
      # A configuration that looks kinda just like a plain default NixOS host.
      base = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./common.nix ];
        specialArgs = { inherit inputs; };
      };
      # Configuration intended for the big chungus in the office on my desk-area-network.
      # Whether this approach of combining separate modules instead of using
      # options to a single shared module is a good one... I have no idea.
      aethelred = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./common.nix ./aethlered.nix ];
        specialArgs = { inherit inputs; };
      };
    };
  };
}