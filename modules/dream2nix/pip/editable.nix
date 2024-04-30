{
  lib,
  findRoot,
  unzip,
  pyEnv,
  editables,
  rootName,
  drvs,
}: ''
  dream2nix-mkEditable() {
    local name="$1"
    local source="$2"
    local dist_info_installed="$3"
    local editable_dir="$editables_dir/$name"
    if [ -e "$editable_dir" ]
    then
      echo "Skipping existing editable source in $editable_dir" >/dev/stderr
      return
    fi

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
      echo "Linking editable source from $source to $editable_dir" >/dev/stderr
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
    nix build --no-link "${pyEnv.drvPath}^out"

    local dream2nix_dir="''$(${findRoot})/.dream2nix"
    local editables_dir="$dream2nix_dir/editables"
    local site_dir="$dream2nix_dir/site"
    # Reset the site dir every time, so that editables which are
    # removed are removed from the path. Don't remove $editables_dir,
    # as that might contain uncommited changes.
    rm -rf "$site_dir"
    mkdir -p "$editables_dir" "$site_dir"

    ${lib.concatStrings ((lib.flip lib.mapAttrsToList) editables (
    name: path: ''
      # Build the non-editable package if it's not in /nix/store already.
      # We need its .dist-info directory and might need it's unpackaged
      # source below.
      if [ ! -e "${drvs.${name}.public.out}" ]
      then
        nix build --no-link "${drvs.${name}.public.drvPath}^out"
      fi

      local source="${
        # If an explicit path is set, use that one.
        # If not, use the current project root for the root package,
        # and copy mkDerivation.src for other packages.
        if path != null
        then path
        else if name == rootName
        then "$(${findRoot})"
        else drvs.${name}.mkDerivation.src
      }"
      # Build the editable
      dream2nix-mkEditable \
        "${lib.replaceStrings ["-"] ["_"] name}" \
         "$source" \
        "$(find ${drvs.${name}.public.out}/${pyEnv.sitePackages} -name '*.dist-info' -print -quit)"
    ''
  ))}

    cat > "$site_dir/sitecustomize.py" <<EOF
  import sys
  import site

  try:
    import _sitecustomize
  except ImportError:
    pass

  site.addsitedir("$site_dir")

  # addsitedir only supports appending to the path, not prepending.
  # As we already include a non-editable instance of each package
  # in our pyEnv, those would shadow the editables. So we move
  # the editables to the front of sys.path.
  for index, path in enumerate(sys.path):
    if path.startswith("$editables_dir"):
      sys.path.insert(0, sys.path.pop(index))
  EOF

    export PYTHONPATH="$site_dir:${pyEnv}/${pyEnv.sitePackages}:$PYTHONPATH"
    export PATH="${pyEnv}/bin:$PATH"
  }
  dream2nix-editablesHook
''
