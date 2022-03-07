{
  dlib,
  lib,
}: {
  # the input format is specified in /specifications/translator-call-example.json
  # this script receives a json file including the input paths and specialArgs
  translateBin = {
    # dream2nix utils
    translators,
    utils,
    # nixpkgs dependenies
    bash,
    coreutils,
    jq,
    nodePackages,
    writeScriptBin,
    ...
  }:
    utils.writePureShellScript
    [
      bash
      coreutils
      jq
      nodePackages.npm
    ]
    ''
      # accroding to the spec, the translator reads the input from a json file
      jsonInput=$1

      # read the json input
      outputFile=$(jq '.outputFile' -c -r $jsonInput)
      source=$(jq '.source' -c -r $jsonInput)
      npmArgs=$(jq '.npmArgs' -c -r $jsonInput)

      cp -r $source/* ./
      chmod -R +w ./
      rm -rf package-lock.json

      if [ "$(jq '.noDev' -c -r $jsonInput)" == "true" ]; then
        echo "excluding dev dependencies"
        jq '.devDependencies = {}' ./package.json > package.json.mod
        mv package.json.mod package.json
        npm install --package-lock-only --production $npmArgs
      else
        npm install --package-lock-only $npmArgs
      fi

      jq ".source = \"$(pwd)\"" -c -r $jsonInput > $TMPDIR/newJsonInput

      cd $WORKDIR
      ${translators.translators.nodejs.pure.package-lock.translateBin} $TMPDIR/newJsonInput
    '';

  # inherit projectName function from package-lock translator
  projectName = dlib.translators.translators.nodejs.pure.package-lock.projectName;

  # This allows the framework to detect if the translator is compatible with the given input
  # to automatically select the right translator.
  compatible = {source}:
    dlib.containsMatchingFile [''.*package.json''] source;

  # inherit options from package-lock translator
  extraArgs =
    dlib.translators.translators.nodejs.pure.package-lock.extraArgs
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
