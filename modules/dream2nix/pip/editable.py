import os
import sys
import json
import shutil
import subprocess
import configparser
import importlib
from contextlib import redirect_stdout
from textwrap import dedent
from pathlib import Path
from tempfile import TemporaryDirectory

import tomli


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
    sources,
    name,
    path,
    root_dir,
):
    normalized_name = name.replace("-", "_")
    editable_dir = editables_dir / name
    if editable_dir.exists():
        relative_editable_dir = os.path.relpath(editable_dir, root_dir)
        print(
            f"Skipping existing editable source in {relative_editable_dir}",
            file=sys.stderr,
        )
        return
    source = source_for(path, sources)
    make_editable_source(editable_dir, site_dir, normalized_name, source)
    make_pth(site_dir, editable_dir, normalized_name)
    if str(source).endswith(".whl"):
        editable_dist_info = make_dist_info_for_wheel(site_dir, normalized_name, source)
    else:
        editable_dist_info = make_dist_info(
            site_dir, editable_dir, site_packages, normalized_name
        )
    make_entrypoints(python_environment, bin_dir, editable_dist_info)


def source_for(path, sources):
    # If a(n absolute) path is found, we use that.
    if isinstance(path, str) and os.path.isabs(path):
        return path
    # For the root package, we default to as symlink to this projects root
    elif name == root_name:
        return root_dir
    # For all others, we copy mkDerivation.src from /nix/store.
    return sources[name]


def make_editable_source(editable_dir, site_dir, normalized_name, source):
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


def make_dist_info_for_wheel(site_dir, normalized_name, source):
    run(
        [
            f"{unzip}/bin/unzip",
            "-q",
            "-d",
            str(site_dir),
            source,
            f"{normalized_name}*.dist-info/*",
        ]
    )
    dist_info_path = next(site_dir.glob(f"{normalized_name}*.dist-info"))
    write_direct_url_json(dist_info_path, source)
    return dist_info_path


# make_dist_info based on importlib.metadata instead of copying the .dist-info from the non-editable derivation
def make_dist_info(site_dir, editable_dir, site_packages, normalized_name):
    os.chdir(editable_dir)
    pyproject_file = editable_dir / "pyproject.toml"
    if pyproject_file.exists():
        with open(pyproject_file, "rb") as f:
            pyproject = tomli.load(f)
        build_system = (
            pyproject["build-system"] if "build-system" in pyproject else "setuptools"
        )
        build_backend = (
            build_system["build-backend"]
            if "build-backend" in build_system
            else "setuptools.build_meta.__legacy__"
        )
        build_system_import = (
            build_backend
            if build_backend != "setuptools.build_meta.__legacy__"
            else "setuptools.build_meta"
        )
    else:
        build_system_import = "setuptools.build_meta"
    backend = importlib.import_module(build_system_import)
    with redirect_stdout(open(os.devnull, "w")), TemporaryDirectory() as tmp_dir:
        if hasattr(backend, "prepare_metadata_for_build_editable"):
            # redirect stdout to stderr to avoid leaking the metadata to the user
            dist_info_name = backend.prepare_metadata_for_build_editable(tmp_dir)
        else:
            dist_info_name = backend.prepare_metadata_for_build_wheel(tmp_dir)
        # copy the dist-info to the site-packages
        shutil.copytree(Path(tmp_dir) / dist_info_name, site_dir / dist_info_name)
    dist_info_path = site_dir / dist_info_name
    for egg_info in site_dir.glob("*.egg-info"):
        shutil.rmtree(egg_info)
    write_direct_url_json(dist_info_path, editable_dir)
    return dist_info_path


def write_direct_url_json(dist_info_path, editable_dir):
    with open(dist_info_path / "direct_url.json", "w") as f:
        json.dump(
            {"url": f"file://{editable_dir}", "dir_info": {"editable": True}},
            f,
            indent=2,
        )


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


def is_state_valid(args, dream2nix_python_dir):
    if not (dream2nix_python_dir / "editable-args.json").exists():
        return False
    with open(dream2nix_python_dir / "editable-args.json", "r") as f:
        old_args = json.load(f)
    return old_args == args


if __name__ == "__main__":
    with open(sys.argv[1], "r") as f:
        args = json.load(f)
    # print(json.dumps(args, indent=2), file=sys.stderr)
    unzip = args["unzip"]
    find_root = args["findRoot"]
    python_environment = Path(args["pyEnv"])
    root_name = args["rootName"]
    site_packages = args["sitePackages"]
    sources = args["sources"]
    editables = args["editables"]

    # directories to use
    root_dir = Path(run([find_root]))
    dream2nix_python_dir = root_dir / ".dream2nix" / "python"
    editables_dir = dream2nix_python_dir / "editables"
    bin_dir = dream2nix_python_dir / "bin"
    site_dir = dream2nix_python_dir / "site"

    # remove dream2nix python dir if args changed
    if not is_state_valid(args, dream2nix_python_dir):
        if dream2nix_python_dir.exists():
            shutil.rmtree(dream2nix_python_dir)

    bin_dir.mkdir(parents=True, exist_ok=True)
    editables_dir.mkdir(parents=True, exist_ok=True)
    site_dir.mkdir(parents=True, exist_ok=True)

    for name, path in editables.items():
        if path:
            make_editable(
                python_environment,
                bin_dir,
                site_dir,
                editables_dir,
                site_packages,
                sources,
                name,
                path,
                root_dir,
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

    with open(dream2nix_python_dir / "editable-args.json", "w") as f:
        json.dump(args, f, indent=2)
