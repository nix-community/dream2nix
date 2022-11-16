{pkgs}: let
  # This is only executed for electron based packages.
  # Electron ships its own version of node, requiring a rebuild of native
  # extensions.
  # Theoretically this requires headers for the exact electron version in use,
  # but we use the headers from nixpkgs' electron instead which might have a
  # different minor version.
  # Alternatively the headers can be specified via `electronHeaders`.
  # Also a custom electron version can be specified via `electronPackage`
  electron-rebuild = ''
    # prepare node headers for electron
    if [ -n "$electronPackage" ]; then
      export electronDist="$electronPackage/lib/electron"
    else
      export electronDist="$nodeModules/$packageName/node_modules/electron/dist"
    fi
    local ver
    ver="v$(cat $electronDist/version | tr -d '\n')"
    mkdir $TMP/$ver
    cp $electronHeaders $TMP/$ver/node-$ver-headers.tar.gz

    # calc checksums
    cd $TMP/$ver
    sha256sum ./* > SHASUMS256.txt
    cd -

    # serve headers via http
    python -m http.server 45034 --directory $TMP &

    # copy electron distribution
    cp -r $electronDist $TMP/electron
    chmod -R +w $TMP/electron

    # configure electron toolchain
    ${pkgs.jq}/bin/jq ".build.electronDist = \"$TMP/electron\"" package.json \
        | ${pkgs.moreutils}/bin/sponge package.json

    ${pkgs.jq}/bin/jq ".build.linux.target = \"dir\"" package.json \
        | ${pkgs.moreutils}/bin/sponge package.json

    ${pkgs.jq}/bin/jq ".build.npmRebuild = false" package.json \
        | ${pkgs.moreutils}/bin/sponge package.json

    # execute electron-rebuild if available
    export headers=http://localhost:45034/
    if command -v electron-rebuild &> /dev/null; then
      pushd $electronAppDir

      electron-rebuild -d $headers
      popd
    fi
  '';
in ''
  runHook preBuild

  # execute electron-rebuild
  if [ -n "$electronHeaders" ]; then
    echo "executing electron-rebuild"
    ${electron-rebuild}
  fi

  # execute install command
  if [ -n "$buildScript" ]; then
    if [ -f "$buildScript" ]; then
      $buildScript
    else
      eval "$buildScript"
    fi

  # by default, only for top level packages, `npm run build` is executed
  elif [ -n "$runBuild" ] && [ "$(jq '.scripts.build' ./package.json)" != "null" ]; then
    npm run build

  else
    if [ "$(jq '.scripts.preinstall' ./package.json)" != "null" ]; then
      npm --production --offline --nodedir=$nodeSources run preinstall
    fi
    if [ "$(jq '.scripts.install' ./package.json)" != "null" ]; then
      npm --production --offline --nodedir=$nodeSources run install
    fi
    if [ "$(jq '.scripts.postinstall' ./package.json)" != "null" ]; then
      npm --production --offline --nodedir=$nodeSources run postinstall
    fi
  fi

  runHook postBuild
''
