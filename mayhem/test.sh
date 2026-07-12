#!/usr/bin/env bash
#
# mayhem/test.sh — RUN pyreadr's own upstream functional test suite (already built in-place by
# mayhem/build.sh) and emit a CTRF summary. Does NOT compile.
#
# This is the project's real behavioral suite (unittest with assertEqual / DataFrame.equals /
# known-answer checks over librdata reads+writes) — the same tests upstream runs in CI
# (tests/test_basic.py + tests/test_http_integration.py). A no-op / exit(0) sabotage of librdata
# makes read_r() return wrong data and FAILS these assertions, so the oracle is not reward-hackable.
# (tests/test_version.py is a dev-only version-string check that imports the Sphinx docs conf and
# is NOT part of upstream CI; it exercises no librdata behavior, so it is intentionally excluded.)
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
cd "$SRC"

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

# Fail loudly if build.sh never produced the extension (test.sh must not compile it).
if ! python3 -c "import pyreadr, pyreadr.librdata" 2>/dev/null; then
  echo "test.sh: pyreadr extension not built — mayhem/build.sh must build it" >&2
  emit_ctrf "python-unittest" 0 1
  exit 1
fi
if [ ! -x /mayhem/read-kat ]; then
  echo "test.sh: /mayhem/read-kat missing — mayhem/build.sh must build it" >&2
  emit_ctrf "python-unittest" 0 1
  exit 1
fi

# --- Native librdata known-answer test (behavioral; output-asserted) --------------------
# one.Rds is a data frame of 7 columns x 6 rows. A neutered/no-op librdata (or the sabotage
# LD_PRELOAD) can neither emit this line nor emit the right numbers, so this FAILS.
kat_pass=0; kat_fail=0
kat_out="$(/mayhem/read-kat "$SRC/test_data/basic/one.Rds" 2>/dev/null || true)"
echo "read-kat: $kat_out"
if [ "$kat_out" = "KAT ncols=7 nrows=6" ]; then kat_pass=1; else kat_fail=1; fi

# Run each upstream unittest module AS A SCRIPT (the way upstream/CI invokes it — the module
# only imports pyreadr under `if __name__ == '__main__'`), capture unittest's summary, and sum
# the real pass/fail/skip counts across modules.
LOG="$(mktemp)"
: > "$LOG"
for t in tests/test_basic.py tests/test_http_integration.py; do
  echo "=== $t ===" | tee -a "$LOG"
  python3 "$t" --inplace >>"$LOG" 2>&1 || true
done
cat "$LOG"

read -r passed failed skipped < <(python3 - "$LOG" <<'PY'
import re, sys
txt = open(sys.argv[1]).read()
total = sum(int(m) for m in re.findall(r'^Ran (\d+) test', txt, re.M))
fails = sum(int(m) for m in re.findall(r'failures=(\d+)', txt))
errs  = sum(int(m) for m in re.findall(r'errors=(\d+)', txt))
skips = sum(int(m) for m in re.findall(r'skipped=(\d+)', txt))
# A module with no summary line at all means it crashed on import -> count as a failure.
mods_run = len(re.findall(r'^Ran \d+ test', txt, re.M))
mods_exp = txt.count('=== tests/')
crashed  = max(0, mods_exp - mods_run)
failed = fails + errs + crashed
passed = total - fails - errs - skips
print(passed, failed, skips)
PY
)
: "${passed:=0}" "${failed:=1}" "${skipped:=0}"
rm -f "$LOG"

passed=$(( passed + kat_pass ))
failed=$(( failed + kat_fail ))

emit_ctrf "python-unittest+librdata-kat" "$passed" "$failed" "$skipped"
