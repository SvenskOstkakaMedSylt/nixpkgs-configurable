{parameters ? {}, ...} @ args:
(import ./lib.nix).rawPackages ({
    extraArgs = builtins.removeAttrs ["parameters"] args;
  }
  // {flake = builtins.getFlake "${./.}";}
  // parameters)
