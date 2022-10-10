#! /usr/bin/python3
import logging
import sys
import tempfile
import gc

import atheris
from pyreadr import PyreadrError, LibrdataError

logging.disable(logging.CRITICAL)

with atheris.instrument_imports():
    import pyreadr


EXECS_SINCE_GC = 0
MAX_EXECS_SINCE_GC = 1000

f = tempfile.NamedTemporaryFile()

@atheris.instrument_func
def TestOneInput(data):
    global EXECS_SINCE_GC

    ## The underlying codebase is riddled with memory leaks, this is my attempt to resolve that
    EXECS_SINCE_GC += 1
    if EXECS_SINCE_GC > MAX_EXECS_SINCE_GC:
        gc.collect()
        EXECS_SINCE_GC = 0

    try:
        f.seek(0)
        f.truncate()
        f.write(data)
        f.flush()
        pyreadr.read_r(f.name)
    except (PyreadrError, LibrdataError):
        pass

def main():
    atheris.Setup(sys.argv, TestOneInput)
    atheris.Fuzz()


if __name__ == "__main__":
    main()
