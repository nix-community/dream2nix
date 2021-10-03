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

  fetchSource = source:
    let
      fetcher = fetchers."${source.type}";
      fetcherOutputs = fetcher.outputs source;
    in
      fetcherOutputs.fetched (source.hash or null);

  fetchViaShortcut = shortcut:
    let

      fetchViaHttpUrl = 
        let
          fetcher = fetchers.fetchurl;
          fetcherOutputs = fetchers.http.outputs { url = shortcut; };
        in
          rec {
            hash = fetcherOutputs.calcHash "sha256";
            fetched = fetcherOutputs.fetched hash;
          };

      fetchViaGitShortcut =
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
          fetcherOutputs = fetcher.outputs args;
        in
          rec {
            hash = fetcherOutputs.calcHash "sha256";
            fetched = fetcherOutputs.fetched hash;
          };
        
      fetchViaRegularShortcut =
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
            rec {
              hash = fetcherOutputs.calcHash "sha256";
              fetched = fetcherOutputs.fetched hash;
            };
    in
      if lib.hasPrefix "git+" (lib.head (lib.splitString ":" shortcut)) then
        fetchViaGitShortcut
      else if lib.hasPrefix "http://" shortcut || lib.hasPrefix  "https://" shortcut then
        fetchViaHttpUrl
      else
        fetchViaRegularShortcut;
}
