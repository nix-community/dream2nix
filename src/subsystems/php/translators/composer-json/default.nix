{
  dlib,
  lib,
  ...
}: let
  l = lib // builtins;
in {
  type = "impure";

  /*
  Allow dream2nix to detect if a given directory contains a project
  which can be translated with this translator.
  Usually this can be done by checking for the existence of specific
  file names or file endings.

  Alternatively a fully featured discoverer can be implemented under
  `src/subsystems/{subsystem}/discoverers`.
  This is recommended if more complex project structures need to be
  discovered like, for example, workspace projects spanning over multiple
  sub-directories

  If a fully featured discoverer exists, do not define `discoverProject`.
  */
  discoverProject = tree: (l.pathExists "${tree.fullPath}/composer.json");

  # A derivation which outputs a single executable at `$out`.
  # The executable will be called by dream2nix for translation
  # The input format is specified in /specifications/translator-call-example.json.
  # The first arg `$1` will be a json file containing the input parameters
  # like defined in /src/specifications/translator-call-example.json and the
  # additional arguments required according to extraArgs
  #
  # The program is expected to create a file at the location specified
  # by the input parameter `outFile`.
  # The output file must contain the dream lock data encoded as json.
  # See /src/specifications/dream-lock-example.json
  translateBin = {
    # dream2nix utils
    subsystems,
    utils,
    # nixpkgs dependenies
    bash,
    coreutils,
    jq,
    phpPackages,
    writeScriptBin,
    ...
  }:
    utils.writePureShellScript
    [
      bash
      coreutils
      jq
      phpPackages.composer
    ]
    ''
      # accroding to the spec, the translator reads the input from a json file
      jsonInput=$1

      # read the json input
      outputFile=$(realpath -m $(jq '.outputFile' -c -r $jsonInput))
      source=$(jq '.source' -c -r $jsonInput)
      relPath=$(jq '.project.relPath' -c -r $jsonInput)

      pushd $TMPDIR
      cp -r $source/* ./
      chmod -R +w ./
      newSource=$(pwd)

      cd ./$relPath
      rm -f composer.lock

      echo "translating in temp dir: $(pwd)"

      # create lockfile
      if [ "$(jq '.project.subsystemInfo.noDev' -c -r $jsonInput)" == "true" ]; then
        echo "excluding dev dependencies"
        jq '.require-dev = {}' ./composer.json > composer.json.mod
        mv composer.json.mod composer.json
        composer update --no-install --no-dev
      else
        composer update --no-install
      fi

      jq ".source = \"$newSource\"" -c -r $jsonInput > $TMPDIR/newJsonInput

      popd
      ${subsystems.php.translators.composer-lock.translateBin} $TMPDIR/newJsonInput
    '';

  # inherit options from composer-lock translator
  extraArgs = dlib.translators.translators.php.composer-lock.extraArgs;
}
