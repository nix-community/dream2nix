{
  lib,
  fetchurl,

  utils,
  ...
}:
{

  inputs = [
    "url"
  ];

  outputs = { url, ... }@inp: 
    let
      b = builtins;
    in
    {

      calcHash = algo: utils.hashPath algo (b.fetchurl {
        inherit url;
      });

      fetched = hash:
        if lib.stringLength hash == 40 then
          fetchurl {
            inherit url;
            sha1 = hash;
          }
        else
          fetchurl {
            inherit url hash;
          };

    };
}