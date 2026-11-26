#!/usr/bin/env python3
"""Run GNATprove on each Ada unit, then on a sample of generated packages.

Silver mode is absence of run-time errors. Unproved checks fail this script.
"""

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ADA = ROOT / "bin" / "pycrc"

# Body file, human description of SPARK_Mode.
UNITS = [
    ("pycrc.adb", "On; Die, Warn, Hex_Image, To_Bytes Off"),
    ("pycrc-algorithms.adb", "On"),
    ("pycrc-models.adb", "On; Names Off"),
    ("pycrc-options.adb", "Off"),
    ("pycrc-codegen.adb", "Off"),
    ("pycrc-main.adb", "Off"),
    ("pycrc-self_check.adb", "Off"),
]

GENERATED = [
    ("crc-32", "table-driven", []),
    ("crc-8", "bit-by-bit", []),
    ("crc-16", "bit-by-bit-fast", []),
    ("crc-5", "table-driven", ["--table-idx-width", "4"]),
    ("xmodem", "table-driven", []),
]

PROVE = [
    "--mode=silver",
    "--level=2",
    "--timeout=30",
    "--checks-as-errors=on",
]


def run(cmd: list[str], cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd, cwd=cwd, check=False, capture_output=True, text=True
    )


def prove(project: Path, unit: str, cwd: Path) -> subprocess.CompletedProcess[str]:
    return run(
        ["alr", "-C", str(ROOT), "exec", "--", "gnatprove", "-P", str(project),
         "-u", unit, *PROVE],
        cwd=cwd,
    )


def outcome(proc: subprocess.CompletedProcess[str], mode: str) -> str:
    text = proc.stdout + proc.stderr
    if proc.returncode != 0 or "might fail" in text or "gnatprove: error" in text:
        unproved = text.count("might fail")
        if unproved == 0:
            unproved = text.count("gnatprove: error") or 1
        return f"unproved ({unproved})"
    if mode.startswith("Off"):
        return "not analyzed"
    return "proved"


def main() -> None:
    if not ADA.is_file():
        sys.exit(f"missing {ADA}; run alr build first")

    print(f"{'unit':<24}  {'SPARK_Mode':<42}  result")
    failed = False
    for unit, mode in UNITS:
        proc = prove(ROOT / "pycrc.gpr", unit, ROOT)
        result = outcome(proc, mode)
        print(f"{unit:<24}  {mode:<42}  {result}")
        if result.startswith("unproved"):
            failed = True
            sys.stderr.write(proc.stdout + proc.stderr)

    print()
    print("generated packages")
    for model, algo, extra in GENERATED:
        label = f"{model} {algo} {' '.join(extra)}".strip()
        with tempfile.TemporaryDirectory(prefix="pycrc-spark.") as tmp:
            work = Path(tmp)
            (work / "obj").mkdir()
            generated = True
            for kind, name in (("ads", "crc.ads"), ("adb", "crc.adb")):
                gen = run([
                    str(ADA), "--model", model, "--algorithm", algo, *extra,
                    "--generate", kind, "-o", str(work / name),
                ])
                if gen.returncode != 0:
                    print(f"{label:<40}  On                                         unproved (generator failed)")
                    sys.stderr.write(gen.stderr)
                    failed = True
                    generated = False
                    break
            if not generated:
                continue
            (work / "gen.gpr").write_text(
                "project Gen is\n"
                "   for Source_Dirs use (\".\");\n"
                "   for Object_Dir use \"obj\";\n"
                "   for Main use ();\n"
                "   package Compiler is\n"
                "      for Default_Switches (\"Ada\") use (\"-gnat2022\");\n"
                "   end Compiler;\n"
                "end Gen;\n"
            )
            proc = prove(work / "gen.gpr", "crc.adb", work)
            result = outcome(proc, "On")
            print(f"{label:<40}  On                                         {result}")
            if result.startswith("unproved"):
                failed = True
                sys.stderr.write(proc.stdout + proc.stderr)

    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
