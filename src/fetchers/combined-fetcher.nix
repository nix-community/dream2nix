# this fetcher takes an attrset of sources and combines all contained FODs
# to one large FOD. Non-FOD sources like derivations and store paths are
# not touched
{
  defaultFetcher,

  bash,
  coreutils,
  lib,
  nix,
  stdenv,
  writeScript,
  ...
}:
{
  # sources attrset from generic lock
  sources,
  sourcesCombinedHash,
}:
let

  # resolve to individual fetcher calls
  defaultFetched = (defaultFetcher { inherit sources; }).fetchedSources;

  # extract the arguments from the individual fetcher calls
  fetcherArgsAll =
    let
      fetcherArgsAll' =
        lib.mapAttrs
          (pname: fetched:

            # handle FOD sources
            if lib.all (attr: fetched ? "${attr}") [ "outputHash" "outputHashAlgo" "outputHashMode" ] then
              (fetched.overrideAttrs (args: {
                passthru.originalArgs = args;
              })).originalArgs

            # handle non-FOD sources
            else if lib.isDerivation fetched || lib.isStorePath fetched then
              null

            # error out on unknown source types
            else
              throw ''
                Error while generating FOD fetcher for combined sources.
                Cannot classify source of '${pname}'.
                Known source types:
                  - FOD
                  - derivation
                  - store path
              ''
          )
          defaultFetched;
    in
      lib.filterAttrs (pname: fetcherArgs: fetcherArgs != null) fetcherArgsAll';

  # convert arbitrary types to string, like nix does with derivation arguments
  toString = x:
    if lib.isBool x then
      if x then
        "1"
      else
        ""
    else if lib.isList x then
      builtins.toString (lib.forEach x (y: toString y))
    else if x == null then
      ""
    else
      builtins.toJSON x;

  # generate script to fetch single item
  fetchItem = pname: fetcherArgs: ''

    # export arguments for builder
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (argName: argVal: ''
      export ${argName}=${toString argVal}
    '') fetcherArgs)}

    # run builder
    bash ${fetcherArgs.builder}
  '';

  # builder which wraps several other FOD builders
  # and executes these after each other inside a single build
  # TODO: for some reason PATH is unset and we don't have access to the stdenv tools
  builder = writeScript "multi-source-fetcher" ''
    #!${bash}/bin/bash
    export PATH=${coreutils}/bin:${bash}/bin

    mkdir $out

    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (pname: fetcherArgs:
      ''
        OUT_ORIG=$out
        export out=$OUT_ORIG/${fetcherArgs.name}
        mkdir workdir
        pushd workdir
        ${fetchItem pname fetcherArgs}
        popd
        rm -r workdir
        export out=$OUT_ORIG
      '') fetcherArgsAll )}

    echo "FOD_PATH=$(${nix}/bin/nix hash-path $out)"
  '';

  FODAllSources = 
    let
      nativeBuildInputs' = lib.foldl (a: b: a ++ b) [] (
        lib.mapAttrsToList
          (pname: fetcherArgs: (fetcherArgs.nativeBuildInputs or []))
          fetcherArgsAll
      );
    in
      stdenv.mkDerivation rec {
        name = "sources-combined";
        inherit builder;
        nativeBuildInputs = nativeBuildInputs' ++ [
          coreutils
        ];
        outputHashAlgo = "sha256";
        outputHashMode = "recursive";
        outputHash = sourcesCombinedHash;
      };

in

{
  FOD = FODAllSources;
  fetchedSources =
    # attrset: pname -> path of downloaded source
    lib.genAttrs (lib.attrNames sources) (pname:
      if fetcherArgsAll ? "${pname}" then
        "${FODAllSources}/${fetcherArgsAll."${pname}".name}"
      else
        sources."${pname}"
    );
}
