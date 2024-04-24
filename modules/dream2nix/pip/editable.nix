{
  lib,
  findRoot,
  unzip,
  pyEnv,
  editables,
  drvs,
}: ''
  dream2nix-mkEditable() {
    local name="$1"
    local source="$2"
    local dist_info_installed="$3"
    local editable_dir="$editables_dir/$name"
    if [[ "$source" == /nix/store/*.whl ]]
    then
      echo "Extracting editable source from $source to $editable_dir" >/dev/stderr
      unzip -q -d "$editable_dir" "$source" "$name/*"
    elif [[ "$source" == /nix/store/* ]]
    then
      echo "Copying editable source from $source to $editable_dir" >/dev/stderr
      cp --recursive --remove-destination "$source/." "$editable_dir/"
      chmod -R u+w "$editable_dir"
    else
      echo "Linking editable source from $source to $editable_dir"
      ln -sf "$source" "$editable_dir"
    fi

    if [ -e "$editable_dir/src" ]
    then
      echo "$editable_dir/src" > "$site_dir/$name.pth"
    else
      # TODO this approach is risky as it puts everything inside
      # upstreams repo on $PYTHONPATH. Maybe we should try to
      # get packages from toplevel.txt first and if found,
      # create a dir with only them linked?
      echo "$editable_dir" > "$site_dir/$name.pth"
    fi

    # Create a .dist-info directory based on the non-editable install
    local dist_info_name="$(basename "$dist_info_installed")"
    local dist_info_editable="$site_dir/$dist_info_name"
    cp --recursive --remove-destination "$dist_info_installed/." "$dist_info_editable/"
    chmod -R u+w "$dist_info_editable"

    # Required by PEP-660
    rm -f "$dist_info_editable/RECORD"
    cat > "$dist_info_editable/direct_url.json" <<EOF
  {
    "url": "file://$editable_dir",
    "dir_info": { "editable": true }
  }
  EOF
  }

  dream2nix-editablesHook() {
    # Ensure the python env is realized.
    nix build "${pyEnv.drvPath}^out"

    local dream2nix_dir="''$(${findRoot})/.dream2nix"
    local editables_dir="$dream2nix_dir/editables"
    local site_dir="$dream2nix_dir/site"
    mkdir -p "$editables_dir" "$site_dir"

    ${lib.concatStrings ((lib.flip lib.mapAttrsToList) editables (
    name: path: ''
      # if it's not in /nix/store already. We need its
      # .dist-info directory and might need it's unpackaged
      # source below.
      if [ ! -e "${drvs.${name}.public.out}" ]
      then
        nix build "${drvs.${name}.public.drvPath}^out"
      fi
      # Build the editable
      dream2nix-mkEditable \
        "${lib.replaceStrings ["-"] ["_"] name}" \
        "${
        if path != null
        then path
        else drvs.${name}.mkDerivation.src
      }" \
        "$(find ${drvs.${name}.public.out}/${pyEnv.sitePackages} -name '*.dist-info' -print -quit)"
    ''
  ))}

    cat > "$site_dir/sitecustomize.py" <<EOF
  import site
  site.addsitedir("$site_dir")
  EOF
    export PYTHONPATH="$site_dir:${pyEnv}/${pyEnv.sitePackages}:$PYTHONPATH"
    export PATH="${pyEnv}/bin:$PATH"
  }
  dream2nix-editablesHook
''
