#!/usr/bin/env bash
# Hermetic package-consumer proof for the optional APNs/Pigeon boundary.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture_root="$repo_root/test/fixtures/apns_consumer"
work_root=$(mktemp -d "${TMPDIR:-/tmp}/chimeway-apns.XXXXXX")
artifact_root="$work_root/archive"

cleanup() {
  if [[ "${CHIMEWAY_APNS_KEEP_TEMP:-}" != "1" ]]; then
    rm -rf "$work_root"
  else
    printf 'verify.apns temporary root retained at %s\n' "$work_root" >&2
  fi
}
trap cleanup EXIT INT TERM

fail() { echo "verify.apns: $*" >&2; exit 1; }

[[ -d "$fixture_root" ]] || fail "consumer fixture is missing"
[[ "$work_root" == "${TMPDIR:-/tmp}"/* ]] || fail "temporary directory escaped TMPDIR"
mkdir -p "$artifact_root"

(cd "$repo_root" && MIX_ENV=prod mix hex.build --unpack --output "$artifact_root" >/dev/null)
package_path=$(find "$artifact_root" -mindepth 1 -maxdepth 2 -name mix.exs -print -quit | xargs -r dirname)
[[ -n "$package_path" && -f "$package_path/mix.exs" ]] || fail "unpacked package mix.exs is missing"

focus="${CHIMEWAY_APNS_FOCUS:-}"
[[ -z "$focus" || "$focus" == "bridge_to_cas" || "$focus" == "runtime_success" ]] || fail "unknown CHIMEWAY_APNS_FOCUS value: $focus"

run_consumer() {
  local mode="$1"
  local consumer_root="$work_root/$mode"
  local output="$work_root/$mode.log"

  cp -R "$fixture_root" "$consumer_root"

  if [[ "$mode" == "enabled" ]]; then
    (
      cd "$consumer_root"
      cp "$fixture_root/apns-enabled.lock" mix.lock
      CHIMEWAY_PACKAGE_PATH="$package_path" CHIMEWAY_APNS_ENABLED=1 MIX_ENV=test mix deps.get --check-locked
      CHIMEWAY_PACKAGE_PATH="$package_path" CHIMEWAY_APNS_ENABLED=1 MIX_ENV=test mix deps.tree >"$output"
      grep -Eq 'pigeon.*2\.0\.1' "$output" || fail "enabled fixture did not resolve pigeon 2.0.1"
      grep -Eq 'httpoison.*3\.0\.0' "$output" || fail "enabled fixture did not resolve httpoison 3.0.0"
      grep -Eq 'hackney.*4\.7\.4' "$output" || fail "enabled fixture did not resolve hackney 4.7.4"
      grep -Eq 'pigeon.*2\.0\.1' mix.lock || fail "enabled fixture lock does not pin pigeon 2.0.1"
      grep -Eq 'httpoison.*3\.0\.0' mix.lock || fail "enabled fixture lock does not pin httpoison 3.0.0"
      grep -Eq 'hackney.*4\.7\.4' mix.lock || fail "enabled fixture lock does not pin hackney 4.7.4"
      CHIMEWAY_PACKAGE_PATH="$package_path" CHIMEWAY_APNS_ENABLED=1 MIX_ENV=test mix hex.audit >>"$output"
      CHIMEWAY_PACKAGE_PATH="$package_path" CHIMEWAY_APNS_ENABLED=1 MIX_ENV=test mix compile --warnings-as-errors >>"$output"
      if [[ "$focus" == "bridge_to_cas" ]]; then
        CHIMEWAY_PACKAGE_PATH="$package_path" CHIMEWAY_APNS_ENABLED=1 MIX_ENV=test \
          mix test --only apns_bridge_to_cas >>"$output"
      elif [[ "$focus" == "runtime_success" ]]; then
        CHIMEWAY_PACKAGE_PATH="$package_path" CHIMEWAY_APNS_ENABLED=1 MIX_ENV=test \
          mix test --only apns_runtime_success >>"$output"
      else
        CHIMEWAY_PACKAGE_PATH="$package_path" CHIMEWAY_APNS_ENABLED=1 MIX_ENV=test mix test >>"$output"
      fi
    )
  else
    (
      cd "$consumer_root"
      CHIMEWAY_PACKAGE_PATH="$package_path" MIX_ENV=test mix deps.get
      CHIMEWAY_PACKAGE_PATH="$package_path" MIX_ENV=test mix deps.tree >"$output"
      ! grep -qi pigeon "$output" || fail "disabled fixture dependency tree contains pigeon"
      ! grep -Eqi 'httpoison|hackney' "$output" || fail "disabled fixture dependency tree contains enabled HTTP dependencies"
      ! grep -qi pigeon mix.lock || fail "disabled fixture lock contains pigeon"
      ! grep -Eqi 'httpoison|hackney' mix.lock || fail "disabled fixture lock contains enabled HTTP dependencies"
      CHIMEWAY_PACKAGE_PATH="$package_path" MIX_ENV=test mix compile --warnings-as-errors >>"$output"
      CHIMEWAY_PACKAGE_PATH="$package_path" MIX_ENV=test mix test >>"$output"
    )
  fi

  ! grep -q 'fixture-token-never-emitted' "$output" || fail "consumer output leaked the token sentinel"
}

if [[ "$focus" == "bridge_to_cas" || "$focus" == "runtime_success" ]]; then
  run_consumer enabled
else
  run_consumer disabled
  run_consumer enabled
fi

# This is an intentionally narrow proof claim: it describes a synthetic sandbox
# handoff only, never Apple acceptance, device display, or protected-open proof.
printf '%s\n' '{"provider":"apns","outcome":"provider_accepted","environment":"sandbox","proof":"not_live_not_device_not_open"}'
