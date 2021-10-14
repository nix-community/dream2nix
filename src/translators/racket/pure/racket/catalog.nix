{ runCommand, curl, cacert }:

{
  #TODO: This is sadly impure, getting around this by using wayback machine for now
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
}
