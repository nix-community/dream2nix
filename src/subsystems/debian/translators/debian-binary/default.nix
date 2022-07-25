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
  discoverProject = tree:
  # Example
  # Returns true if given directory contains a file ending with .cabal
    l.any # is this working?
    
    (filename: l.hasSuffix "deb-spec" filename)
    (l.attrNames tree.files);

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
    utils,
    # nixpkgs dependenies
    bash,
    coreutils,
    jq,
    writeScriptBin,
    nix,
    callPackage,
    python3,
    ...
  }:
    utils.writePureShellScript
    [
      bash
      coreutils
      jq
      nix
      (callPackage ./aptdream {})
      python3
    ]
    ''
      # accroding to the spec, the translator reads the input from a json file
      jsonInput=$1

      # read the json input
      export outputFile=$WORKDIR/$(jq '.outputFile' -c -r $jsonInput)
      source=$(jq '.source' -c -r $jsonInput)
      relPath=$(jq '.project.relPath' -c -r $jsonInput)

      pkgsName=$(cat $source/deb-spec)

      mkdir ./state
      touch ./status
      mkdir ./download

      mkdir -p ./etc/apt
      echo "deb http://deb.debian.org/debian bullseye main" >> ./etc/apt/sources.list

      apt -o Acquire::AllowInsecureRepositories=1 \
      -o Dir::State::status=./status \
      -o Dir::Etc=./etc/apt \
      -o Dir::State=./state \
      update

      apt -o Acquire::AllowInsecureRepositories=1 \
      -o Dir::State::status=./status \
      -o Dir::Etc=./etc/apt \
      -o Dir::State=./state \
      install $pkgsName --print-uris > ./deb-uris

      apt -o Acquire::AllowInsecureRepositories=1 \
      -o Dir::State::status=./status \
      -o Dir::Etc=./etc/apt \
      -o Dir::Cache=./download \
      -o Dir::State=./state \
      install $pkgsName --download-only -y --allow-unauthenticated

      # cat ./deb-uris
      # ls ./download/archives
      ls ./download
      ls ./download/archives

      # TODO:
      # read input files/dirs and produce a json file at $outputFile
      # containing the dream lock similar to /src/specifications/dream-lock-example.json

      # # generate the dream lock from the downloaded list of files
      export NAME=$pkgsName
      python3 ${./generate_dream_lock.py}
    '';

  # If the translator requires additional arguments, specify them here.
  # When users run the CLI, they will be asked to specify these arguments.
  # There are only two types of arguments:
  #   - string argument (type = "argument")
  #   - boolean flag (type = "flag")
  # String arguments contain a default value and examples. Flags do not.
  extraArgs = {
    # Example: boolean option
    # Flags always default to 'false' if not specified by the user
    noDev = {
      description = "Exclude dev dependencies";
      type = "flag";
    };

    # Example: string option
    theAnswer = {
      default = "42";
      description = "The Answer to the Ultimate Question of Life";
      examples = [
        "0"
        "1234"
      ];
      type = "argument";
    };
  };
}
