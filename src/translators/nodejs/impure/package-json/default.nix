{
  # dream2nix utils
  translators,
  utils,

  # nixpkgs dependenies
  bash,
  coreutils,
  jq,
  lib,
  nodePackages,
  writeScriptBin,
  ...
}:

{

  # the input format is specified in /specifications/translator-call-example.json
  # this script receives a json file including the input paths and specialArgs
  translateBin = utils.writePureShellScript
    [ bash coreutils jq nodePackages.npm ]
    ''
      # accroding to the spec, the translator reads the input from a json file
      jsonInput=$1

      # read the json input
      outputFile=$(jq '.outputFile' -c -r $jsonInput)
      inputDirectory=$(jq '.inputDirectories | .[0]' -c -r $jsonInput)
      # inputFiles=$(jq '.inputFiles | .[]' -c -r $jsonInput)

      cp -r $inputDirectory/* ./
      chmod -R +w ./
      cat ./package.json
      npm install --package-lock-only
      cat package-lock.json

      jq ".inputDirectories[0] = \"$(pwd)\"" -c -r $jsonInput > ./newJsonInput
      
      ${translators.translators.nodejs.pure.package-lock.translateBin}/bin/run $(realpath ./newJsonInput)
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
      # TODO: insert regex here that matches valid input file names
      # examples:
      #   - ''.*requirements.*\.txt''
      #   - ''.*package-lock\.json''
      inputDirectories = lib.filter 
        (utils.containsMatchingFile [ ''.*package.json'' ])
        args.inputDirectories;
      
      inputFiles = [];
    };


  # If the translator requires additional arguments, specify them here.
  # There are only two types of arguments:
  #   - string argument (type = "argument")
  #   - boolean flag (type = "flag")
  # String arguments contain a default value and examples. Flags do not.
  extraArgs = {

    # # Example: boolean option
    # # Flags always default to 'false' if not specified by the user
    # dev-dependenices = {
    #   description = "Include dev dependencies";
    #   type = "flag";
    # };

    # # Example: string option
    # the-answer = {
    #   default = "42";
    #   description = "The Answer to the Ultimate Question of Life";
    #   examples = [
    #     "0"
    #     "1234"
    #   ];
    #   type = "argument";
    # };

  };
}
