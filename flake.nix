{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable"; # should always be overwritten by caller

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
    args = import self.inputs.args;

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

    inherit (original) lib checks htmlDocs nixosModules devShells; # no formatter

    # debug
    /*
       error = flakeLib.finalArgs {
      flake = self;
      defaultSystem = "x86-64_linux";
      extraArgs = {
        overlays =
          (import "${original}/pkgs/top-level/impure-overlays.nix")
          ++ [
            (_: prev: {
              lib = prev.lib.extend (import "${original}/lib/flake-version-info.nix" original);
            })
          ];
      };
    };
    inherit self;
    */
  };
}
