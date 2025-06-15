import argparse
import os
import sys
import subprocess
import tempfile
import json
import shutil
from pathlib import Path

from .lock_file_from_report import lock_file_from_report


__version__ = "1.0.0"


def prepare_venv(venv_path, pip_version, wheel_version, python_interpreter: Path):
    subprocess.run([python_interpreter, "-m", "venv", venv_path], check=True)
    subprocess.run(
        [
            f"{venv_path}/bin/pip",
            "install",
            "--upgrade",
            f"pip=={pip_version}",
            f"wheel=={wheel_version}",
        ],
        check=True,
        stdout=sys.stderr,
        stderr=sys.stderr,
    )
    return venv_path


def is_path_writable(path: Path) -> bool:
    return os.access(path, os.W_OK)


def make_path_writable(path: Path, tmpdir: Path):
    """
    Copy a path to a writable location.

    Args:
        path: The path to check
        tmpdir: Temporary directory to use for copying if needed

    Returns:
        Path: The writable copied path
    """
    # Create a subdirectory in tmpdir for the copy
    copy_dest = tmpdir / path.name
    shutil.copytree(path, copy_dest)

    # Make the copied path writable recursively
    for root, dirs, files in os.walk(copy_dest):
        os.chmod(root, 0o755)
        for file in files:
            os.chmod(os.path.join(root, file), 0o644)

    return copy_dest


def fetch_pip_metadata():
    parser = argparse.ArgumentParser(description="Fetch metadata for python packages")
    # use argparse to parse arguments
    # parse json file from --json-args-file
    parser.add_argument(
        "--json-args-file",
        type=str,
        help="path to json file containing arguments",
        required=True,
    )
    # parse the project root from the second variable
    parser.add_argument(
        "--project-root",
        type=Path,
        help="path to project root",
        required=True,
    )

    # parse the json args from the json-args-file
    args = parser.parse_args()
    with open(args.json_args_file, "r") as f:
        json_args = json.load(f)

    with tempfile.TemporaryDirectory() as home:
        home = Path(home)
        path_mappings = {}  # Track original -> writable path mappings

        venv_path = prepare_venv(
            (home / ".venv").absolute(),
            json_args["pipVersion"],
            json_args["wheelVersion"],
            python_interpreter=json_args["pythonInterpreter"],
        )  # noqa: 501

        flags = json_args["pipFlags"] + [
            "--progress-bar",
            "off",
            "--report",
            str(home / "report.json"),
        ]
        for req in json_args["requirementsList"]:
            if req:
                # if dependency is a path, make sure it is writable
                if Path(req).exists() and not is_path_writable(Path(req)):
                    writable_path = make_path_writable(Path(req), home)
                    path_mappings[str(writable_path)] = str(Path(req))
                    flags.append(str(writable_path))
                else:
                    flags.append(req)
        for req in json_args["requirementsFiles"]:
            if req:
                flags += ["-r", req]

        subprocess.run(
            [
                f"{venv_path}/bin/pip",
                "install",
                "--dry-run",
                "--ignore-installed",
                # "--use-feature=fast-deps",
                *flags,
            ],
            check=True,
            stdout=sys.stderr,
            stderr=sys.stderr,
        )
        with open(home / "report.json", "r") as f:
            report = json.load(f)

        with open(os.getenv("out"), "w") as f:
            lock = lock_file_from_report(
                report,
                project_root=args.project_root,
                temp_dir=home,
                path_mappings=path_mappings,
            )
            json.dump(lock, f, indent=2, sort_keys=True)
