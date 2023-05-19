{
  jq,
  moreutils,
}: ''
  runHook preBuild

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
