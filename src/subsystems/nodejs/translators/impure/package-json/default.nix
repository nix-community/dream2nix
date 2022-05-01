{
  pkgs,
  config,
  dlib,
  lib,
  # translators,
  utils,
  specialArgs,
  ...
}: {
  type = "impure";

  # the input format is specified in /specifications/translator-call-example.json
  # this script receives a json file including the input paths and specialArgs
  translateBin =
    utils.writePureShellScript
    (with pkgs; [
      bash
      coreutils
      git
      jq
      nodePackages.npm
      openssh
    ])
    ''
      # accroding to the spec, the translator reads the input from a json file
      jsonInput=$1

      # read the json input
      outputFile=$(jq '.outputFile' -c -r $jsonInput)
      source=$(jq '.source' -c -r $jsonInput)
      relPath=$(jq '.project.relPath' -c -r $jsonInput)
      npmArgs=$(jq '.project.subsystemInfo.npmArgs' -c -r $jsonInput)

      cp -r $source/* ./
      chmod -R +w ./
      newSource=$(pwd)

      cd ./$relPath
      rm -rf package-lock.json

      if [ "$(jq '.project.subsystemInfo.noDev' -c -r $jsonInput)" == "true" ]; then
        echo "excluding dev dependencies"
        jq '.devDependencies = {}' ./package.json > package.json.mod
        mv package.json.mod package.json
        npm install --package-lock-only --production $npmArgs
      else
        npm install --package-lock-only $npmArgs
      fi

      jq ".source = \"$newSource\"" -c -r $jsonInput > $TMPDIR/newJsonInput

      cd $WORKDIR
      ${(lib.traceVal specialArgs.translators.nodejs.pure.package-lock).translateBin} $TMPDIR/newJsonInput
    '';

  # inherit options from package-lock translator
  extraArgs =
    # translators.nodejs.pure.package-lock.extraArgs
    # // {
    {
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
