{utils, ...}: {
  inputs = [
    "path"
  ];

  outputs = {path, ...}: {
    calcHash = algo: utils.hashPath "${path}";

    fetched = hash: "${path}";
  };
}
