{
  pkgs,
  # this function needs the following arguments via env
  # packageName,
  # nodeModules,
  # electronDist,
  # electronAppDir,
  # electronHeaders
}: let
  # Only executed for electron based packages.
  # Creates an executable script under /bin starting the electron app
  electronWrap =
    if pkgs.stdenv.isLinux
    then ''
      mkdir -p $out/bin
      makeWrapper \
        $electronDist/electron \
        $out/bin/$(basename "$packageName") \
        --add-flags "$(realpath $electronAppDir)"
    ''
    else ''
      mkdir -p $out/bin
      makeWrapper \
        $electronDist/Electron.app/Contents/MacOS/Electron \
        $out/bin/$(basename "$packageName") \
        --add-flags "$(realpath $electronAppDir)"
    '';
in ''
  runHook preInstall
  mkdir -p $out/lib
  cp -r $nodeModules $out/lib/node_modules
  nodeModules=$out/lib/node_modules
  cd "$nodeModules/$packageName"

  echo "Symlinking bin entries from package.json"
  python $linkBins

  echo "Symlinking manual pages"
  if [ -d "$nodeModules/$packageName/man" ]
  then
    mkdir -p $out/share
    for dir in "$nodeModules/$packageName/man/"*
    do
      mkdir -p $out/share/man/$(basename "$dir")
      for page in "$dir"/*
      do
          ln -s $page $out/share/man/$(basename "$dir")
      done
    done
  fi

  # wrap electron app
  if [ -n "$electronHeaders" ]; then
    echo "Wrapping electron app"
    ${electronWrap}
  fi

  runHook postInstall
''
