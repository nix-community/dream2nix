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


def run_pip(home, venv, proxy, args):
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
            f"{venv}/bin/pip",
            "install",
            "--dry-run",
            "--ignore-installed",
            *flags,
        ],
        check=True,
        stdout=sys.stderr,
        stderr=sys.stderr,
    )


def fetch_pip_metadata(args):
    with tempfile.TemporaryDirectory() as home:
        home = Path(home)

        if args.from_report:
            with open(args.from_report, "r") as f:
                report = json.load(f)
        else:
            venv = prepare_venv(
                (home / ".venv").absolute(), args.pip_version, args.wheel_version
            )
            with PypiProxy(home, args) as proxy:
                run_pip(home, venv, proxy, args)

            with open(home / "report.json", "r") as f:
                report = json.load(f)

        if args.report_out_file:
            with open(args.report_out_file, "w") as f:
                json.dump(report, f, indent=2)

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
    parser.add_argument(
        "--report-out-file", help="save the raw pip report to this file"
    )
    parser.add_argument(
        "--from-report",
        help="skip ´pip install´ and generate a lock file from an existing report",
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
