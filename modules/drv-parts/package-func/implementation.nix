# Module to provide an interface for integrating derivation builder functions
#   like for example, mkDerivation, buildPythonPackage, etc...
{
  config,
  lib,
  extendModules,
  ...
}: let
  l = lib // builtins;
  t = l.types;

  # outputs needed to assemble a package as proposed in
  #   https://github.com/NixOS/nix/issues/6507
  outputs = l.unique config.package-func.outputs;

  outputDrvs =
    l.genAttrs outputs
    (output: config.package-func.result.${output});

  outputPaths = l.mapAttrs (_: drv: "${drv}") outputDrvs;

  outputDrvsContexts =
    l.mapAttrsToList (output: path: l.attrNames (l.getContext path)) outputPaths;

  isSingleDrvPackage = (l.length (l.unique outputDrvsContexts)) == 1;

  nonSingleDrvError = ''
    The package ${config.name} consists of multiple outputs that are built by distinct derivations. It can't be understood as a single derivation.
    This problem is causes by referencing the package directly. Instead, reference one of its output attributes:
      - .${l.concatStringsSep "\n  - ." outputs}
  '';

  throwIfMultiDrvOr = returnVal:
    if isSingleDrvPackage
    then returnVal
    else throw nonSingleDrvError;

  public =
    # out, lib, bin, etc...
    outputDrvs
    # outputs, drvPath
    // {
      inherit outputs;
      inherit config extendModules;
      drvPath = throwIfMultiDrvOr outputDrvs.out.drvPath;
      outPath = throwIfMultiDrvOr outputDrvs.out.outPath;
      outputName = throwIfMultiDrvOr outputDrvs.out.outputName;
      type = "derivation";
    };
in {
  # add an option for each output, eg. out, bin, lib, etc...
  options.public = l.genAttrs outputs (output:
    l.mkOption {
      type = t.path;
    });

  # the final derivation
  config.public = public;
}
