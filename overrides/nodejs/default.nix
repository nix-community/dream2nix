{
  lib,
  pkgs,
}:

let
  b = builtins;
in

{
  degit = {
    run-build = {
      installScript = ''
        npm run build
        cp help.md ./dist
      '';
    };
  };

  esbuild = {
    "add-binary-0.12.17" = {
      _condition = pkg: pkg.version == "0.12.17";
      ESBUILD_BINARY_PATH =
        let
          esbuild = pkgs.buildGoModule rec {
            pname = "esbuild";
            version = "0.12.17";

            src = pkgs.fetchFromGitHub {
              owner = "evanw";
              repo = "esbuild";
              rev = "v${version}";
              sha256 = "sha256-wZOBjNOgGmwIQNCrhzwGPmI/fW/yZiDqq8l4oSDTvZs=";
            };

            vendorSha256 = "sha256-2ABWPqhK2Cf4ipQH7XvRrd+ZscJhYPc3SV2cGT0apdg=";
          };
        in
          "${esbuild}/bin/esbuild";
    };
  };

  geckodriver = {
    add-binary = {
      GECKODRIVER_FILEPATH = "${pkgs.geckodriver}/bin/geckodriver";
    };
  };

  gifsicle = {
    add-binary = {
      installScript = ''
        ln -s ${pkgs.gifsicle}/bin/gifsicle ./vendor/gifsicle
        npm run postinstall
      '';
    };
  };

  mozjpeg = {
    add-binary = {
      installScript = ''
        ln -s ${pkgs.mozjpeg}/bin/cjpeg ./vendor/cjpeg
        npm run postinstall
      '';
    };
  };

  optipng-bin = {
    add-binary = {
      installScript = ''
        ln -s ${pkgs.optipng}/bin/optipng ./vendor/optipng
        npm run postinstall
      '';
    };
  };

  pngquant-bin = {
    add-binary = {
      installScript = ''
        ln -s ${pkgs.pngquant}/bin/pngquant ./vendor/pngquant
        npm run postinstall
      '';
    };
  };

  webpack = {
    remove-webpack-cli-check = {
      _condition = pkg: pkg.version == "5.41.1";
      ignoreScripts = false;
      patches = [
        ./webpack/remove-webpack-cli-check.patch
      ];
    };
  };

  webpack-cli = {
    remove-webpack-check = {
      _condition = pkg: pkg.version == "4.7.2";
      ignoreScripts = false;
      patches = [
        ./webpack-cli/remove-webpack-check.patch
      ];
    };
  };

  "@mattermost/webapp" = {
    run-webpack = {
      installScript = ''
        NODE_ENV=production node --max-old-space-size=8192 ./node_modules/webpack/bin/webpack.js
      '';
    };
  };

}
