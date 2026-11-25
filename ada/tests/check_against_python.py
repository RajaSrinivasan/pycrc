#!/usr/bin/env python3
"""Compare the Ada pycrc port with the original Python implementation.

The script prints a table of every built-in model (the check value of
"123456789"), then checks files, hex strings, a width sweep, and generated
Ada sources. It exits with status 1 on the first mismatch.
"""

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path
from shutil import which

ROOT = Path(__file__).resolve().parents[2]
PYCRC_PY = ROOT / "src" / "pycrc.py"
ADA = ROOT / "bin" / "pycrc"
MODELS = [
    "crc-5", "crc-8", "dallas-1-wire", "crc-12-3gpp", "crc-15", "crc-16",
    "crc-16-usb", "crc-16-modbus", "crc-16-genibus", "crc-16-ccitt",
    "r-crc-16", "kermit", "x-25", "xmodem", "zmodem", "crc-24", "crc-32",
    "crc-32c", "crc-32-mpeg", "crc-32-bzip2", "posix", "jam", "xfer",
    "crc-64", "crc-64-jones", "crc-64-xz",
]
GENERATE_MODELS = [
    "crc-5", "crc-8", "crc-12-3gpp", "crc-16", "xmodem", "crc-32",
    "crc-32c", "crc-64", "crc-64-xz",
]
ALGORITHMS = ["bit-by-bit", "bit-by-bit-fast", "table-driven"]


def run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, check=False, capture_output=True, text=True)


def find_gnatmake() -> str:
    found = which("gnatmake")
    if found:
        return found
    candidates = sorted(
        Path.home().glob(".local/share/alire/toolchains/gnat_native_*/bin/gnatmake")
    )
    if not candidates:
        sys.exit("gnatmake was not found; install a GNAT toolchain (alr toolchain --select)")
    return str(candidates[-1])


def value_of(proc: subprocess.CompletedProcess[str], label: str) -> str:
    if proc.returncode != 0:
        sys.exit(f"{label} failed ({proc.returncode}): {proc.stderr.strip()}")
    return proc.stdout.strip()


def compare(args: list[str], label: str) -> tuple[str, str]:
    python = value_of(run(["python3", str(PYCRC_PY), *args]), "python " + label)
    ada = value_of(run([str(ADA), *args]), "ada " + label)
    if python != ada:
        sys.exit(f"mismatch for {label}: Python {python} Ada {ada}")
    return python, ada


def check_models() -> None:
    print(f"{'model':<16}  {'python':<20}  {'ada':<20}  status")
    for name in MODELS:
        python, ada = compare(["--model", name], name)
        print(f"{name:<16}  {python:<20}  {ada:<20}  ok")
    print(f"{len(MODELS)} models matched on \"123456789\".")


def check_files_and_hex() -> None:
    payload = b"123456789\x00\xffABC"
    for name in MODELS:
        compare(
            ["--model", name, "--check-hexstring", payload.hex()],
            f"{name} hex",
        )
        compare(["--model", name, "--check-string", ""], f"{name} empty")
        with tempfile.NamedTemporaryFile() as handle:
            handle.write(payload)
            handle.flush()
            compare(
                ["--model", name, "--check-file", handle.name],
                f"{name} file",
            )
    print(f"hex string, empty string, and file checks matched for {len(MODELS)} models.")


def check_widths() -> None:
    count = 0
    for width in (1, 7, 8, 9, 15, 31, 32, 33, 63, 64):
        mask = (1 << width) - 1
        for poly in (0x04C11DB7 & mask | 1, 0x8005 & mask | 1):
            for reflect_in in ("true", "false"):
                for reflect_out in ("true", "false"):
                    compare(
                        [
                            "--width", str(width),
                            "--poly", hex(poly),
                            "--reflect-in", reflect_in,
                            "--xor-in", hex(mask),
                            "--reflect-out", reflect_out,
                            "--xor-out", "1",
                            "--check-string", "123456789",
                        ],
                        f"width {width} poly {poly:#x} {reflect_in}/{reflect_out}",
                    )
                    count += 1
    print(f"{count} custom parameter sets matched.")


def check_generated(gnatmake: str) -> None:
    cases = [(model, algo, []) for model in GENERATE_MODELS for algo in ALGORITHMS]
    cases += [
        ("crc-5", "table-driven", ["--table-idx-width", "1"]),
        ("crc-5", "table-driven", ["--table-idx-width", "4"]),
        ("crc-32", "table-driven", ["--table-idx-width", "1"]),
        ("crc-32", "table-driven", ["--table-idx-width", "4"]),
        ("crc-64", "table-driven", ["--table-idx-width", "4"]),
    ]
    with tempfile.TemporaryDirectory(prefix="pycrc-ada.") as tmp:
        work = Path(tmp)
        for model, algo, extra in cases:
            for unit, kind in (
                ("crc.ads", "ads"),
                ("crc.adb", "adb"),
                ("crc_main.adb", "main"),
            ):
                proc = run([
                    str(ADA), "--model", model, "--algorithm", algo, *extra,
                    "--generate", kind, "-o", str(work / unit),
                ])
                if proc.returncode != 0:
                    sys.exit(f"generate {kind} {model} {algo} failed: {proc.stderr}")
            for stale in work.glob("*.o"):
                stale.unlink()
            for stale in work.glob("*.ali"):
                stale.unlink()
            binary = work / "crc_main"
            if binary.exists():
                binary.unlink()
            build = subprocess.run(
                [
                    gnatmake, "-gnat2022", "-gnatwa", "-gnatwe", "-q",
                    "-o", str(binary), "crc_main.adb",
                ],
                cwd=work,
                check=False,
                capture_output=True,
                text=True,
            )
            if build.returncode != 0:
                sys.exit(
                    f"build {model} {algo} {' '.join(extra)} failed:\n{build.stderr}"
                )
            got = value_of(run([str(binary)]), f"run {model} {algo}")
            expect = value_of(
                run(["python3", str(PYCRC_PY), "--model", model, "--check-string", "123456789"]),
                f"python {model}",
            )
            if got != expect:
                sys.exit(
                    f"generated {model} {algo} {' '.join(extra)}: Ada {got} Python {expect}"
                )
            print(f"generated {model:<12} {algo:<16} {' '.join(extra):<24} {got}")
    print(f"{len(cases)} generated programs matched.")


def main() -> None:
    if not ADA.is_file():
        sys.exit(f"missing {ADA}; build with 'alr build' from the repository root")
    gnatmake = find_gnatmake()
    self_check = ROOT / "bin" / "pycrc_self_check"
    if self_check.is_file():
        proc = run([str(self_check)])
        if proc.returncode != 0:
            sys.exit(proc.stdout + proc.stderr)
        print(proc.stdout, end="")
        print()
    check_models()
    print()
    check_files_and_hex()
    check_widths()
    print()
    check_generated(gnatmake)


if __name__ == "__main__":
    main()
