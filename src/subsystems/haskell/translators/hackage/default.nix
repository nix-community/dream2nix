{
  dlib,
  lib,
  ...
}: let
  l = lib // builtins;
in {
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
    curl,
    gnutar,
    gzip,
    haskellPackages,
    jq,
    moreutils,
    nix,
    python3,
    writeScriptBin,
    ...
  }:
    utils.writePureShellScript
    [
      bash
      coreutils
      curl
      gnutar
      gzip
      haskellPackages.cabal-install
      haskellPackages.ghc
      jq
      moreutils
      nix
      python3
    ]
    ''
      # accroding to the spec, the translator reads the input from a json file
      jsonInput=$1

      # read the json input
      outputFile=$(realpath -m $(jq '.outputFile' -c -r $jsonInput))
      name=$(jq '.project.name' -c -r $jsonInput)
      version=$(jq '.project.version' -c -r $jsonInput)
      source=$(jq '.source' -c -r $jsonInput)
      relPath=$(jq '.project.relPath' -c -r $jsonInput)

      pushd $TMPDIR

      # download and unpack package source
      mkdir source
      curl -L https://hackage.haskell.org/package/$name-$version/$name-$version.tar.gz > $TMPDIR/tarball
      cd source
      cat $TMPDIR/tarball | tar xz --strip-components 1
      # trigger creation of `dist-newstyle` directory
      cabal update
      cabal freeze
      cd -

      # generate arguments for cabal-plan translator
      echo "{
        \"source\": \"$TMPDIR/source\",
        \"outputFile\": \"$outputFile\",
        \"project\": {
          \"relPath\": \"\",
          \"subsystemInfo\": {}
        }
      }" > $TMPDIR/newJsonInput

      popd

      # execute cabal-plan translator
      ${subsystems.haskell.translators.cabal-plan.translateBin} $TMPDIR/newJsonInput

      # finalize dream-lock. Add source and export default package
      # set correct package version under `packages`
      export version
      export hash=$(sha256sum $TMPDIR/tarball | cut -d " " -f 1)
      cat $outputFile \
        | python3 ${./fixup-dream-lock.py} $TMPDIR/sourceInfo.json \
        | sponge $outputFile

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
