{
  pkgs,
  utils,
  translators,
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
  translateBin =
    utils.writePureShellScript
    (with pkgs; [
      bash
      coreutils
      haskellPackages.cabal-install
      haskellPackages.ghc
      jq
      moreutils
      nix
      python3
      util-linux
    ])
    ''
      # accroding to the spec, the translator reads the input from a json file
      jsonInput=$1

      # read the json input
      outputFile=$(realpath -m $(jq '.outputFile' -c -r $jsonInput))
      name=$(jq '.project.name' -c -r $jsonInput)
      version=$(jq '.project.version' -c -r $jsonInput)
      source=$(jq '.source' -c -r $jsonInput)
      relPath=$(jq '.project.relPath' -c -r $jsonInput)

      # update the cabal index if older than 1 day
      (
        flock 9 || exit 1
        # ... commands executed under lock ...
        cabalIndex="$HOME/.cabal/packages/hackage.haskell.org/01-index.cache"
        set -x
        if [ -e "$cabalIndex" ]; then
          indexTime=$(stat -c '%Y' "$cabalIndex")
          age=$(( $(date +%s) - $indexTime ))
          if [ "$age" -gt "$((60*60*24))" ]; then
            cabal update
          fi
        else
          cabal update
        fi
      ) 9>/tmp/cabal-lock

      pushd $TMPDIR

      # copy source
      echo "copying source"
      cp -drT --no-preserve=mode,ownership "$source" source

      cd source
      # trigger creation of `dist-newstyle` directory
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
      ${translators.cabal-plan.finalTranslateBin} $TMPDIR/newJsonInput

      # finalize dream-lock. Add source and export default package
      # set correct package version under `packages`
      export source
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
  };
}
