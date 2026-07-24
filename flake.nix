{
  description = "Vanilla NixOS on OnePlus 6T (fajita)";

  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/569d578509928497eddc3fdbf94a799027050be4";
    };
    impermanence = {
      url = "github:nix-community/impermanence/7b1d382faf603b6d264f58627330f9faa5cba149";
    };
  };

  outputs =
    inputs:
    let
      inherit (inputs.nixpkgs) lib;

      aarch64Pkgs = import inputs.nixpkgs {
        system = "aarch64-linux";
        config.allowUnfree = true;
      };

      ubootPkgs = {
        uboot-img = aarch64Pkgs.callPackage ./uboot.nix { };
      };
    in
    {
      packages = {
        x86_64-linux = ubootPkgs;
        aarch64-linux = ubootPkgs;
      };

      nixosModules.default = import ./module.nix inputs;
    };
}
