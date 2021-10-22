{
  lib,

  # dream2nix
  callPackageDream,
  utils,
  ...
}:

let
  b = builtins;
  callFetcher = file: args: callPackageDream file args;
in

rec {

  fetchers = lib.genAttrs (utils.dirNames ./.) (name:
    callFetcher (./. + "/${name}") {}
  );

  defaultFetcher = callPackageDream ./default-fetcher.nix { inherit fetchers fetchSource; };
  
  combinedFetcher = callPackageDream ./combined-fetcher.nix { inherit defaultFetcher; };

  constructSource =
    {
      type,
      reComputeHash ? false,
      ...
    }@args:
    let
      fetcher = fetchers."${type}";
      namesKeep = fetcher.inputs ++ [ "version" "type" "hash" ];
      argsKeep = lib.filterAttrs (n: v: b.elem n namesKeep) args;
      fetcherOutputs = fetcher.outputs args;
    in
      argsKeep
      # if version was not provided, use the default version field
      // (lib.optionalAttrs (! args ? version) {
        version = args."${fetcher.versionField}";
      })
      # if the hash was not provided, calculate hash on the fly (impure)
      // (lib.optionalAttrs reComputeHash {
        hash = fetcherOutputs.calcHash "sha256";
      });

  # update source spec to different version
  updateSource =
    {
      source,
      newVersion,
      ...
    }:
    let
      fetcher = fetchers."${source.type}";
      argsKeep = b.removeAttrs source [ "hash" ];
    in
    constructSource (argsKeep // {
      version = newVersion;
      reComputeHash = true;
    } // {
      "${fetcher.versionField}" = newVersion;
    });

  # fetch a source defined via a dream lock source spec
  fetchSource = { source, extract ? false, }:
    let
      fetcher = fetchers."${source.type}";
      fetcherOutputs = fetcher.outputs source;
      maybeArchive = fetcherOutputs.fetched (source.hash or null);
    in
      if extract then
        utils.extractSource { source = maybeArchive; }
      else
        maybeArchive;

  # fetch a source define dby a shortcut
  fetchShortcut = { shortcut, extract ? false, }:
    fetchSource {
      source = translateShortcut { inherit shortcut; };
      inherit extract;
    };

  # translate shortcut to dream lock source spec
  translateShortcut = { shortcut, }:
    let

      checkArgs = fetcherName: args:
        let
          fetcher = fetchers."${fetcherName}";
          unknownArgNames = lib.filter (argName: ! lib.elem argName fetcher.inputs) (lib.attrNames args);
          missingArgNames = lib.filter (inputName: ! args ? "${inputName}") fetcher.inputs;
        in
          if lib.length unknownArgNames > 0 then
            throw "Received unknown arguments for fetcher '${fetcherName}': ${b.toString unknownArgNames}"
          else if lib.length missingArgNames > 0 then
            throw "Missing arguments for fetcher '${fetcherName}': ${b.toString missingArgNames}"
          else
            args;

      translateHttpUrl = 
        let
          fetcher = fetchers.fetchurl;
          fetcherOutputs = fetchers.http.outputs { url = shortcut; };
        in
          constructSource {
            type = "fetchurl";
            hash = fetcherOutputs.calcHash "sha256";
            url = shortcut;
          };

      translateGitShortcut =
        let
          urlAndParams = lib.elemAt (lib.splitString "+" shortcut) 1;
          splitUrlParams = lib.splitString "?" urlAndParams;
          url = lib.head splitUrlParams;
          params = lib.listToAttrs (lib.forEach (lib.tail splitUrlParams) (keyVal:
            let
              split = lib.splitString "=" keyVal;
              name = lib.elemAt split 0;
              value = lib.elemAt split 1;
            in
              lib.nameValuePair name value
          ));
          fetcher = fetchers.git;
          args = params // { inherit url; };
          fetcherOutputs = fetcher.outputs (checkArgs "git" args);
        in
          constructSource {
            type = "git";
            hash = fetcherOutputs.calcHash "sha256";
            inherit url;
          };
        
      translateRegularShortcut =
        let
          splitNameParams = lib.splitString ":" (lib.removeSuffix "/" shortcut);
          fetcherName = lib.elemAt splitNameParams 0;
          paramsStr = lib.elemAt splitNameParams 1;
          params = lib.splitString "/" paramsStr;
          
          fetcher = fetchers."${fetcherName}";
          args = lib.listToAttrs 
            (lib.forEach
              (lib.range 0 ((lib.length fetcher.inputs) - 1))
              (idx:
                lib.nameValuePair
                  (lib.elemAt fetcher.inputs idx)
                  (lib.elemAt params idx)
              ));
          fetcherOutputs = fetcher.outputs args;
        in
          if b.length params != b.length fetcher.inputs then
            throw ''
              Wrong number of arguments provided in shortcut for fetcher '${fetcherName}'
              Should be ${fetcherName}:${lib.concatStringsSep "/" fetcher.inputs}
            ''
          else
            constructSource (args // {
              type = fetcherName;
              hash = fetcherOutputs.calcHash "sha256";
            });
    in
      if lib.hasPrefix "git+" (lib.head (lib.splitString ":" shortcut)) then
        translateGitShortcut
      else if lib.hasPrefix "http://" shortcut || lib.hasPrefix  "https://" shortcut then
        translateHttpUrl
      else
        translateRegularShortcut;
    
}
