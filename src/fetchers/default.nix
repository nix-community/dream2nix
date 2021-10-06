{
  callPackageDream,
  lib,

  utils,
  # config
  allowBuiltinFetchers,
  ...
}:

let
  b = builtins;
  callFetcher = file: args: callPackageDream file ({
    inherit allowBuiltinFetchers;
  } // args);
in

rec {

  fetchers = lib.genAttrs (utils.dirNames ./.) (name:
    callFetcher (./. + "/${name}") {}
  );

  defaultFetcher = callPackageDream ./default-fetcher.nix { inherit fetchers fetchSource; };
  
  combinedFetcher = callPackageDream ./combined-fetcher.nix { inherit defaultFetcher; };

  fetchSource = { source, }:
    let
      fetcher = fetchers."${source.type}";
      fetcherOutputs = fetcher.outputs source;
    in
      fetcherOutputs.fetched (source.hash or null);
  
  fetchShortcut = { shortcut, }:
    fetchSource { source = translateShortcut { inherit shortcut; }; };

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
          {
            type = "fetchurl";
            hash = fetcherOutputs.calcHash "sha256";
            url = shortcut;
            versionField = fetcher.versionField;
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
          {
            type = "git";
            hash = fetcherOutputs.calcHash "sha256";
            inherit url;
            versionField = fetcher.versionField;
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
            args // {
              type = fetcherName;
              hash = fetcherOutputs.calcHash "sha256";
              versionField = fetcher.versionField;
            };
    in
      if lib.hasPrefix "git+" (lib.head (lib.splitString ":" shortcut)) then
        translateGitShortcut
      else if lib.hasPrefix "http://" shortcut || lib.hasPrefix  "https://" shortcut then
        translateHttpUrl
      else
        translateRegularShortcut;
}
