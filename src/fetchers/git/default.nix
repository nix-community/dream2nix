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

  outputs = { url, ref ? null, rev ? null, ... }@inp: 
    if ref == null && rev == null then
      throw "At least 'rev' or 'ref' must be specified for fetcher 'git'"
    else if rev != null && ! (builtins.match "[a-f0-9]*" rev) then
      throw "Argument 'rev' for fetcher git must be a sha1 hash. Try using 'ref' instead"
    else if ref != null && b.match "refs/(heads|tags)/.*" ref == null then
      throw ''ref must be of format "refs/heads/branch-name" or "refs/tags/tag-name"''
    else
    let
      b = builtins;
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
              { inherit url;} // refAndRev
            )
        else
          fetchgit {
            inherit url;
            rev = if rev != null then rev else ref;
            sha256 = hash;
          };
    };
}