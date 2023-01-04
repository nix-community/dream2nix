{pkgs, ...}: {
  zlib = {
    add-deps = {
      buildInputs = old: old ++ [pkgs.zlib];
    };
  };
}
