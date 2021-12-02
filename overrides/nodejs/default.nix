{
  lib,
  pkgs,

  # dream2nix
  satisfiesSemver,
  ...
}:

let
  l = lib // builtins;

  # include this into an override to enable cntr debugging
  # (linux only)
  cntr = {
    nativeBuildInputs = [pkgs.breakpointHook];
    b = "${pkgs.busybox}/bin/busybox";
  };

  # helper that should be prepended to any sed call to ensure the file
  # is actually modified.
  ensureFileModified = pkgs.writeScript "ensure-file-changed" ''
    #!${pkgs.bash}/bin/bash
    file=$1
    cp $file $TMP/ensureFileModified
    "''${@:2}"
    if diff -q $file $TMP/ensureFileModified; then
      echo -e "file $file could not be modified as expected by command:\n  ''${@:2}"
      exit 1
    fi
  '';

in

## OVERRIDES
{

  atom = {
    build = {
      buildScript = ''
        node script/build --no-bootstrap
      '';
    };
  };

  balena-etcher = {
    build = {
      buildScript = ''
        npm run webpack
      '';
    };
  };

  code-oss-dev = {
    build = {
      buildScript = ''
        npm run compile-extensions-build
      '';
    };
  };

  css-loader = {

    disable-source-map-v4-v5 = {

      _condition = pkg:
        satisfiesSemver "^4.0.0" pkg
        || satisfiesSemver "^5.0.0" pkg;

      postPatch = ''
        substituteInPlace ./dist/utils.js --replace \
          "sourceMap: typeof rawOptions.sourceMap === "boolean" ? rawOptions.sourceMap : loaderContext.sourceMap," \
          "sourceMap: false,"
      '';
    };
  };

  cypress = {

    add-binary = {

      dontBuild = true;
    };
  };

  "draw.io" = {

    build = {

      nativeBuildInputs = [
        pkgs.makeWrapper
      ];

      buildScript = ''
        mkdir $out/bin
        makeWrapper \
          $(realpath ./node_modules/electron/dist/electron) \
          $out/bin/drawio \
          --add-flags \
            "$(realpath ./drawio/src/main/webapp)"
      '';
    };
  };

  dugite = {

    add-git = {

      buildScript = ''
        ln -s ${pkgs.git} ./git
      '';
    };
  };

  edex-ui = {

    build = {

      nativeBuildInputs = [
        pkgs.rsync
      ];

      buildScript = ''
        npm run build-linux
      '';
    };
  };

  electron =
    let

      mkElectron =
        pkgs.callPackage
          "${pkgs.path}/pkgs/development/tools/electron/generic.nix"
          {};

      nixpkgsElectrons =
        lib.mapAttrs
          (version: hashes:
            (mkElectron version hashes).overrideAttrs (old: {
              dontStrip = true;
              fixupPhase = old.postFixup;
            }))
          hashes;

      getElectronFor = version:
        nixpkgsElectrons."${version}"
        or (throw ''
          Electron binary hashes are missing for required version ${version}
          Please add the hashes in the override below the origin of this error.
          To get the hashes, execute:
          ${pkgs.path}/pkgs/development/tools/electron/print-hashes.sh ${version}
        '');

      # TODO: generate more of these via the script in nixpkgs,
      #       once we feel confident about this approach
      hashes = {
        "8.5.5" = {
          x86_64-linux = "8058442ab4a18d73ca644d4a6f001e374c3736bc7e37db0275c29011681f1f22";
          x86_64-darwin = "02bb9f672c063b23782bee6e336864609eed72cffeeea875a3b43c868c6bd8b3";
          i686-linux = "c8ee6c3d86576fe7546fb31b9318cb55a9cd23c220357a567d1cb4bf1b8d7f74";
          armv7l-linux = "0130d1fcd741552d2823bc8166eae9f8fc9f17cd7c0b2a7a5889d753006c0874";
          aarch64-linux = "ca16d8f82b3cb47716dc9db273681e9b7cd79df39894a923929c99dd713c45f5";
          headers = "18frb1z5qkyff5z1w44mf4iz9aw9j4lq0h9yxgfnp33zf7sl9qb5";
        };
        "10.4.5" = {
          x86_64-linux = "d7f6203d09b4419262e985001d4c4f6c1fdfa3150eddb0708df9e124bebd0503";
          x86_64-darwin = "e3ae7228010055b1d198d8dbaf0f34882d369d8caf76206a59f198301a3f3913";
          i686-linux = "dd6abc0dc00d8f9d0e31c8f2bb70f7bbbaec58af4c446f8b493bbae9a9428e2f";
          armv7l-linux = "86bc5f9d3dc94d19e847bf10ab22d98926b616d9febcbdceafd30e35b8f2b2db";
          aarch64-linux = "655b36d68332131250f7496de0bb03a1e93f74bb5fc4b4286148855874673dcd";
          headers = "1kfgww8wha86yw75k5yfq4mxvjlxgf1jmmzxy0p3hyr000kw26pk";
        };
        "11.4.6" = {
          x86_64-linux = "03932a0b3328a00e7ed49947c70143b7b3455a3c1976defab2f74127cdae43e9";
          x86_64-darwin = "47de03b17ab20213c95d5817af3d7db2b942908989649202efdcd1d566dd24c3";
          i686-linux = "b76e69ad4b654384b4f1647f0cb362e78c1d99be7b814d7d32abc22294639ace";
          armv7l-linux = "cc4be8e0c348bc8db5002cf6c63c1d02fcb594f1f8bfc358168738c930098857";
          aarch64-linux = "75665dd5b2b9938bb4572344d459db65f46c5f7c637a32946c5a822cc23a77dc";
          aarch64-darwin = "0c782b1d4eb848bae780f4e3a236caa1671486264c1f8e72fde98f1256d8f9e5";
          headers = "0ip1wxgflifs86vk4xpz1555xa7yjy64ygqgd5a2g723148m52rk";
        };
        "12.0.2" = {
          x86_64-linux = "fc3ff888d8cd4ada8368420c8951ed1b5ad78919bdcb688abe698d00e12a2e0a";
          x86_64-darwin = "766ca8f8adc4535db3069665ea8983979ea79dd5ec376e1c298f858b420ec58f";
          i686-linux = "78ab55db275b85210c6cc14ddf41607fbd5cefed93ef4d1b6b74630b0841b23c";
          armv7l-linux = "8be8c6ea05da669d79179c5969ddee853710a1dd44f86e8f3bbe1167a2daf13c";
          aarch64-linux = "9ef70ab9347be63555784cac99efbaff1ef2d02dcc79070d7bccd18c38de87ef";
          aarch64-darwin = "d4f0f73e0a5a723ef7f3f1e6ca3743b6267eef385cf79aa63a2fb3f698a7931d";
          headers = "07095b5rylilbmyd0syamm6fc4pngazldj5jgm7blgirdi8yzzd2";
        };
        "12.2.2" = {
          x86_64-linux = "a8e88c67f375e41f3a6f8b8a8c3a1e41b8c0a46f1b731e05de21208caa005fb2";
          x86_64-darwin = "8a33d2bed668e30a6d64856e01d2aa3b1f1d9efe4eb0e808e916694d32d5e8f2";
          i686-linux = "5f0bdc9581237f2f87b5d34e232d711617bd8bf5ff5d7ebd66480779c13fba0a";
          armv7l-linux = "aeee4acf40afa0397c10a4c76bc61ed2967433bab5c6f11de181fa33d0b168ff";
          aarch64-linux = "593a3fef97a7fed8e93b64d659af9c736dff445eedcbfd037f7d226a88d58862";
          aarch64-darwin = "256daa25a8375c565b32c3c2f0e12fbac8d5039a13a9edbb3673a863149b750a";
          headers = "1fvqkw08pync38ixi5cq4f8a108k2ajxpm1w2f8sn2hjph9kpbsd";
        };
        "13.1.9" = {
          x86_64-linux = "60c7c74a5dd00ebba6d6b5081a4b83d94ac97ec5e53488b8b8a1b9aabe17fefc";
          x86_64-darwin = "b897bdc42d9d1d0a49fc513c769603bff6e111389e2a626eb628257bc705f634";
          i686-linux = "081f08ce7ff0e1e8fb226a322b855f951d120aa522773f17dd8e5a87969b001f";
          armv7l-linux = "c6b6b538d4764104372539c511921ddecbf522ded1fea856cbc3d9a303a86206";
          aarch64-linux = "9166dd3e703aa8c9f75dfee91fb250b9a08a32d8181991c1143a1da5aa1a9f20";
          aarch64-darwin = "a1600c0321a0906761fdf88ab9f30d1c53b53803ca33bcae20a6ef7a6761cac1";
          headers = "1k9x9hgwl23sd5zsdrdlcjp4ap40g282a1dxs1jyxrwq1dzgmsl3";
        };
        "13.2.3" = {
          x86_64-linux = "495b0c96427c63f6f4d08c5b58d6379f9ee3c6c81148fbbe8a7a6a872127df6d";
          x86_64-darwin = "c02f116484a5e1495d9f7451638bc0d3dea8fa2fde2e4c9c88a17cff98192ddc";
          i686-linux = "03fb8cad91fcbb578027b814119b09cd1ddd414f159c9012850655f9171847c1";
          armv7l-linux = "d8aaf2b49b9ab0a46caa31ed7d4358a3223efeaf90941d3d5e272532718ed754";
          aarch64-linux = "cbbf9f98b1cfbee3fcd0869632a03542408dfd35f2e4d5b72cd823ce9448f659";
          aarch64-darwin = "ef375063e30bc51bbcbe16fb7e5d85933eb60888ccc159c391aefc4f6d616faa";
          headers = "0ayiklr84x7xhh5nz2dfzq2fkqivb9y9axfy7q9n4ps08xbqycyr";
        };
        "13.5.1" = {
          x86_64-linux = "4d145dbca59541d665435198c9fb697b1ec85c6e525878b7f48ecb8431dc4836";
          x86_64-darwin = "ac342741a17034ccc305b83fde18d014f8c6080f8f7143e953545a945542168d";
          i686-linux = "95acabcf7d0a5a3bbfa0634c1956d8aea59565fb695d22ec65edd77c2a09e3a8";
          armv7l-linux = "9cb773eaa9882c313513cb1bb552f8bcac859f35854de477dc2ec6cc24e7d003";
          aarch64-linux = "ae605f169482b1c40e9449073c0f962cceeac4166a00cb304ba22f4f5a7a5d48";
          aarch64-darwin = "79ad1c22afb2e5338467621fc16a092d16be329c3b60bb753caa311e9933a4b4";
          headers = "0pjj0ra5ksn6cdqiy84ydy45hivksknzbq3szs9r9dlajcczgw9l";
        };
        "13.6.1" = {
          x86_64-linux = "bfc09dd2d591ad614c8d598dad6e13b76c3baf4f48773e7819c493b524a0bb1a";
          x86_64-darwin = "ce45f17f875d72e791999eaf30a1af39b6e9143e57a653e7f06cfa0bee9b985d";
          i686-linux = "1ea7c7d19759fa0ee0ddef68c09bcc1c57265436d3f5dab37dad3567f117f317";
          armv7l-linux = "c8bba8da0baf5cde3eb4823c801c228abfa7943c69131b3701c74e2b342e1813";
          aarch64-linux = "09a1ff29c33a23f19cc702e0147dee03cfe2acedcff6bfb63c7911184b871a1a";
          aarch64-darwin = "e2f82720acae3a03d7d4b3e7dcc7697b84d5bb69a63d087a7420ace2412e7a28";
          headers = "1bd87c74863w0sjs8gfxl62kjjscc56dmmw85vhwz01s4niksr02";
        };
        "14.1.0" = {
          x86_64-linux = "27b60841c85369a0ea8b65a8b71cdd1fb08eba80d70e855e9311f46c595874f3";
          x86_64-darwin = "36d8e900bdcf5b410655e7fcb47800fa1f5a473c46acc1c4ce326822e5e95ee1";
          i686-linux = "808795405d6b27221b219c2a0f7a058e3acb2e56195c87dc08828dc882ffb8e9";
          armv7l-linux = "25a68645cdd1356d95a8bab9488f5aeeb9a206f9b5ee2df23c2e13f87d775847";
          aarch64-linux = "94047dcf53c54f6a5520a6eb62e400174addf04fc0e3ebe04b548ca962de349a";
          aarch64-darwin = "5c81f418f3f83dc6fc5893247dd386e1d23e609c83f798dd5aad451febed13c8";
          headers = "0p8lkhy97yq43sl6s4rskhdnzl520968cyh5l4fdhl2fhm5mayd4";
        };
        "14.2.0" = {
          armv7l-linux = "a1357716ebda8d7856f233c86a8cbaeccad1c83f1d725d260b0a6510c47042a2";
          aarch64-linux = "b1f4885c3ad816d89446f64a87b78d5139a27fecbf6317808479bede6fd94ae1";
          x86_64-linux = "b2faec4744edb20e889c3c85af685c2a6aef90bfff58f55b90038a991cd7691f";
          i686-linux = "9207af6e3a24dfcc76fded20f26512bcb20f6b652295a4ad3458dc10fd2d7d6e";
          x86_64-darwin = "d647d658c8c2ec4a69c071e791cf7e823320860f987121bd7390978aecacb073";
          aarch64-darwin = "f5a7e52b639b94cf9b2ec53969c8014c6d299437c65d98c33d8e5ca812fbfd48";
          headers = "1y289vr8bws3z6gmhaj3avz95rdhc8gd3rc7bi40jv9j1pnlsd3m";
        };
      };

    in

    {

      add-binary-v14 = {

        overrideAttrs = old: {
          postPatch = ''
            cp -r ${getElectronFor "${old.version}"}/lib/electron ./dist
            chmod -R +w ./dist
            echo -n $version > ./dist/version
            echo -n "electron" > ./path.txt
          '';
        };
      };
    };

  # TODO: fix electron-builder call or find alternative
  element-desktop = {
    build = {
      postPatch = ''
        ls tsconfig.json
        cp ${./element-desktop/tsconfig.json} ./tsconfig.json
      '';
      buildScript = ''
        npm run build:ts
        npm run build:res
        # electron-builder
      '';
      nativeBuildInputs = [pkgs.breakpointHook];
      b = "${pkgs.busybox}/bin/busybox";
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

  enhanced-resolve = {

    fix-resolution-v4 = {

      _condition = satisfiesSemver "^4.0.0";

      # respect node path
      postPatch = ''
        ${ensureFileModified} lib/ResolverFactory.js \
          sed -zi 's/const symlinks =.*options.symlinks : true;/const symlinks = false;/g' lib/ResolverFactory.js

        substituteInPlace lib/ResolverFactory.js --replace \
          'let modules = options.modules || ["node_modules"];' \
          'let modules = (options.modules || ["node_modules"]).concat(process.env.NODE_PATH.split( /[;:]/ ));'
      '';
    };

    fix-resolution-v5 = {

      _condition = satisfiesSemver "^5.0.0";

      patches = [
        ./enhanced-resolve/npm-preserve-symlinks-v5.patch
        ./enhanced-resolve/respect-node-path-v5.patch
      ];
    };
  };

  gifsicle = {
    add-binary = {
      buildScript = ''
        mkdir -p ./vendor
        ln -s ${pkgs.gifsicle}/bin/gifsicle ./vendor/gifsicle
        npm run postinstall
      '';
    };
  };

  ledger-live-desktop = {
    build = {
      postPatch = ''
        substituteInPlace ./tools/main.js --replace \
          "git rev-parse --short HEAD" \
          "echo unknown"
      '';
    };
  };

  mattermost-desktop = {

    build = {

      nativeBuildInputs = [
        pkgs.makeWrapper
      ];

      postPatch = ''
        substituteInPlace webpack.config.base.js --replace \
          "git rev-parse --short HEAD" \
          "echo foo"


        ${pkgs.jq}/bin/jq ".electronDist = \"$TMP/dist\"" electron-builder.json \
          | ${pkgs.moreutils}/bin/sponge electron-builder.json

        ${pkgs.jq}/bin/jq ".linux.target = [\"dir\"]" electron-builder.json \
          | ${pkgs.moreutils}/bin/sponge electron-builder.json
      '';

      # TODO:
      #   - figure out if building via electron-build is feasible
      #     (if not, remove commented out instructions)
      #   - app seems to logout immediately after login (token expired)
      buildScript = ''
        # copy over the electron dist, as write access seems required
        cp -r ./node_modules/electron/dist $TMP/dist
        chmod -R +w $TMP/dist

        # required if electron-buidler is used
        # mv $TMP/dist/electron $TMP/dist/electron-wrapper
        # mv $TMP/dist/.electron-wrapped $TMP/dist/electron

        NODE_ENV=production npm-run-all check-build-config build-prod

        # skipping electron-builder, as produced executable crashes on startup
        # electron-builder --linux --x64 --publish=never

        # the electron wrapper wants to read the name and version from there
        cp package.json dist/package.json

        mkdir -p $out/bin
        makeWrapper \
          $(realpath ./node_modules/electron/dist/electron) \
          $out/bin/mattermost-desktop \
          --add-flags \
            "$(realpath ./dist) --disable-dev-mode"
      '';
    };
  };

  mozjpeg = {
    add-binary = {
      buildScript = ''
        mkdir -p ./vendor
        ln -s ${pkgs.mozjpeg}/bin/cjpeg ./vendor/cjpeg
        npm run postinstall
      '';
    };
  };

  Motrix = {
    build = {
      postPatch = ''
        ${pkgs.jq}/bin/jq ".build.electronDist = \"$TMP/dist\"" package.json \
          | ${pkgs.moreutils}/bin/sponge package.json
      '';
    };
  };

  optipng-bin = {
    add-binary = {
      buildScript = ''
        mkdir -p ./vendor
        ln -s ${pkgs.optipng}/bin/optipng ./vendor/optipng
        npm run postinstall
      '';
    };
  };

  pngquant-bin = {
    add-binary = {
      buildScript = ''
        mkdir -p ./vendor
        ln -s ${pkgs.pngquant}/bin/pngquant ./vendor/pngquant
        npm run postinstall
      '';
    };
  };

  rollup = {
    preserve-symlinks = {
      postPatch = ''
        find -name '*.js' -exec \
          ${ensureFileModified} {} sed -i "s/preserveSymlinks: .*/preserveSymlinks: true,/g" {} \;
      '';
    };
  };

  # TODO: confirm this is actually working
  typescript = {
    preserve-symlinks = {
      postPatch = ''
        find -name '*.js' -exec \
          ${ensureFileModified} {} sed -i "s/options.preserveSymlinks/true/g; s/compilerOptions.preserveSymlinks/true/g" {} \;
      '';
    };
  };

  vscode-ripgrep = {
    add-binary = {
      buildScript = ''
        mkdir bin
        mkdir -p $out/bin
        ln -s ${pkgs.ripgrep}/bin/rg bin/rg
        ln -s ${pkgs.ripgrep}/bin/rg $out/bin/rg
      '';
    };
  };

  # TODO: ensure preserving symlinks on dependency resolution always works
  #       The patch is currently done in `enhanced-resolve` which is used
  #       by webpack for module resolution
  webpack = {
    remove-webpack-cli-check = {
      _condition = satisfiesSemver "^5.0.0";
      patches = [
        ./webpack/remove-webpack-cli-check.patch
      ];
    };
  };

  webpack-cli = {
    remove-webpack-check = {
      _condition = satisfiesSemver "^4.0.0";
      patches = [
        ./webpack-cli/remove-webpack-check.patch
      ];
    };
  };

  # TODO: Maybe should replace binaries with the ones from nixpkgs
  "7zip-bin" = {

    patch-binaries = {

      nativeBuildInputs = [
        pkgs.autoPatchelfHook
      ];

      buildInputs = old: old ++ [
        pkgs.gcc-unwrapped.lib
      ];
    };
  };

  "@alicloud/fun" = {
    build = {
      buildScript = ''
        tsc -p ./
      '';
    };
  };

  "@mattermost/webapp" = {

    run-webpack = {

      # custom webpack config
      postPatch = ''
        substituteInPlace webpack.config.js --replace \
          "crypto: require.resolve('crypto-browserify')," \
          "crypto: 'node_modules/crypto-browserify',"

        substituteInPlace webpack.config.js --replace \
          "stream: require.resolve('stream-browserify')," \
          "stream: 'node_modules/stream-browserify',"

        substituteInPlace webpack.config.js --replace \
          "DEV ? 'style-loader' : MiniCssExtractPlugin.loader," \
          ""
      '';

      # there seems to be a memory leak in some module
      # -> incleasing max memory
      buildScript = ''
        NODE_ENV=production node --max-old-space-size=8192 ./node_modules/webpack/bin/webpack.js
      '';
    };
  };

  # This should not be necessary, as this plugin claims to
  # respect the `preserveSymlinks` option of rollup.
  # Adding the NODE_PATH to the module directories fixes it for now.
  "@rollup/plugin-node-resolve" = {
    respect-node-path = {
      postPatch = ''
        for f in $(find -name '*.js'); do
          substituteInPlace $f --replace \
            "moduleDirectories: ['node_modules']," \
            "moduleDirectories: ['node_modules'].concat(process.env.NODE_PATH.split( /[;:]/ )),"
        done
      '';
    };
  };

}
