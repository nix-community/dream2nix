# copied from github:nix-community/flake-compat/pull/4/head
# + modified to fix laziness issue in defaultNix
# Compatibility function to allow flakes to be used by
# non-flake-enabled Nix versions. Given a source tree containing a
# 'flake.nix' and 'flake.lock' file, it fetches the flake inputs and
# calls the flake's 'outputs' function. It then returns an attrset
# containing 'defaultNix' (to be used in 'default.nix'), 'shellNix'
# (to be used in 'shell.nix').
{
  src,
  system ? builtins.currentSystem or "unknown-system",
}: let
  makeFlakeCompat = impureOverrides: let
    id = x: x;
    overrideWrap' = fn: set: set // {overrideInputs = ov: fn (makeFlakeCompat ov);};
    overrideWrap = overrideWrap' id;
    lockFilePath = src + "/flake.lock";

    lockFile = builtins.fromJSON (builtins.readFile lockFilePath);

    fetchTree = info:
      if info.type == "github"
      then {
        outPath =
          fetchTarball
          (
            {url = "https://api.${info.host or "github.com"}/repos/${info.owner}/${info.repo}/tarball/${info.rev}";}
            // (
              if info ? narHash
              then {sha256 = info.narHash;}
              else {}
            )
          );
        inherit (info) rev;
        shortRev = builtins.substring 0 7 info.rev;
        inherit (info) lastModified;
        lastModifiedDate = formatSecondsSinceEpoch info.lastModified;
        inherit (info) narHash;
      }
      else if info.type == "git"
      then
        {
          outPath =
            builtins.fetchGit
            (
              {
                inherit (info) url;
                shallow = true;
                allRefs = true;
              }
              // (
                if info ? rev
                then {inherit (info) rev;}
                else {}
              )
              // (
                if info ? submodules
                then {inherit (info) submodules;}
                else {}
              )
            );
          inherit (info) lastModified;
          lastModifiedDate = formatSecondsSinceEpoch info.lastModified;
          inherit (info) narHash;
        }
        // (
          if info ? rev
          then {
            inherit (info) rev;
            shortRev = builtins.substring 0 7 info.rev;
          }
          else {}
        )
      else if info.type == "path"
      then {
        outPath = builtins.path {
          path =
            if builtins.substring 0 1 info.path != "/"
            then src + ("/" + info.path)
            else info.path;
        };
        inherit (info) narHash;
      }
      else if info.type == "tarball"
      then {
        outPath =
          fetchTarball
          (
            {inherit (info) url;}
            // (
              if info ? narHash
              then {sha256 = info.narHash;}
              else {}
            )
          );
      }
      else if info.type == "gitlab"
      then {
        inherit (info) rev narHash lastModified;
        outPath =
          fetchTarball
          (
            {url = "https://${info.host or "gitlab.com"}/api/v4/projects/${info.owner}%2F${info.repo}/repository/archive.tar.gz?sha=${info.rev}";}
            // (
              if info ? narHash
              then {sha256 = info.narHash;}
              else {}
            )
          );
        shortRev = builtins.substring 0 7 info.rev;
      }
      else
        # FIXME: add Mercurial, tarball inputs.
        throw "flake input has unsupported input type '${info.type}'";

    callLocklessFlake = flakeSrc: let
      flake = import (flakeSrc + "/flake.nix");
      outputs = flakeSrc // (flake.outputs {self = outputs;});
    in
      outputs;

    rootSrc = let
      # Try to clean the source tree by using fetchGit, if this source
      # tree is a valid git repository.
      tryFetchGit = src:
        if isGit && !isShallow
        then let
          res = builtins.fetchGit src;
        in
          if res.rev == "0000000000000000000000000000000000000000"
          then removeAttrs res ["rev" "shortRev"]
          else res
        else {outPath = src;};
      # NB git worktrees have a file for .git, so we don't check the type of .git
      isGit = builtins.pathExists (src + "/.git");
      isShallow = builtins.pathExists (src + "/.git/shallow");
    in
      {
        lastModified = 0;
        lastModifiedDate = formatSecondsSinceEpoch 0;
      }
      // (
        if src ? outPath
        then src
        else tryFetchGit src
      );

    nameValuePair = name: value: {inherit name value;};
    mapAttrs' =
      # A function, given an attribute's name and value, returns a new `nameValuePair`.
      f:
      # Attribute set to map over.
      set:
        builtins.listToAttrs (map (attr: f attr set.${attr}) (builtins.attrNames set));

    # Format number of seconds in the Unix epoch as %Y%m%d%H%M%S.
    formatSecondsSinceEpoch = t: let
      rem = x: y: x - x / y * y;
      days = t / 86400;
      secondsInDay = rem t 86400;
      hours = secondsInDay / 3600;
      minutes = (rem secondsInDay 3600) / 60;
      seconds = rem t 60;

      # Courtesy of https://stackoverflow.com/a/32158604.
      z = days + 719468;
      era =
        (
          if z >= 0
          then z
          else z - 146096
        )
        / 146097;
      doe = z - era * 146097;
      yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
      y = yoe + era * 400;
      doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
      mp = (5 * doy + 2) / 153;
      d = doy - (153 * mp + 2) / 5 + 1;
      m =
        mp
        + (
          if mp < 10
          then 3
          else -9
        );
      y' =
        y
        + (
          if m <= 2
          then 1
          else 0
        );

      pad = s:
        if builtins.stringLength s < 2
        then "0" + s
        else s;
    in "${toString y'}${pad (toString m)}${pad (toString d)}${pad (toString hours)}${pad (toString minutes)}${pad (toString seconds)}";

    rootOverrides =
      mapAttrs'
      (input: lockKey': let
        lockKey =
          if builtins.isList lockKey'
          then builtins.concatStringsSep "/" lockKey'
          else lockKey';
      in
        nameValuePair lockKey (impureOverrides.${input} or null))
      lockFile.nodes.${lockFile.root}.inputs;

    allNodes =
      builtins.mapAttrs
      (
        key: node: let
          sourceInfo =
            if key == lockFile.root
            then rootSrc
            else if rootOverrides.${key} or null != null
            then {
              type = "path";
              outPath = rootOverrides.${key};
              narHash = throw "narHash unimplemented for impureOverride";
            }
            else fetchTree (node.info or {} // removeAttrs node.locked ["dir"]);

          subdir =
            if key == lockFile.root
            then ""
            else node.locked.dir or "";

          flake = import (sourceInfo
            + (
              if subdir != ""
              then "/"
              else ""
            )
            + subdir
            + "/flake.nix");

          inputs =
            builtins.mapAttrs
            (_inputName: inputSpec: allNodes.${resolveInput inputSpec})
            (node.inputs or {});

          # Resolve a input spec into a node name. An input spec is
          # either a node name, or a 'follows' path from the root
          # node.
          resolveInput = inputSpec:
            if builtins.isList inputSpec
            then getInputByPath lockFile.root inputSpec
            else inputSpec;

          # Follow an input path (e.g. ["dwarffs" "nixpkgs"]) from the
          # root node, returning the final node.
          getInputByPath = nodeName: path:
            if path == []
            then nodeName
            else
              getInputByPath
              # Since this could be a 'follows' input, call resolveInput.
              (resolveInput lockFile.nodes.${nodeName}.inputs.${builtins.head path})
              (builtins.tail path);

          outputs = flake.outputs (inputs // {self = result;});

          result =
            outputs
            // sourceInfo
            // {
              inherit inputs;
              inherit outputs;
              inherit sourceInfo;
              _type = "flake";
            };
        in
          if node.flake or true
          then assert builtins.isFunction flake.outputs; result
          else sourceInfo
      )
      lockFile.nodes;

    result =
      if !(builtins.pathExists lockFilePath)
      then callLocklessFlake rootSrc
      else if lockFile.version >= 5 && lockFile.version <= 7
      then allNodes.${lockFile.root}
      else throw "lock file '${lockFilePath}' has unsupported version ${toString lockFile.version}";
  in
    builtins.mapAttrs (key: attr: overrideWrap' (res: res.${key}) attr)
    {
      defaultNix =
        builtins.removeAttrs result ["__functor"];
    };
in
  makeFlakeCompat {}
