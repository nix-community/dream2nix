import os
import sys
import json
import shutil
import subprocess
import configparser
from textwrap import dedent
from pathlib import Path


def run(args):
    try:
        proc = subprocess.run(
            args,
            check=True,
            capture_output=True,
            encoding="utf8",
        )
        return proc.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error while calling {' '.join(args)}", file=sys.stderr)
        print(e.output, file=sys.stderr)
        sys.exit(1)


def make_editable(
    python_environment,
    bin_dir,
    site_dir,
    editables_dir,
    site_packages,
    drvs,
    name,
    path,
):
    normalized_name = name.replace("-", "_")
    editable_dir = editables_dir / name
    drv_out = Path(drvs[name]["out"])
    if editable_dir.exists():
        print(f"Skipping existing editable source in {editable_dir}", file=sys.stderr)
        return

    # Build the non-editable package if it's not in /nix/store already.
    # We need its .dist-info directory and might need it's unpackaged
    # source below.
    if not drv_out.exists():
        run(["nix", "build", "--no-link", drv_out])

    make_editable_source(editable_dir, normalized_name, path)
    make_pth(site_dir, editable_dir, normalized_name)
    editable_dist_info = make_dist_info(site_dir, editable_dir, site_packages, drv_out)
    make_entrypoints(python_environment, bin_dir, editable_dist_info)


def make_editable_source(editable_dir, normalized_name, path):
    # If a(n absolute) path is found, we use that.
    if path != None:
        source = path
    # For the root package, we default to as symlink to this projects root
    elif name == root_name:
        source = root_dir
    # For all others, we copy mkDerivation.src from /nix/store.
    else:
        source = drvs[name]["src"]

    # Create a copy of the source in editable_dir
    if str(source).startswith("/nix/store") and str(source).endswith(".whl"):
        print(
            f"Extracting editable source from {source} to {editable_dir}",
            file=sys.stderr,
        )
        run(
            [
                f"{unzip}/bin/unzip",
                "-q",
                "-d",
                str(editable_dir),
                source,
                f"{normalized_name}/*",
            ]
        )
    elif str(source).startswith("/nix/store"):
        print(
            f"Copying editable source from {source} to {editable_dir}",
            file=sys.stderr,
        )
        shutil.copytree(source, editable_dir, symlinks=True)
        run(["chmod", "-R", "u+w", editable_dir])
    else:
        print(
            f"Linking editable source from {source} to {editable_dir}",
            file=sys.stderr,
        )
        run(["ln", "-sf", source, editable_dir])


def make_pth(site_dir, editable_dir, normalized_name):
    # Check if source uses a "src"-layout or a flat-layout and
    # write the .pth file
    if (editable_dir / "src").exists():
        pth = editable_dir / "src"
    else:
        # TODO this approach is risky as it puts everything inside
        # upstreams repo on $PYTHONPATH. Maybe we should try to
        # get packages from toplevel.txt first and if found,
        # create a dir with only them linked?
        pth = editable_dir
    with open((site_dir / normalized_name).with_suffix(".pth"), "w") as f:
        f.write(f"{pth}\n")


def make_dist_info(site_dir, editable_dir, site_packages, drv_out):
    # Reuse dist_info from the non-editable derivation and make it editable
    installed_dist_infos = list((drv_out / site_packages).glob("*.dist-info"))
    assert len(installed_dist_infos) == 1
    installed_dist_info = installed_dist_infos[0]
    editable_dist_info = site_dir / installed_dist_info.name
    shutil.copytree(installed_dist_info, editable_dist_info, symlinks=True)
    run(["chmod", "-R", "u+w", editable_dist_info])

    if (editable_dist_info / "RECORD").exists():
        # PEP-660 says RECORD should not be included
        (editable_dist_info / "RECORD").unlink()

    with open(editable_dist_info / "direct_url.json", "w") as f:
        json.dump(
            {"url": f"file://{editable_dir}", "dir_info": {"editable": True}},
            f,
            indent=2,
        )
    return editable_dist_info


def make_entrypoints(python_environment, bin_dir, dist_info):
    entry_points_file = dist_info / "entry_points.txt"
    if not entry_points_file.exists():
        return
    entry_points = configparser.ConfigParser()
    entry_points.read(entry_points_file)
    if "console_scripts" not in entry_points:
        return
    for name, spec in entry_points["console_scripts"].items():
        # https://setuptools.pypa.io/en/latest/userguide/entry_point.html#entry-points-syntax
        package, obj_attrs = spec.split(":", 1) if ":" in spec else (spec, None)
        obj, attrs = (
            obj_attrs.split(".", 1)
            if obj_attrs and "." in obj_attrs
            else (obj_attrs, None)
        )
        script = (
            f"#!{python_environment}/bin/python\n"
            + dedent(
                f"""
                from {package} import {obj}
                {obj}{f".{attrs}" if attrs else ""}()
            """
                if obj
                else f"""
                import {package}
                {package}()
            """
            ).strip()
        )
        with open(bin_dir / name, "w") as f:
            f.write(script)
        os.chmod(bin_dir / name, 0o755)


if __name__ == "__main__":
    with open(sys.argv[1], "r") as f:
        args = json.load(f)
    # print(json.dumps(args, indent=2), file=sys.stderr)
    unzip = args["unzip"]
    find_root = args["findRoot"]
    python_environment = Path(args["pyEnv"])
    root_name = args["rootName"]
    site_packages = args["sitePackages"]
    drvs = args["drvs"]
    editables = args["editables"]

    # directories to use
    root_dir = Path(run([find_root]))
    dream2nix_dir = root_dir / ".dream2nix"
    editables_dir = dream2nix_dir / "editables"
    bin_dir = dream2nix_dir / "bin"
    site_dir = dream2nix_dir / "site"

    bin_dir.mkdir(parents=True, exist_ok=True)
    editables_dir.mkdir(parents=True, exist_ok=True)
    site_dir.mkdir(parents=True, exist_ok=True)

    # ensure the python env is realized
    run(["nix", "build", "--no-link", python_environment])

    for name, path in editables.items():
        make_editable(
            python_environment,
            bin_dir,
            site_dir,
            editables_dir,
            site_packages,
            drvs,
            name,
            path,
        )

    with open(site_dir / "sitecustomize.py", "w") as f:
        f.write(
            f"""import sys
import site

try:
  import _sitecustomize
except ImportError:
  pass

site.addsitedir("{site_dir}")

# addsitedir only supports appending to the path, not prepending.
# As we already include a non-editable instance of each package
# in our pyEnv, those would shadow the editables. So we move
# the editables to the front of sys.path.
for index, path in enumerate(sys.path):
  if path.startswith("{editables_dir}"):
    sys.path.insert(0, sys.path.pop(index))
        """
        )

    print(
        f"""
export PYTHONPATH="{site_dir}:{python_environment / site_packages}:$PYTHONPATH"
export PATH="{bin_dir}:${python_environment}/bin:$PATH"
    """
    )
