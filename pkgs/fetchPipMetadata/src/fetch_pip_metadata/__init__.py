import argparse
import os
import sys
import subprocess
import tempfile
import json
import dateutil.parser
from pathlib import Path

from .lock_file_from_report import lock_file_from_report
from .pypi_proxy import PypiProxy


__version__ = "1.0.0"


def get_max_date(snapshot_date):
    try:
        return int(snapshot_date)
    except ValueError:
        return dateutil.parser.parse(snapshot_date)


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

        if json_args.get("pypiSnapshotDate", False):
            print(
                f"selected maximum release date for python packages: {get_max_date(json_args['pypiSnapshotDate'])}",  # noqa: E501
                file=sys.stderr,
            )
            proxy = PypiProxy(
                executable=json_args["mitmProxy"],
                args=[
                    "--ignore-hosts",
                    ".*files.pythonhosted.org.*",
                    "--script",
                    json_args["filterPypiResponsesScript"],
                ],
                env={"pypiSnapshotDate": json_args["pypiSnapshotDate"], "HOME": home},
            )
        else:
            proxy = False

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
        if proxy:
            flags += [
                "--proxy",
                f"https://localhost:{proxy.port}",
                "--cert",
                proxy.cafile,
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
        if proxy:
            proxy.kill()

        with open(home / "report.json", "r") as f:
            report = json.load(f)

        with open(os.getenv("out"), "w") as f:
            lock = lock_file_from_report(report, project_root=args.project_root)
            json.dump(lock, f, indent=2, sort_keys=True)
