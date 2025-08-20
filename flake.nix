{
  inputs = {
    nixpkgs.url = "nixpkgs";

    args = {
      flake = false;
      url = ./args.nix;
    };
  };

  outputs = inputs: let
    chainFrom = flake: (
      if flake ? inputs.nixpkgs
      then chainFrom flake.inputs.nixpkgs ++ [flake]
      else []
    );
    chain = chainFrom inputs.self;
    original = (builtins.elemAt chain 0).inputs.nixpkgs;

    inherit (original) lib;
    forEachSystem = lib.genAttrs lib.systems.flakeExposed;

    finalArgs = {
      extraArgs ? [],
      defaultSystem ? null,
    }: let
      argsList = map (x: x.args) chain ++ [extraArgs];
      overlays =
        builtins.concatMap (args: args.overlays or []) argsList;

      crossOverlays = builtins.concatMap (args: args.crossOverLays or []) argsList;

      configModules = builtins.concatMap (args:
        if args ? config
        then [args.config]
        else [])
      argsList;
      moduleAmount = builtins.length configModules;
    in
      (
        if defaultSystem == null
        then {}
        else {system = defaultSystem;}
      )
      // (
        if moduleAmount == 0
        then {}
        else {
          config =
            if moduleAmount == 1
            then builtins.elemAt configModules 0
            else {
              imports = configModules;
            };
        }
      )
      // (
        if builtins.length overlays == 0
        then {}
        else {inherit overlays;}
      )
      // (
        if builtins.length crossOverlays == 0
        then {}
        else {inherit crossOverlays;}
      );
  in {
    staticSelf = forEachSystem ( # this whole horrible hack is only needed becayse the flake registry does not support the input attribute, and is therefore only used as the path of this flake in the local flake registry
      system:
        derivation {
          name = "source";
          inherit system;
          builder = "${inputs.self.outputs.legacyPackages.${system}.nushell}/bin/nu";
          args = [./builder.nu];

          flake = builtins.readFile ./flake.nix;
          default = builtins.readFile ./default.nix;
          build = builtins.readFile ./builder.nu;

          lock = let
            generateLock = flake: {
              type = "path";
              path = flake.sourceInfo.outPath;
              lastModified = 0;
              inherit (flake.sourceInfo) narHash;
            };

            generateNixpkgsNode = index: {
              name = "nixpkgs_${index + 1}";
              value = {
                original = {
                  type = "indirect";
                  id = "nixpkgs";
                };

                locked = generateLock (builtins.elemAt chain index);

                inputs = {
                  nixpkgs = "nixpkgs_${index}";
                  args = "args_${index + 1}";
                };
              };
            };

            generateArgsNode = index: {
              name = "args_${index + 1}";
              value = {
                flake = false;

                original = {
                  type = "path";
                  path = "args.nix";
                };

                locked = generateLock (builtins.elemAt chain index).inputs.args;
              };
            };
          in
            builtins.toJSON {
              version = 7;
              root = "root";
              nodes =
                {
                  root.inputs = {
                    nixpkgs = "nixpkgs_${builtins.length chain}";
                    args = "args";
                  };

                  nixpkgs_0 = {
                    original = {
                      type = "indirect";
                      id = "nixpkgs";
                    };

                    locked = generateLock original;
                  };
                }
                // (builtins.listToAttrs (builtins.genList generateNixpkgsNode (builtins.length chain)))
                // (builtins.listToAttrs (builtins.genList generateArgsNode (builtins.length chain)));
            };
        }
    );

    rawPackages = parameters: import original (finalArgs parameters);

    legacyPackages = forEachSystem (system:
      inputs.self.outputs.rawPackages {
        defaultSystem = system;
        extraArgs = {
          overlays =
            (import "${original}/pkgs/top-level/impure-overlays.nix")
            ++ [
              (_: prev: {
                lib = prev.lib.extend (import "${original}/lib/flake-version-info.nix");
              })
            ];
        };
      });

    lib = lib.extend (final: _: {
      nixosSystem = args:
        import "${original}/nixos/lib/eval-config.nix" {
          lib = final;
          system = null;

          modules =
            args.modules
            ++ [
              ({
                lib,
                config,
                ...
              }: {
                nixpkgs.flake.source = inputs.self.outPath;

                nix.registry.nixpkgs.to = lib.mkOverride 1001 {
                  type = "path";
                  path = inputs.self.outputs.staticSelf.${config.nixpkgs.hostPlatform}.sourceInfo.outPath; # dummy
                };
              })
            ];
        }
        // builtins.removeAttrs args ["modules"];
    });
  };
}
