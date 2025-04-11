{
  inputs = {
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-24.11"; };
  };

  outputs = inputs: {
    nixosConfigurations = {
      nixos = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./configuration.nix ];
        specialArgs = { inherit inputs; };
      };
    };
  };
}