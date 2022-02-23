{
  dlib,
  lib,
}:

{

  # the input format is specified in /specifications/translator-call-example.json
  # this script receives a json file including the input paths and specialArgs
  translateBin =
    {
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
        inputDirectory=$(jq '.inputDirectories | .[0]' -c -r $jsonInput)
        npmArgs=$(jq '.npmArgs' -c -r $jsonInput)
        # inputFiles=$(jq '.inputFiles | .[]' -c -r $jsonInput)

        cp -r $inputDirectory/* ./
        chmod -R +w ./
        rm -rf package-lock.json
        cat ./package.json

        if [ "$(jq '.noDev' -c -r $jsonInput)" == "true" ]; then
          echo "excluding dev dependencies"
          jq '.devDependencies = {}' ./package.json > package.json.mod
          mv package.json.mod package.json
          npm install --package-lock-only --production $npmArgs
        else
          npm install --package-lock-only $npmArgs
        fi

        cat package-lock.json

        jq ".inputDirectories[0] = \"$(pwd)\"" -c -r $jsonInput > ./newJsonInput

        ${translators.translators.nodejs.pure.package-lock.translateBin} $(realpath ./newJsonInput)
      '';


  # From a given list of paths, this function returns all paths which can be processed by this translator.
  # This allows the framework to detect if the translator is compatible with the given inputs
  # to automatically select the right translator.
  compatiblePaths =
    {
      inputDirectories,
      inputFiles,
    }@args:
    {
      inputDirectories = lib.filter
        (dlib.containsMatchingFile [ ''.*package.json'' ])
        args.inputDirectories;

      inputFiles = [];
    };

  # inherit options from package-lock translator
  extraArgs =
    let
      packageLockExtraArgs =
        (import ../../pure/package-lock { inherit dlib lib; }).extraArgs;
    in
      packageLockExtraArgs // {
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
