# Module to provide an interface for integrating derivation builder functions
#   like for example, mkDerivation, buildPythonPackage, etc...
{
  config,
  extendModules,
  lib,
  ...
}: let
  l = lib // builtins;

  rawPackage = config.package-func.result;

  # outputs needed to assemble a package as proposed in
  #   https://github.com/NixOS/nix/issues/6507
  outputs = l.unique config.package-func.outputs;

  outputDrvs =
    l.genAttrs outputs
    (output: rawPackage.${output});

  outputPaths = l.mapAttrs (_: drv: "${drv}") outputDrvs;

  outputDrvsContexts =
    l.mapAttrsToList (output: path: l.attrNames (l.getContext path)) outputPaths;

  isSingleDrvPackage = (l.length (l.unique outputDrvsContexts)) == 1;

  nonSingleDrvWarning = ''
    The package ${config.name} consists of multiple outputs that are built by distinct derivations.
    The first output declared in the package's outputs or the default output is used as the top-level output of the package.

    If the package has not explicitly specified an output, prefer directly referencing one of its output attributes:
      - .${l.concatStringsSep "\n  - ." outputs}
  '';

  warnIfMultiDrvOr = returnVal:
    if isSingleDrvPackage
    then returnVal
    else l.warn nonSingleDrvWarning returnVal;

  defaultOutput = l.getFirstOutput outputs rawPackage;

  public =
    # out, lib, bin, etc...
    outputDrvs
    # outputs, drvPath
    // {
      inherit outputs;
      inherit config extendModules;
      drvPath = warnIfMultiDrvOr defaultOutput.drvPath;
      outPath = warnIfMultiDrvOr defaultOutput.outPath;
      outputName = warnIfMultiDrvOr defaultOutput.outputName;
      type = "derivation";
    };
in {
  imports = [
    ./interface.nix
    ../core/public
  ];
  # the final derivation
  config.public = public;
  config.package-func.result =
    config.package-func.func config.package-func.args;
}
