# Tests

Offline checks run with `texlua` (Lua 5.3) against stubbed game APIs; they are not in the release zip.

    cd tests
    for t in *_test.lua; do texlua "$t" ..; done      # each prints ok / FAIL lines
    for m in plain oldguide oldtracker fakeguide noauct; do texlua smoke2.lua .. $m; done
    texlua orphans_test.lua .. fakeguide
    python3 globals_audit.py ..

`more_test.lua` prints a few known harmless "attempt to index a function value (local 'header')" lines from its stubs.
