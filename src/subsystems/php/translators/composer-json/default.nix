{
  dlib,
  lib,
  ...
}: {
  type = "impure";

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
    moreutils,
    jq,
    phpPackages,
    ...
  }:
    utils.writePureShellScript
    [
      bash
      coreutils
      moreutils
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
      mv composer.json composer.json.orig

      jq \
        "(.config.lock = true) | \
         (.config.\"platform-check\" = false) | \
         (.authors = []) | \
         (.require = ((.require // {}) | with_entries(.key |= ascii_downcase))) | \
         (.\"require-dev\" = ((.\"require-dev\" // {}) | with_entries(.key |= ascii_downcase)))" \
        composer.json.orig > composer.json

      if [ "$(jq '.project.subsystemInfo.noDev' -c -r $jsonInput)" == "true" ]; then
        echo "excluding dev dependencies"
        jq \
          '.require-dev = {}' \
          composer.json | sponge composer.json
      fi
      composer update --ignore-platform-reqs --no-scripts --no-plugins --no-install

      jq ".source = \"$newSource\"" -c -r $jsonInput > $TMPDIR/newJsonInput
      popd
      ${subsystems.php.translators.composer-lock.translateBin} $TMPDIR/newJsonInput
    '';

  # inherit options from composer-lock translator
  extraArgs = dlib.translators.translators.php.composer-lock.extraArgs;
}
