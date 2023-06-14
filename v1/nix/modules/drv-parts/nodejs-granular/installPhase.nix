{
  stdenv,
  # this function needs the following arguments via env
  # packageName,
  # nodeModules,
}: ''
  echo "executing installPhaseNodejs"

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
''
