{ runCommand, writeTextFile, curl, cacert, parser }:
let
  # TODO: This is sadly impure, getting around this by using wayback machine for now
  # Would a way around this be to cache these changes ourselves in a better way than i am doing here?
  # eg Have a github action that checks for changes to this file and caches it in dream to Nix with a date tag?
  # or should this be converted into a impure translator...
  rawCatalog = runCommand "fetch-racket-package-index" {
    outputHash = "+U8FvM5Sf8QNJdH/L1V4L8nS49NAFZZxK0fnFRuLC/E=";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    buildInputs = [ curl ];
    SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
  } ''
      curl https://web.archive.org/web/20211013170533/https://pkgs.racket-lang.org/pkgs-all --output $out
    '';

  parsedCatalog = builtins.toJSON (parser.parseRacketCatalog rawCatalog);
  version = builtins.substring 0 6 rawCatalog.outputHash;

in
  # TODO: Version 2.0 of this translator could make use of a parser not written in Nix
  # that would be faster and could be used directly in the rawCatalog runCommand
  # REVIEW: Is it possible to set up a cachix that DreamToNix uses for this file?
  # At the moment it is being copied directly into the repo
  # The other alternative would be to automate the update of this file in dream2nix via
  # github actions or some other alternative
  writeTextFile {
    name = "racket-packages-catalog#${version}";
    text = "${parsedCatalog}";
}
