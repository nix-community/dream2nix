{...}: {
  inputs = [
    "path"
  ];

  outputs = {utils, ...}: {path, ...} @ inp: let
    b = builtins;
  in {
    calcHash = algo: utils.hashPath "${path}";

    fetched = hash: "${path}";
  };
}
