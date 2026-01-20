WARNING: this is intended for personal use

# Example usage

## Old flake

```nix
{
    inputs = {
        nixpkgs.url = "nixpkgs";
        
        home-manager = {
            url = "home-manager";
            inputs.nixpkgs.follows = "nixpkgs";
        };
    };

    outputs = {nixpkgs, home-manager}: let
        system = "x86_64-linux";
        pkgs = import nixpkgs {
            config.allowUnfree = true;
            inherit system;
        };
    in ...;
}
```

## New flake

```nix
{
    inputs = {
        nixpkgs.url = "nixpkgs";

        nixpkgs-configurable = {
            url = "github:SvenskOstkakaMedSylt/nixpkgs-configurable";
            inputs = {
                args.url = ./args.nix;
                nixpkgs = "nixpkgs";
            };
        };

        home-manager = {
            url = "home-manager";
            inputs.nixpkgs.follows = "nixpkgs-configurable";
        };
    };

    outputs = {nixpkgs-configurable, home-manager, ...}: let
        system = "x86_64-linux";
        pkgs = nixpkgs-configurable.legacyPackages.${system};
    in ...;
}
```

with `./args.nix`:

```nix
{
    config.allowUnfree = true;
}
```

## What does this do

- Saves 1 nixpkgs invocation as home manager now uses the same nixpkgs import as
  the rest of the flake
- Allows the nixpkgs arguments to be overwritten by other flakes
- Allows arguments to be inherited from other such projects by taking their
  nixpkgs-configurable instance since they compose

## Features to be implemented

Configuration of the following parameters ( #TODO double check that this is the
case )

- stdEnvStages
- localsystem
- crossSystem
