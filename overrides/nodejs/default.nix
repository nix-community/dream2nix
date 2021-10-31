{
  lib,
  pkgs,
}:

let
  b = builtins;
in

{

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
      installScript = ''
        patch ./bin/webpack.js < ${./webpack/remove-webpack-cli-check.patch}
      '';
    };
  };

  webpack-cli = {
    remove-webpack-check = {
      _condition = pkg: pkg.version == "4.7.2";
      ignoreScripts = false;
      installScript = ''
        patch ./bin/cli.js < ${./webpack-cli/remove-webpack-check.patch}
      '';
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
