{ runCommand, writeTextFile, curl, cacert, parser }:
let
  # TODO: This is sadly impure, getting around this by using wayback machine for now
  # Would a way around this be to cache these changes ourselves in a better way than i am doing here?
  # eg Have a github action that checks for changes to this file and caches it in dream to Nix with a date tag?
  # or should this be converted into a impure translator...
  pkgCatalog = runCommand "fetch-racket-package-index" {
    outputHash = "lFfsZLNJnhzXmgTbkWmz0o66RGagb+rD18B2/zpASbw=";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    buildInputs = [ curl ];
    SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
  } ''
      curl https://web.archive.org/web/20211013170533/https://pkgs.racket-lang.org/pkgs-all --output download
      sed 's|\\"||g' <download >$out
    '';

  catalog = builtins.toJSON (parser.parseRacketCatalog pkgCatalog);
  version = builtins.subString 0 6 pkgCatalog.outputHash;

in
  # TODO: Version 2.0 of this translator could make use of a parser not written in Nix
  # that would be faster and could be used directly in the pkgCatalog runCommand
  writeTextFile {
    name = "racket-packages-catalog#${version}";
    text = "${catalog}";
}
