pycrc
=====

[pycrc](https://pycrc.org) is a free, easy to use Cyclic Redundancy Check (CRC)
calculator and source code generator. The original tool is written in Python
and generates C. This repository also contains an Ada port that calculates
the same CRCs and generates Ada packages instead of C.


System Requirements
-------------------

Python 3.8 or newer is required to run pycrc.
The last version compatible with Python 2 is v0.9.x.

Running pycrc
-------------

This program doesn't need to be installed to be run. The script can be
executed from the source directory.
Simply call the python interpreter with the script as parameter:

    python3 src/pycrc.py [options]

Installation
------------

Install pycrc (if required) using pip:

    python3 -m pip install pycrc

or apt (on Debian 13 and later, Ubuntu 23.10 and later, and
derivatives):

    sudo apt install pycrc

Either of these will install a `pycrc` binary in the path.


Ada port
--------

The Ada sources live in `ada/src` and are built with [Alire](https://alire.ada.dev/)
and GNAT. The Python implementation is unchanged and remains the C code
generator; the Ada tool is a second front end with the same models and the
same three algorithms.

### Build

Install Alire, select a current GNAT toolchain, and build from the
repository root:

    alr toolchain --select
    alr build

`alr build` produces `bin/pycrc` and `bin/pycrc_self_check`. The project
file is `pycrc.gpr`.

### Calculate a CRC

The command line follows pycrc. With no explicit action, the tool checksums
the string `123456789`:

    bin/pycrc --model crc-32
    bin/pycrc --model crc-32 --check-string "The quick brown fox"
    bin/pycrc --model crc-16 --check-hexstring 313233343536373839
    bin/pycrc --model crc-32c --check-file /etc/hostname

A model is either a built-in name (`--model`) or the six Rocksoft parameters
`--width`, `--poly`, `--reflect-in`, `--xor-in`, `--reflect-out`, and
`--xor-out`. `--algorithm` accepts `bit-by-bit` (`bbb`), `bit-by-bit-fast`
(`bbf`), `table-driven` (`tbl`), and `all` (the default). `all` runs every
algorithm and stops if they disagree. `-v` prints the parameter block.

`bin/pycrc_self_check` recomputes every built-in model and checks the three
algorithms against the catalogue value of `123456789`.

### Generate Ada

Where pycrc writes C, this tool writes an Ada package. The CRC type is a
modular type of the model width. Pick one algorithm:

    bin/pycrc --model crc-32 --algorithm table-driven --generate ads -o crc.ads
    bin/pycrc --model crc-32 --algorithm table-driven --generate adb -o crc.adb
    bin/pycrc --model crc-32 --algorithm table-driven --generate main -o crc_main.adb
    gnatmake -gnat2022 crc_main.adb
    ./crc_main

`--generate` accepts `ads` (specification), `adb` (body), `main` (a small
driver), and `table` (the lookup table only). `h`, `c`, and `c-main` are
accepted as aliases of `ads`, `adb`, and `main`; they still emit Ada.
`--symbol-prefix` sets the package name (default `CRC`). The driver
checksums `123456789`, or the first command-line argument when one is given.

The generated package has `Init`, `Update`, `Finalize`, and `Calculate`:

    CRC : CRC_Type := CRC.Init;
    CRC := CRC.Update (CRC, Data);
    CRC := CRC.Finalize (CRC);

### Tests

With the project built and `python3` available:

    python3 ada/tests/check_against_python.py

That compares every built-in model with `python3 src/pycrc.py`, checks files
and hex strings, sweeps widths from 1 to 64 bits, then compiles generated
Ada for several models and algorithms and runs it.

### Differences from the Python tool

*   Register widths above 64 bits are rejected. Every model shipped with
    pycrc fits in 64 bits.
*   `--slice-by` is recognized, then ignored with a warning. Generated
    table code reads one byte at a time. The CRC value is unchanged.
*   Partially specified models (pycrc's C `cfg` struct, filled in at run
    time) are not generated. Width, polynomial, reflections, and xor values
    must all be known.
*   `--std` and `--crc-type` are C options. They are accepted and ignored.
*   `--symbol-prefix` is the Ada package name, default `CRC`, rather than
    the C prefix `crc_`.
*   Fatal option errors are printed as `pycrc: error:` and the program
    exits with status 1. The Python tool prints those messages as warnings
    before exiting.
*   File checksums use the bit-by-bit-fast algorithm, which is what the
    Python implementation does as well.

Getting help
------------

If you are new to pycrc and want to generate C code, start with
[the tutorial](https://pycrc.org/tutorial.html).

The [pycrc manual page](https://pycrc.org/pycrc.html) explains the command line
options in some detail and also gives some more examples how to use pycrc.

If you have found a bug in pycrc or want to request a feature please take the
time and submit it to the
[issue tracker](https://github.com/tpircher/pycrc/issues).
Thanks for your help.

Also see the [frequently asked questions](https://pycrc.org/faq.html).


Feedback
--------

If you like pycrc, let me know and drop me a note. If you don't like pycrc let
me know what you don't like and why.
If you want some idea how to say thanks for this software, please have a look
[here](https://www.tty1.net/say-thanks_en.html).


Copyright of the generated source code
--------------------------------------

The MIT licence allows commercial use of the source and the output of the
program. But since I got asked on occasion whether the generated code is
encumbered by the copyright of the author, I give my view on this:

The code generated by pycrc is not considered a substantial portion of the
software, therefore the licence does not cover the generated code; the
author of pycrc will not claim any copyright on the generated code.
