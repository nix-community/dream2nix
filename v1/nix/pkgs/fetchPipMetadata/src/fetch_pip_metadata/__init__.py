import os
import sys
import re
import argparse
import subprocess
import tempfile
import json
from pathlib import Path

from .lock_file_from_report import lock_file_from_report
from .pypi_proxy import PypiProxy


__version__ = "1.0.0"


def prepare_venv(venv_path, pip_version, wheel_version):
    subprocess.run([sys.executable, "-m", "venv", venv_path], check=True)
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


def fetch_pip_metadata(args):
    with tempfile.TemporaryDirectory() as home, PypiProxy(home, args) as proxy:
        home = Path(home)

        print(
            f"selected maximum release date for python packages: {get_max_date(args.pypi_snapshot_date)}",  # noqa: E501
            file=sys.stderr,
        )

        venv_path = prepare_venv(
            (home / ".venv").absolute(), args.pip_version, args.wheel_version
        )  # noqa: 501

        flags = args.pip_flags + [
            "--proxy",
            f"https://localhost:{proxy.port}",
            "--progress-bar",
            "off",
            "--cert",
            proxy.cafile,
            "--report",
            str(home / "report.json"),
        ]
        for req in args.requirements_list:
            if req:
                flags.append(req)
        for req in args.requirements_files:
            if req:
                flags += ["-r", req]

        subprocess.run(
            [
                f"{venv_path}/bin/pip",
                "install",
                "--dry-run",
                "--ignore-installed",
                *flags,
            ],
            check=True,
            stdout=sys.stderr,
            stderr=sys.stderr,
        )

        with open(home / "report.json", "r") as f:
            report = json.load(f)

        with open(args.out_file, "w") as f:
            lock = lock_file_from_report(report)
            json.dump(lock, f, indent=2, sort_keys=True)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config-file", help="Load arguments from a JSON file.")
    parser.add_argument(
        "--out-file",
        help="path to write the lock file to, defaults to $out",
        default=os.getenv("out"),
    )
    parser.add_argument("--filter-pypi-responses-script")
    parser.add_argument("--mitm-proxy")
    parser.add_argument("--pip-flags", nargs="*", default=[])
    parser.add_argument("--pip-version")
    parser.add_argument("--pypi-snapshot-date")
    parser.add_argument("-R", "--requirements-files", action="append", default=[])
    parser.add_argument("-r", "--requirements-list", action="append", default=[])
    parser.add_argument("--wheel-version")

    args = parser.parse_args()
    if args.config_file:
        with open(args.config_file, "r") as f:
            re_camel_to_snake_case = re.compile(r"(?<!^)(?=[A-Z])")
            new = {
                re_camel_to_snake_case.sub("_", name).lower(): value
                for name, value in json.load(f).items()
            }
            args = parser.parse_args(namespace=argparse.Namespace(**new))
    return args


def main():
    args = parse_args()
    fetch_pip_metadata(args)
