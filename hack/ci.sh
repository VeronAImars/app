#!/usr/bin/env bash
# Copyright The k3sm Authors.
# SPDX-License-Identifier: Apache-2.0
#
# ci.sh -- the k3sm app repo's gate. Run from anywhere; it works on a lone clone.
#
#   0. the package declares no dependencies
#   1. swift build
#   2. swift test (the status decoder, the visibility rule, role detection)
#   3. hack/build-app.sh into a temp dir (builds, signs and verifies the bundle)
#   4. every .swift file carries the Apache-2.0 header
#   5. every file under .github/workflows/ is dormant (fully commented out)
#   6. the vendored status fixtures match a sibling k3sm checkout, when one exists
set -euo pipefail
cd "$(dirname "$0")/.."

# The Command Line Tools ship the swift-testing macro plugin in a directory
# SwiftPM does not search on its own; point the compiler at it. A full Xcode
# toolchain finds it without help, so this applies only when the plugin exists.
TEST_FLAGS=()
devdir="$(xcode-select -p 2>/dev/null || true)"
plugdir="$devdir/usr/lib/swift/host/plugins/testing"
if [ -n "$devdir" ] && [ -f "$plugdir/libTestingMacros.dylib" ]; then
	TEST_FLAGS=(-Xswiftc -plugin-path -Xswiftc "$plugdir")
fi

echo "==> no third-party dependencies"
# The package depends on nothing outside the toolchain, which is also why there
# is no Package.resolved to commit: SwiftPM writes one only when it has pins.
deps="$(swift package show-dependencies 2>&1)"
printf '%s\n' "$deps" | grep -q '^No external dependencies found' \
	|| { echo "FAIL: the package must not declare dependencies:"; printf '%s\n' "$deps"; exit 1; }
[ ! -e Package.resolved ] || grep -q '"pins" : \[\s*\]' Package.resolved \
	|| { echo "FAIL: Package.resolved carries pins"; exit 1; }
echo "    ok"

echo "==> swift build"
swift build

echo "==> swift test"
swift test "${TEST_FLAGS[@]}"

echo "==> hack/build-app.sh (temp dir)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
bash hack/build-app.sh "$tmp/out"
[ -d "$tmp/out/k3sm.app" ] || { echo "FAIL: bundle not produced"; exit 1; }

echo "==> license headers (.swift)"
header="hack/boilerplate/boilerplate.swift.txt"
n="$(wc -l < "$header" | tr -d ' ')"
missing=0
while IFS= read -r -d '' f; do
	start=1
	# Package.swift must keep the tools-version comment on line 1.
	if head -n 1 "$f" | grep -q '^// swift-tools-version'; then start=2; fi
	if ! tail -n "+$start" "$f" | head -n "$n" | cmp -s - "$header"; then
		echo "    missing header: $f"; missing=1
	fi
done < <(find . -name '*.swift' -not -path './.build/*' -not -path './.git/*' -print0)
[ "$missing" = 0 ] || { echo "FAIL: add the header in $header to the files above"; exit 1; }
echo "    ok"

echo "==> workflows dormant (.github/workflows)"
# A workflow file is dormant iff it has no line that is neither blank nor a
# comment. Every file counts, whatever its name or extension. Deliberately
# strict: a stray '---' or a byte-order mark makes a file active.
active=0
if [ -d .github/workflows ]; then
	while IFS= read -r -d '' f; do
		if grep -qEv '^[[:space:]]*(#|$)' "$f"; then
			echo "    ACTIVE: $f"; active=1
		fi
	done < <(find .github/workflows -type f -print0)
fi
[ "$active" = 0 ] || { echo "FAIL: workflows must stay fully commented out"; exit 1; }
# Red-path check, so the predicate above cannot pass vacuously.
printf '# off\non: push\n' > "$tmp/active.yml"
printf '# off\n\n  # still off\n' > "$tmp/dormant.yml"
grep -qEv '^[[:space:]]*(#|$)' "$tmp/active.yml" || { echo "FAIL: predicate missed an active file"; exit 1; }
! grep -qEv '^[[:space:]]*(#|$)' "$tmp/dormant.yml" || { echo "FAIL: predicate flagged a dormant file"; exit 1; }
echo "    ok"

echo "==> status fixtures (vendored from k3sm)"
# k3sm owns the status JSON contract and its golden fixtures. The copies under
# Tests/K3smStatusTests/Fixtures must match byte for byte. K3SM_DIR names a k3sm
# checkout; a sibling ../k3sm is used when present. A lone clone skips this.
k3sm_dir="${K3SM_DIR:-../k3sm}"
golden="$k3sm_dir/pkg/status/testdata"
if [ -d "$golden" ]; then
	drift=0
	for f in Tests/K3smStatusTests/Fixtures/status_*.json; do
		if ! cmp -s "$f" "$golden/$(basename "$f")"; then
			echo "    DRIFT: $f differs from $golden/$(basename "$f")"; drift=1
		fi
	done
	[ "$drift" = 0 ] || { echo "FAIL: re-copy the fixtures from $golden"; exit 1; }
	echo "    ok (against $golden)"
else
	echo "    skipped: no k3sm checkout at $k3sm_dir (set K3SM_DIR)"
fi

echo "app ci: green"
