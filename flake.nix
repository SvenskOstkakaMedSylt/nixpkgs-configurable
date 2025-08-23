{
  inputs = {
    nixpkgs.url = "nixpkgs";

    args = {
      flake = false;
      url = ./args.nix;
    };
  };

  outputs = {self, ...}: let
    flakeLib = import ./lib.nix;

    original = flakeLib.original self;
    rawPackages = parameters:
      flakeLib.rawPackages ({
          flake = self;
        }
        // parameters);

    inherit (original) lib;
    forEachSystem = lib.genAttrs lib.systems.flakeExposed;
  in {
    inherit flakeLib;

    legacyPackages = forEachSystem (system:
      rawPackages {
        defaultSystem = system;
        extraArgs = {
          overlays =
            (import "${original}/pkgs/top-level/impure-overlays.nix")
            ++ [
              (_: prev: {
                lib = prev.lib.extend (import "${original}/lib/flake-version-info.nix" original);
              })
            ];
        };
      });

    inherit lib;
  };
}
