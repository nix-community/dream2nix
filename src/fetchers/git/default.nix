{
  fetchgit,
  lib,
  utils,
  ...
}: let
  b = builtins;
in {
  inputs = [
    "url"
    "rev"
  ];

  versionField = "rev";

  outputs = {
    url,
    rev,
    ...
  } @ inp:
    if b.match "refs/(heads|tags)/.*" rev == null && builtins.match "[a-f0-9]*" rev == null
    then throw ''rev must either be a sha1 revision or "refs/heads/branch-name" or "refs/tags/tag-name"''
    else let
      b = builtins;

      refAndRev =
        if b.match "refs/(heads|tags)/.*" inp.rev != null
        then {ref = inp.rev;}
        else {rev = inp.rev;};
    in {
      calcHash = algo:
        utils.hashPath algo
        (b.fetchGit
          (refAndRev
            // {
              inherit url;
              allRefs = true;
              submodules = true;
            }));

      # git can either be verified via revision or hash.
      # In case revision is used for verification, `hash` will be null.
      fetched = hash:
        if hash == null
        then
          if ! refAndRev ? rev
          then throw "Cannot fetch git repo without integrity. Specify at least 'rev' or 'sha256'"
          else
            b.fetchGit
            (refAndRev
              // {
                inherit url;
                allRefs = true;
                submodules = true;
              })
        else
          fetchgit
          (refAndRev
            // {
              inherit url;
              fetchSubmodules = true;
              sha256 = hash;
            });
    };
}
