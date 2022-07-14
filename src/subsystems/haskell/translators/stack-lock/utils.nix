{
  lib,
  dlib,
  pkgs,
}: let
  l = lib // builtins;

  flakeCompat = import (builtins.fetchTarball {
    url = "https://github.com/edolstra/flake-compat/tarball/b4a34015c698c7793d592d66adbab377907a2be8";
    sha256 = "1qc703yg0babixi6wshn5wm2kgl5y1drcswgszh4xxzbrwkk9sv7";
  });
in rec {
  all-cabal-hashes = pkgs.runCommandLocal "all-cabal-hashes" {} ''
    mkdir $out
    cd $out
    tar --strip-components 1 -xf ${pkgs.all-cabal-hashes}
  '';

  # The cabal2json program
  cabal2json = pkgs.haskell.packages.ghc8107.cabal2json;

  # parse cabal file via IFD
  fromCabal = file: name: let
    file' = l.path {path = file;};
    jsonFile = pkgs.runCommandLocal "${name}.cabal.json" {} ''
      ${cabal2json}/bin/cabal2json ${file'} > $out
    '';
  in
    l.fromJSON (l.readFile jsonFile);

  # fromYaml IFD implementation
  fromYaml = file: let
    file' = l.path {path = file;};
    jsonFile = pkgs.runCommandLocal "yaml.json" {} ''
      ${pkgs.yaml2json}/bin/yaml2json < ${file'} > $out
    '';
  in
    l.fromJSON (l.readFile jsonFile);

  # converts all cabal files for a given list of candidates to json files
  batchCabal2Json = candidates: let
    candidatesJsonStr = l.toJSON candidates;
    convertOne = name: version: ''
      cabalFile=${all-cabal-hashes}/${name}/${version}/${name}.cabal
      if [ -e $cabalFile ]; then
        echo "converting cabal to json: ${name}-${version}"
        mkdir -p $out/${name}/${version}
        ${cabal2json}/bin/cabal2json \
          $cabalFile \
          > $out/${name}/${version}/cabal.json
      else
        echo "all-cabal-hashes" seems to be outdated
        exit 1
      fi
    '';
  in
    pkgs.runCommandLocal "cabal-json-files" {}
    (l.concatStringsSep "\n"
      (l.map (c: convertOne c.name c.version) candidates));

  /*
  Converts all cabal files for a given list of candiates to an attrset.
  access like: ${name}.${version}.${some_cabal_attr}
  */
  batchCabalData = candidates: let
    batchJson = batchCabal2Json candidates;
  in
    l.mapAttrs
    (name: _:
      l.mapAttrs
      (version: _: l.fromJSON (l.readFile "${batchJson}/${name}/${version}/cabal.json"))
      (l.readDir "${batchJson}/${name}"))
    (l.readDir batchJson);
}
