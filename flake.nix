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
    { nixpkgs, ... }@inputs:
    let
      aarch64Pkgs = import inputs.nixpkgs {
        system = "aarch64-linux";
        config.allowUnfree = true;
      };

      ubootPkgs = {
        uboot-img = aarch64Pkgs.callPackage ./uboot.nix { };
      };

      module = import ./module.nix inputs;
    in
    {
      packages = {
        x86_64-linux = ubootPkgs;
        aarch64-linux = ubootPkgs;
      };

      nixosModules.default = module;

      nixosConfigurations.fajita = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          module
          {
            oneplus-fajita = {
              enable = true;
              user = "user";
            };
            users.users =
              let
                # Password: 123000
                pw = "$y$j9T$9GIlW.MlYdkM4dOqtXyoa1$2tUrrg2SJMJ4z92Hj7Xj7P48DvVeEtVqED9A5Sm44a5";
              in
              {
                root.hashedPassword = pw;
                user = {
                  isNormalUser = true;
                  hashedPassword = pw;
                };
              };
            networking.hostName = "fajita";
            services.openssh = {
              enable = true;
              settings.PermitRootLogin = "yes";
            };
            nix.channel.enable = false;
            system.stateVersion = "26.05";
          }
        ];
      };
    };
}
