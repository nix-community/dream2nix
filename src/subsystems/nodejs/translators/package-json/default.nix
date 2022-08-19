{
  dlib,
  lib,
  ...
}: {
  type = "impure";

  # the input format is specified in /specifications/translator-call-example.json
  # this script receives a json file including the input paths and specialArgs
  translateBin = {
    # dream2nix utils
    subsystems,
    utils,
    # nixpkgs dependenies
    bash,
    coreutils,
    git,
    jq,
    nodePackages,
    openssh,
    writeScriptBin,
    ...
  }:
    utils.writePureShellScript
    [
      bash
      coreutils
      git
      jq
      nodePackages.npm
      openssh
    ]
    ''
      # according to the spec, the translator reads the input from a json file
      jsonInput=$1

      # read the json input
      outputFile=$(jq '.outputFile' -c -r $jsonInput)
      source=$(jq '.source' -c -r $jsonInput)
      relPath=$(jq '.project.relPath' -c -r $jsonInput)
      npmArgs=$(jq '.project.subsystemInfo.npmArgs' -c -r $jsonInput)

      # TODO: Do we really need to copy everything? Just package.json + .npmrc
      # is enough, no? And then pass the lock file to translate separately?
      cp -r $source/* ./
      chmod -R +w ./
      newSource=$(pwd)

      cd ./$relPath
      rm -rf package-lock.json yarn.lock

      echo "Translating with npm in temp dir: $(pwd)"
      echo "You can avoid this by adding your own package-lock.json file"

      if [ "$(jq '.project.subsystemInfo.noDev' -c -r $jsonInput)" == "true" ]; then
        echo "excluding dev dependencies"
        jq '.devDependencies = {}' ./package.json > package.json.mod
        mv package.json.mod package.json
        npm install --package-lock-only --omit=dev $npmArgs
      else
        npm install --package-lock-only $npmArgs
      fi

      jq ".source = \"$newSource\"" -c -r $jsonInput > $TMPDIR/newJsonInput

      cd $WORKDIR
      ${subsystems.nodejs.translators.package-lock-v2.translateBin} $TMPDIR/newJsonInput
    '';

  # inherit options from package-lock translator
  extraArgs =
    dlib.translators.translators.nodejs.package-lock.extraArgs
    // {
      npmArgs = {
        description = "Additional arguments for npm";
        type = "argument";
        default = "";
        examples = [
          "--force"
        ];
      };
    };
}
