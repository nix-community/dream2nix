{
  lib,
  pkgs,
  # dream2nix
  satisfiesSemver,
  ...
}: let
  l = lib // builtins;

  # include this into an override to enable cntr debugging
  # (linux only)
  cntr = {
    nativeBuildInputs = old: old ++ [pkgs.breakpointHook];
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

    cpu-features = {
      add-inputs = {
        nativeBuildInputs = old:
          old
          ++ [
            pkgs.cmake
          ];
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
        electronAppDir = "src";

        preBuild = {outputs, ...}: ''
          # link dependencies of subpackage
          ln -s \
            ${outputs.subPackages.edex-ui-subpackage.packages.edex-ui-subpackage}/lib/node_modules/edex-ui-subpackage/node_modules \
            ./src/node_modules

          # transform symlinked subpackage 'node-pty' to copies,
          # in order to allow re-building
          mv src/node_modules src/node_modules.bac
          mkdir src/node_modules
          cp -r src/node_modules.bac/* src/node_modules/
          symlinksToCopies ./src/node_modules/node-pty
        '';
      };
    };

    electron = let
      mkElectron =
        pkgs.callPackage
        ./electron/generic.nix
        {};

      nixpkgsElectrons =
        lib.mapAttrs
        (version: hashes:
          (mkElectron version hashes).overrideAttrs (old: {
            dontStrip = true;
          }))
        hashes;

      getElectronFor = version: let
        semVerSpec = "~${version}";

        filteredElectrons =
          lib.filterAttrs
          (electronVer: _:
            satisfiesSemver semVerSpec {
              version = electronVer;
            })
          nixpkgsElectrons;

        electrons = l.attrValues filteredElectrons;
      in
        if l.length electrons == 0
        then
          throw ''
            Electron binary hashes are missing for required version ${version}
            Please add the hashes in the override below the origin of this error.
            To get the hashes, execute:
            ${./.}/electron/print-hashes.sh ${version}
          ''
        else if l.length electrons > 1
        then let
          versionsSorted =
            l.sort
            (v1: v2: l.compareVersions v1 v2 == 1)
            (l.attrNames filteredElectrons);

          versionsToRemove = l.tail versionsSorted;
        in
          throw ''
            Multiple electron minor releases found.
            Please delete the hashes for versions ${l.toString versionsToRemove}
            in the override below the origin of this error.
          ''
        else l.head electrons;

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
        "12.2.3" = {
          armv7l-linux = "4de83c34987ac7b3b2d0c8c84f27f9a34d9ea2764ae1e54fb609a95064e7e71a";
          aarch64-linux = "d29d234c09ba810d89ed1fba9e405b6975916ea208d001348379f89b50d1835c";
          x86_64-linux = "deae6d0941762147716b8298476080d961df2a32d0f6f57b244cbe3a2553cd24";
          i686-linux = "11b4f159cd3b89d916cc05b5231c2cde53f0c6fb5be8e881824fde00daa5e8c2";
          x86_64-darwin = "5af34f1198ce9fd17e9fa581f57a8ad2c9333187fb617fe943f30b8cde9e6231";
          aarch64-darwin = "0db2c021a047a4cd5b28eea16490e16bc82592e3f8a4b96fbdc72a292ce13f50";
          headers = "1idam1xirxqxqg4g7n33kdx2skk0r351m00g59a8yx9z82g06ah9";
        };
        "13.0.0" = {
          armv7l-linux = "51ddcd8c92da5dd84a6bab8304a0df6114153a884f7f185ebfc65843caa30e76";
          aarch64-linux = "5b36e5bcb36cf1b90c38b346d3eae970a2aa41cb585df493bb90d86dc2e88b0a";
          x86_64-linux = "ff89df221293f7253e2a29eb3028014549286179e3d91402e4911b2d086377bb";
          i686-linux = "6fd7eca44302762a97c205b1a08a4178247bea89354ce84c747e09ebeb9f245b";
          x86_64-darwin = "f3b9e45a442f82f06da8dd6cbdccd8031a191f3ba73e2886572f6472160d1f2d";
          aarch64-darwin = "9c26405efd126d4e076fa8068e9003463be62b449182632babd5445f633712b6";
          headers = "0glv92hhzg5f0fycrgv2g2b1avcw4jcrmpxxz4rpn91gd1v4n4fn";
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
        "15.3.4" = {
          armv7l-linux = "caff953cbffdac63307b75a3b78be82ea6003782e981edfdcba14da5ee48b8b6";
          aarch64-linux = "dba1e09b3e4924148b57539d86840fa22e5500f3e15a694dcd2e26b830c1f780";
          x86_64-linux = "5e13b64c3b1b025ddea92b3bda577e00fc533902a9cf92bfd87b976637f7b59a";
          i686-linux = "1253e837e98fc41c14f6b71f0f917b8f42a0777bd2554046567b512f747240d8";
          x86_64-darwin = "ea1cb757f9c8c4c99c840357ecab42a0bcbe8c7a6a3a1265106c238088ad18f1";
          aarch64-darwin = "65b9b3235efdb681e3a4db85068dc9fe6dfbcb7fbb146053c0a534e4b44a2f7a";
          headers = "1xnbzskvf8p5a07bha41qqnw1hb68f019qrda3z2jn96m3qnj46r";
        };
      };
    in {
      add-binary = {
        overrideAttrs = old: {
          postPatch = ''
            cp -r ${getElectronFor "${old.version}"}/lib/electron ./dist
            chmod -R +w ./dist
            echo -n $version > ./dist/version
            echo -n "electron" > ./path.txt
          '';

          postFixup = ''
            mkdir -p $out/lib
            ln -s $(realpath ./dist) $out/lib/electron
          '';
        };
      };
    };

    # TODO: fix electron-builder call or find alternative
    element-desktop = {
      build = {
        # TODO: build rust extensions to enable searching encrypted messages
        # TODO: create lower case symlinks for all i18n strings
        buildScript = {outputs, ...}: ''
          npm run build:ts
          npm run i18n
          npm run build:res

          # build rust extensions
          # npm run hak

          ln -s ${outputs.subPackages.element-web.packages.element-web}/lib/node_modules/element-web/webapp ./webapp

          # ln -s ./lib/i18n/strings/en{-US,}.json
          ln -s \
            $(realpath ./lib/i18n/strings/en_US.json) \
            $(realpath ./lib/i18n/strings/en-us.json)
        '';

        # buildInputs = old: old ++ [
        #   pkgs.rustc
        # ];
      };
    };

    element-web = {
      build = {
        installMethod = "copy";

        # TODO: file upstream issue because of non-reproducible jitsi api file
        buildScript = ''
          # install jitsi api
          mkdir webapp
          cp ${./element-web/external_api.min.js} webapp/external_api.min.js

          # set version variables
          export DIST_VERSION=$version
          export VERSION=$version

          npm run reskindex
          npm run build:res
          npm run build:bundle
        '';
      };
    };

    esbuild = {
      "add-binary-0.12.17" = {
        _condition = pkg: pkg.version == "0.12.17";
        ESBUILD_BINARY_PATH = let
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
        in "${esbuild}/bin/esbuild";
      };
    };

    fontmanager-redux = {
      add-inputs = {
        nativeBuildInputs = old:
          old
          ++ [
            pkgs.fontconfig
          ];
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

    keytar = {
      add-pkg-config = {
        nativeBuildInputs = old:
          old
          ++ [
            pkgs.libsecret
            pkgs.pkg-config
          ];
      };
    };

    ledger-live-desktop = {
      build = {
        installMethod = "copy";

        postPatch = ''
          substituteInPlace ./tools/main.js --replace \
            "git rev-parse --short HEAD" \
            "echo unknown"
        '';
      };
    };

    mattermost-desktop = {
      build = {
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

          # required if electron-builder is used
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

    node-hid = {
      build = {
        nativeBuildInputs = old:
          old
          ++ [
            pkgs.pkg-config
            pkgs.libusb
          ];
      };
    };

    npm = {
      dont-install-deps = {
        installDeps = "";
      };
    };

    npx = {
      dont-install-deps = {
        installDeps = "";
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

    quill = {
      disable-build = {
        runBuild = false;
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

    simple-git-hooks = {
      dont-postinstall = {
        buildScript = "true";
      };
    };

    sodium-native = {
      build = {
        nativeBuildInputs = old:
          old
          ++ [
            pkgs.autoconf
            pkgs.automake
            pkgs.libtool
          ];
      };
    };

    tabby = {
      inherit cntr;
      fix-build = {
        electronAppDir = "./app";

        nativeBuildInputs = old:
          old
          ++ [
            pkgs.fontconfig
            pkgs.libsecret
            pkgs.pkg-config
          ];

        postPatch = {outputs, ...}: ''
          substituteInPlace ./scripts/vars.js --replace \
            "exports.version = childProcess.execSync('git describe --tags', { encoding:'utf-8' })" \
            "exports.version = '$version'"

          ${pkgs.jq}/bin/jq ".typeAcquisition = {}" tsconfig.json \
              | ${pkgs.moreutils}/bin/sponge tsconfig.json

          substituteInPlace app/webpack.main.config.js --replace \
            "configFile: path.resolve(__dirname, 'tsconfig.main.json')," \
            "configFile: path.resolve(__dirname, 'tsconfig.main.json'), allowTsInNodeModules: true,"

          substituteInPlace app/webpack.config.js --replace \
            "configFile: path.resolve(__dirname, 'tsconfig.json')," \
            "configFile: path.resolve(__dirname, 'tsconfig.json'), allowTsInNodeModules: true,"

          substituteInPlace web/webpack.config.js --replace \
            "configFile: path.resolve(__dirname, 'tsconfig.json')," \
            "configFile: path.resolve(__dirname, 'tsconfig.json'), allowTsInNodeModules: true,"

          otherModules=${pkgs.writeText "other-modules.json" (l.toJSON
            (l.mapAttrs
              (pname: subOutputs: let
                pkg = subOutputs.packages."${pname}".overrideAttrs (old: {
                  buildScript = "true";
                  installMethod = "copy";
                });
              in "${pkg}/lib/node_modules/${pname}/node_modules")
              outputs.subPackages))}

          symlinksToCopies() {
            local dir="$1"

            echo "transforming symlinks to copies..."
            for f in $(find -L "$dir" -xtype l); do
              if [ -f $f ]; then
                continue
              fi
              echo "copying $f"
              chmod +wx $(dirname "$f")
              mv "$f" "$f.bak"
              mkdir "$f"
              if [ -n "$(ls -A "$f.bak/")" ]; then
                cp -r "$f.bak"/* "$f/"
                chmod -R +w $f
              fi
              rm "$f.bak"
            done
          }

          for dir in $(ls -d */); do
            if [ -f $dir/package.json ]; then
              echo "installing sub-package $dir"
              name=$(${pkgs.jq}/bin/jq -r '.name' $dir/package.json)
              node_modules=$(${pkgs.jq}/bin/jq -r ".\"$name\"" $otherModules)
              if [ "$node_modules" == "null" ]; then
                node_modules=$(${pkgs.jq}/bin/jq -r ".\"''${dir%/}\"" $otherModules)
              fi
              cp -r $node_modules $dir/node_modules
              chmod -R +w $dir
            fi
          done
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

    usb-detection = {
      build = {
        nativeBuildInputs = old:
          old
          ++ [
            pkgs.libudev
          ];
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

    # TODO: Maybe should replace binaries with the ones from nixpkgs
    "7zip-bin" = {
      patch-binaries = {
        nativeBuildInputs = old:
          old
          ++ [
            pkgs.autoPatchelfHook
          ];

        buildInputs = old:
          old
          ++ [
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

    "@ledgerhq/ledger-core" = {
      build = let
        ledger-core-version = "4.2.0";

        ledger-core = pkgs.stdenv.mkDerivation {
          pname = "ledger-core";
          version = ledger-core-version;
          src = pkgs.fetchFromGitHub {
            owner = "LedgerHQ";
            repo = "lib-ledger-core";
            rev = ledger-core-version;
            fetchSubmodules = true;
            sha256 = "sha256-6nfeHxWyKRm5dCYamaDtx53SqqPK+GJ8kqI37XdEtuI=";
          };
          nativeBuildInputs = [
            pkgs.cmake
          ];
        };

        secp256k1-src = pkgs.fetchzip {
          url = "https://github.com/chfast/secp256k1/archive/ac8ccf29b8c6b2b793bc734661ce43d1f952977a.tar.gz";
          hash = "sha256-7i61CGd+xFvPQkyN7CI7eEoTtko0S77eY+DXEbd3BE8=";
        };
      in {
        buildInputs = [
          ledger-core
        ];

        # TODO: patch core/lib/cmake/ProjectSecp256k1.cmake
        #       to use this secp256k1 instead of downloading from github
        postPatch = ''
          cp -r ${secp256k1-src} ./secp256k1
        '';

        preBuild = ''
          # npm --nodedir=$nodeSources run install
          npm --nodedir=$nodeSources run gypconfig
          npm --nodedir=$nodeSources run gypinstall
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

    "@sentry/cli" = {
      add-binary = {
        buildScript = ''
          ln -s ${pkgs.sentry-cli}/bin $out/bin
          exit
        '';
      };
    };

    "strapi" = {
      build = {
        buildScript = ''
          yarn(){
            npm "$@"
          }
        '';
      };
    };
  }
