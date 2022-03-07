# this fetcher takes an attrset of sources and combines all contained FODs
# to one large FOD. Non-FOD sources like derivations and store paths are
# not touched
{
  bash,
  async,
  coreutils,
  lib,
  nix,
  stdenv,
  writeScript,
  # dream2nix
  defaultFetcher,
  utils,
  ...
}: {
  # sources attrset from dream lock
  sources,
  sourcesAggregatedHash,
  ...
} @ args: let
  b = builtins;

  # resolve to individual fetcher calls
  defaultFetched = (defaultFetcher args).fetchedSources;

  # extract the arguments from the individual fetcher calls
  FODArgsAll = let
    FODArgsAll' =
      lib.mapAttrs
      (
        name: versions:
          lib.mapAttrs
          (version: fetched:
            # handle FOD sources
              if
                lib.all
                (attr: fetched ? "${attr}")
                ["outputHash" "outputHashAlgo" "outputHashMode"]
              then
                (fetched.overrideAttrs (args: {
                  passthru.originalArgs = args;
                }))
                .originalArgs
                // {
                  outPath = let
                    sanitizedName = utils.sanitizeDerivationName name;
                  in "${sanitizedName}/${version}/${fetched.name}";
                }
              # handle path sources
              else if lib.isString fetched
              then "ignore"
              # handle store path sources
              else if lib.isStorePath fetched
              then "ignore"
              # handle unknown sources
              else if fetched == "unknown"
              then "ignore"
              # error out on unknown source types
              else
                throw ''
                  Error while generating FOD fetcher for combined sources.
                  Cannot classify source of ${name}#${version}.
                '')
          versions
      )
      defaultFetched;
  in
    lib.filterAttrs
    (name: versions: versions != {})
    (lib.mapAttrs
      (name: versions:
        lib.filterAttrs
        (version: fetcherArgs: fetcherArgs != "ignore")
        versions)
      FODArgsAll');

  FODArgsAllList =
    lib.flatten
    (lib.mapAttrsToList
      (name: versions:
        b.attrValues versions)
      FODArgsAll);

  # convert arbitrary types to string, like nix does with derivation arguments
  toString' = x:
    if lib.isBool x
    then
      if x
      then "1"
      else ""
    else if lib.isList x
    then ''"${lib.concatStringsSep " " (lib.forEach x (y: toString' y))}"''
    else if x == null
    then ""
    else b.toJSON x;

  # set up nix build env for signle item
  setupEnvForItem = fetcherArgs: ''

    # export arguments for builder
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (argName: argVal: ''
        export ${argName}=${
          lib.replaceStrings ["$" ''\n''] [''\$'' "\n"] (toString' argVal)
        }
      '')
      fetcherArgs)}

    # run builder
    bash ${fetcherArgs.builder}
  '';

  mkScriptForItem = fetcherArgs: ''
    # configure $out
    OUT_ORIG=$out
    export out=$OUT_ORIG/${fetcherArgs.outPath}
    mkdir -p $(dirname $out)

    # set up TMP and TMPDIR
    workdir=$(mktemp -d)
    TMP=$workdir/TMP
    TMPDIR=$TMP
    mkdir -p $TMP

    # do the work
    pushd $workdir
    ${setupEnvForItem fetcherArgs}
    popd
    rm -r $workdir
  '';

  # builder which wraps several other FOD builders
  # and executes these after each other inside a single build
  builder = writeScript "multi-source-fetcher" ''
    #!${bash}/bin/bash
    export PATH=${coreutils}/bin:${bash}/bin

    mkdir $out

    S="/$TMP/async_socket"
    async=${async}/bin/async
    $async -s="$S" server --start -j40

    ${lib.concatStringsSep "\n"
      (b.map
        (fetcherArgs: ''
          $async -s="$S" cmd -- bash -c '${mkScriptForItem fetcherArgs}'
        '')
        FODArgsAllList)}

    $async -s="$S" wait

    echo "FOD_HASH=$(${nix}/bin/nix hash path $out)"
  '';

  FODAllSources = let
    nativeBuildInputs' =
      lib.unique
      (lib.foldl (a: b: a ++ b) []
        (b.map
          (fetcherArgs: (fetcherArgs.nativeBuildInputs or []))
          FODArgsAllList));
  in
    stdenv.mkDerivation rec {
      name = "sources-combined";
      inherit builder;
      nativeBuildInputs =
        nativeBuildInputs'
        ++ [
          coreutils
        ];
      outputHashAlgo = "sha256";
      outputHashMode = "recursive";
      outputHash = sourcesAggregatedHash;
    };
in {
  FOD = FODAllSources;

  fetchedSources =
    lib.mapAttrs
    (name: versions:
      lib.mapAttrs
      (version: source:
        if FODArgsAll ? "${name}"."${version}"
        then "${FODAllSources}/${FODArgsAll."${name}"."${version}".outPath}"
        else defaultFetched."${name}"."${version}")
      versions)
    sources;
}
