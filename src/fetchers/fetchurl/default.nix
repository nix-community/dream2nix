{
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
        fetchurl {
          inherit url hash;
        };

    };
}