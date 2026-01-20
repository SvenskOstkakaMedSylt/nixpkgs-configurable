rec {
  is-nixpkgs-configurable = true;

  chainFrom = flake: (
    if flake.outputs.flakeLib.is-nixpkgs-configurable or false # Note that  or false  is not a logical operation here
    then chainFrom flake.inputs.nixpkgs ++ [flake]
    else []
  );
  original = flake: (builtins.elemAt (chainFrom flake) 0).inputs.nixpkgs;

  finalArgs = {
    flake,
    extraArgs ? {},
    defaultSystem ? null,
  }: let
    argsList =
      builtins.concatMap (x:
        if x ? args
        then [x.args]
        else [])
      (chainFrom flake)
      ++ [extraArgs];
    overlays =
      builtins.concatMap (args: args.overlays or []) argsList;

    crossOverlays = builtins.concatMap (args: args.crossOverlays or []) argsList;

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
    )
    // (
      builtins.foldl' (x: y: x // y) {} (
        map (
          x: builtins.removeAttrs x ["config" "overlays" "crossOverlays"]
        )
        argsList
      )
    );

  rawPackages = parameters:
    import (original parameters.flake) (finalArgs parameters);
}
