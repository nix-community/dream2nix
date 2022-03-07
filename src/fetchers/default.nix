{
  lib,
  # dream2nix
  callPackageDream,
  utils,
  ...
}: let
  b = builtins;
  callFetcher = file: args: callPackageDream file args;
in rec {
  fetchers = lib.genAttrs (utils.dirNames ./.) (
    name:
      callFetcher (./. + "/${name}") {}
  );

  defaultFetcher = callPackageDream ./default-fetcher.nix {inherit fetchers fetchSource;};

  combinedFetcher = callPackageDream ./combined-fetcher.nix {inherit defaultFetcher;};

  constructSource = {
    type,
    reComputeHash ? false,
    ...
  } @ args: let
    fetcher = fetchers."${type}";
    argsKeep = b.removeAttrs args ["reComputeHash"];
    fetcherOutputs =
      fetcher.outputs
      (b.removeAttrs argsKeep ["dir" "hash" "type"]);
  in
    argsKeep
    # if the hash was not provided, calculate hash on the fly (impure)
    // (lib.optionalAttrs reComputeHash {
      hash = fetcherOutputs.calcHash "sha256";
    });

  # update source spec to different version
  updateSource = {
    source,
    newVersion,
    ...
  }:
    constructSource (source
      // {
        reComputeHash = true;
      }
      // {
        "${fetchers."${source.type}".versionField}" = newVersion;
      });

  # fetch a source defined via a dream lock source spec
  fetchSource = {
    source,
    extract ? false,
  }: let
    fetcher = fetchers."${source.type}";
    fetcherArgs = b.removeAttrs source ["dir" "hash" "type"];
    fetcherOutputs = fetcher.outputs fetcherArgs;
    maybeArchive = fetcherOutputs.fetched (source.hash or null);
  in
    if source ? dir
    then "${maybeArchive}/${source.dir}"
    else maybeArchive;

  # fetch a source defined by a shortcut
  fetchShortcut = {
    shortcut,
    extract ? false,
  }:
    fetchSource {
      source = translateShortcut {inherit shortcut;};
      inherit extract;
    };

  parseShortcut = shortcut: let
    # in: "git+https://foo.com/bar?kwarg1=lol&kwarg2=hello"
    # out: [ "git+" "git" "https" "//" "foo.com/bar" "?kwarg1=lol&kwarg2=hello" "kwarg1=lol&kwarg2=hello" ]
    split =
      b.match
      ''(([[:alnum:]]+)\+)?([[:alnum:]-]+):(//)?([^\?]*)(\?(.*))?''
      shortcut;

    parsed = {
      proto1 = b.elemAt split 1;
      proto2 = b.elemAt split 2;
      path = b.elemAt split 4;
      allArgs = b.elemAt split 6;
      kwargs = b.removeAttrs kwargs_ ["dir"];
      dir = kwargs_.dir or null;
    };

    kwargs_ =
      if parsed.allArgs == null
      then {}
      else
        lib.listToAttrs
        (map
          (kwarg: let
            split = lib.splitString "=" kwarg;
          in
            lib.nameValuePair
            (b.elemAt split 0)
            (b.elemAt split 1))
          (lib.splitString "&" parsed.allArgs));
  in
    if split == null
    then throw "Unable to parse shortcut: ${shortcut}"
    else parsed;

  renderUrlArgs = kwargs: let
    asStr =
      lib.concatStringsSep
      "&"
      (lib.mapAttrsToList
        (name: val: "${name}=${val}")
        kwargs);
  in
    if asStr == ""
    then ""
    else "?" + asStr;

  # translate shortcut to dream lock source spec
  translateShortcut = {
    shortcut,
    computeHash ? true,
  }: let
    parsed = parseShortcut shortcut;

    checkArgs = fetcherName: args: let
      fetcher = fetchers."${fetcherName}";
      unknownArgNames = lib.filter (argName: ! lib.elem argName fetcher.inputs) (lib.attrNames args);
      missingArgNames = lib.filter (inputName: ! args ? "${inputName}") fetcher.inputs;
    in
      if lib.length unknownArgNames > 0
      then throw "Received unknown arguments for fetcher '${fetcherName}': ${b.toString unknownArgNames}"
      else if lib.length missingArgNames > 0
      then throw "Missing arguments for fetcher '${fetcherName}': ${b.toString missingArgNames}"
      else args;

    translateHttpUrl = let
      fetcher = fetchers.http;

      urlArgsFinal = renderUrlArgs parsed.kwargs;

      url = with parsed; "${proto2}://${path}${urlArgsFinal}";

      fetcherOutputs = fetchers.http.outputs {
        inherit url;
      };
    in
      constructSource
      {
        inherit url;
        type = "http";
      }
      // (lib.optionalAttrs (parsed.dir != null) {
        dir = parsed.dir;
      })
      // (lib.optionalAttrs computeHash {
        hash = fetcherOutputs.calcHash "sha256";
      });

    translateProtoShortcut = let
      kwargsUrl = b.removeAttrs parsed.kwargs fetcher.inputs;

      urlArgs = renderUrlArgs kwargsUrl;

      url = with parsed; "${proto2}://${path}${urlArgs}";

      fetcherName = parsed.proto1;

      fetcher = fetchers."${fetcherName}";

      args = parsed.kwargs // {inherit url;};

      fetcherOutputs = fetcher.outputs (checkArgs fetcherName args);
    in
      constructSource
      (parsed.kwargs
        // {
          type = fetcherName;
          inherit url;
        }
        // (lib.optionalAttrs (parsed.dir != null) {
          dir = parsed.dir;
        })
        // (lib.optionalAttrs computeHash {
          hash = fetcherOutputs.calcHash "sha256";
        }));

    translateRegularShortcut = let
      fetcherName = parsed.proto2;

      path = lib.removeSuffix "/" parsed.path;

      params = lib.splitString "/" path;

      fetcher = fetchers."${fetcherName}";

      args =
        if fetcher ? parseParams
        then fetcher.parseParams params
        else if b.length params != b.length fetcher.inputs
        then
          throw ''
            Wrong number of arguments provided in shortcut for fetcher '${fetcherName}'
            Should be ${fetcherName}:${lib.concatStringsSep "/" fetcher.inputs}
          ''
        else
          lib.listToAttrs
          (lib.forEach
            (lib.range 0 ((lib.length fetcher.inputs) - 1))
            (
              idx:
                lib.nameValuePair
                (lib.elemAt fetcher.inputs idx)
                (lib.elemAt params idx)
            ));

      fetcherOutputs = fetcher.outputs (args // parsed.kwargs);
    in
      constructSource (args
        // parsed.kwargs
        // {
          type = fetcherName;
        }
        // (lib.optionalAttrs (parsed.dir != null) {
          dir = parsed.dir;
        })
        // (lib.optionalAttrs computeHash {
          hash = fetcherOutputs.calcHash "sha256";
        }));
  in
    if parsed.proto1 != null
    then translateProtoShortcut
    else if
      lib.hasPrefix "http://" shortcut
      || lib.hasPrefix "https://" shortcut
    then translateHttpUrl
    else translateRegularShortcut;
}
