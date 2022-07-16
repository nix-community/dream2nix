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
    # We need npm >= 8
    nodejs-18_x,
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
      nodejs-18_x
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

      # TODO: Do we really need to copy everything? Just package*.json is enough, no?
      cp -r $source/* ./
      chmod -R +w ./
      newSource=$(pwd)

      cd ./$relPath

      rm -f package-lock.json
      echo Generating temporary package-lock.json with npm

      npm install --package-lock-only $npmArgs

      jq ".source = \"$newSource\"" -c -r $jsonInput > $TMPDIR/newJsonInput

      cd $WORKDIR
      ${subsystems.nodejs.translators.resolved-json.translateBin} $TMPDIR/newJsonInput
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
