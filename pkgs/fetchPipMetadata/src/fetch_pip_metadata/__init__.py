import argparse
import os
import sys
import subprocess
import tempfile
import json
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
            lock = lock_file_from_report(report, project_root=args.project_root)
            json.dump(lock, f, indent=2, sort_keys=True)
