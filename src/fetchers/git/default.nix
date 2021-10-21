{
  fetchgit,
  lib,

  utils,
  # config
  allowBuiltinFetchers,
  ...
}:
let
  b = builtins;
in
{

  inputs = [
    "url"
    "rev"
  ];

  versionField = "rev";

  outputs = { url, rev, ... }@inp:
    if b.match "refs/(heads|tags)/.*" rev == null && builtins.match "[a-f0-9]*" rev == null then
      throw ''rev must either be a sha1 revision or "refs/heads/branch-name" or "refs/tags/tag-name"''
    else
    let

      b = builtins;

      ref =
        if b.match "refs/(heads|tags)/.*" inp.rev != null then
          inp.rev
        else
          null;

      rev =
        if b.match "refs/(heads|tags)/.*" inp.rev != null then
          null
        else
          inp.rev;
  
      refAndRev =
        (lib.optionalAttrs (ref != null) {
          inherit ref;
        })
        //
        (lib.optionalAttrs (rev != null) {
          inherit rev;
        });

    in
    {

      calcHash = algo: utils.hashPath algo (b.fetchGit
        ({ inherit url; } // refAndRev)
      );

      fetched = hash:
        if hash == null then
          if rev == null then
            throw "Cannot fetch git repo without integrity. Specify at least 'rev' or 'sha256'"
          else
            b.fetchGit (
              { inherit url; allRefs = true; } // refAndRev
            )
        else
          fetchgit {
            inherit url;
            rev = if rev != null then rev else ref;
            sha256 = hash;
          };
    };
}