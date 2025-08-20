{parameters ? {}, ...} @ args:
(builtins.getFlake "${./.}").outputs.rawPackages ({
    extraArgs = builtins.removeAttrs ["parameters"] args;
  }
  // parameters)
