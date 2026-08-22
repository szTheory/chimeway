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
[[ -z "$focus" || "$focus" == "bridge_to_cas" || "$focus" == "runtime_success" || "$focus" == "strict_compile_probe" || "$focus" == "warning_gate_mutation" ]] || fail "unknown CHIMEWAY_APNS_FOCUS value: $focus"

run_consumer() {
  local mode="$1"
  local consumer_root="$work_root/$mode"
  local output="$work_root/$mode.log"
  local tree_output="$work_root/$mode-tree.log"
  local consumer_lib_path="$consumer_root/_build/test/lib"
  local dependency_erl_libs=""
  local dependency_path

  cp -R "$fixture_root" "$consumer_root"
  rm -rf "$consumer_root/_build" "$consumer_root/deps" "$consumer_root/mix.lock"

  if [[ "$mode" == "enabled" ]]; then
    (
      cd "$consumer_root"
      cp "$fixture_root/apns-enabled.lock" mix.lock
      CHIMEWAY_PACKAGE_PATH="$package_path" CHIMEWAY_APNS_ENABLED=1 MIX_ENV=test mix deps.get --check-locked
      CHIMEWAY_PACKAGE_PATH="$package_path" CHIMEWAY_APNS_ENABLED=1 MIX_ENV=test mix deps.compile |& tee -a "$output"
      [[ -d "$consumer_lib_path/ecto/ebin" ]] || fail "prepared consumer Ecto code path is missing"

      for dependency_path in "$consumer_lib_path"/*; do
        [[ -d "$dependency_path/ebin" ]] || continue
        [[ "$dependency_path" != "$consumer_lib_path/chimeway" ]] || continue
        dependency_erl_libs="${dependency_erl_libs:+$dependency_erl_libs:}$dependency_path"
      done

      [[ -n "$dependency_erl_libs" ]] || fail "prepared consumer dependency code paths are missing"
      [[ ":$dependency_erl_libs:" != *":$consumer_lib_path/chimeway:"* ]] || fail "Chimeway ebin leaked into strict compiler code path"

      assert_no_chimeway_redefinition() {
        ! grep -q 'redefining module Chimeway' "$output" || fail "strict compiler emitted Chimeway module redefinition warnings"
      }

      if [[ "$focus" == "strict_compile_probe" ]]; then
        ERL_LIBS="$dependency_erl_libs" CHIMEWAY_PACKAGE_PATH="$package_path" CHIMEWAY_APNS_ENABLED=1 MIX_ENV=test \
          mix cmd --cd "$package_path" mix compile --force-elixir --no-deps-check --warnings-as-errors |& tee -a "$output"
        assert_no_chimeway_redefinition
        return
      fi

      if [[ "$focus" == "warning_gate_mutation" ]]; then
        warning_probe="$package_path/lib/chimeway/apns_warning_gate_probe.ex"
        [[ "$warning_probe" == "$package_path"/lib/* ]] || fail "warning probe escaped unpacked Chimeway source"
        printf '%s\n' 'defmodule Chimeway.APNS.WarningGateProbe do' '  def warning, do: ignored = :warning' 'end' >"$warning_probe"

        if ERL_LIBS="$dependency_erl_libs" CHIMEWAY_PACKAGE_PATH="$package_path" CHIMEWAY_APNS_ENABLED=1 MIX_ENV=test \
             mix cmd --cd "$package_path" mix compile --force-elixir --no-deps-check --warnings-as-errors |& tee -a "$output"; then
          fail "Chimeway warning mutation unexpectedly compiled cleanly"
        fi

        assert_no_chimeway_redefinition
        grep -q 'warning' "$output" || fail "Chimeway warning mutation did not emit compiler diagnostics"
        return
      fi

      ERL_LIBS="$dependency_erl_libs" CHIMEWAY_PACKAGE_PATH="$package_path" CHIMEWAY_APNS_ENABLED=1 MIX_ENV=test \
        mix cmd --cd "$package_path" mix compile --force-elixir --no-deps-check --warnings-as-errors |& tee -a "$output"
      assert_no_chimeway_redefinition
      CHIMEWAY_PACKAGE_PATH="$package_path" CHIMEWAY_APNS_ENABLED=1 MIX_ENV=test mix deps.tree >"$tree_output"
      grep -Eq 'pigeon.*2\.0\.1' "$tree_output" || fail "enabled fixture did not resolve pigeon 2.0.1"
      grep -Eq 'httpoison.*3\.0\.0' "$tree_output" || fail "enabled fixture did not resolve httpoison 3.0.0"
      grep -Eq 'hackney.*4\.7\.4' "$tree_output" || fail "enabled fixture did not resolve hackney 4.7.4"
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
      env -u CHIMEWAY_APNS_ENABLED CHIMEWAY_PACKAGE_PATH="$package_path" MIX_ENV=test mix deps.get
      env -u CHIMEWAY_APNS_ENABLED CHIMEWAY_PACKAGE_PATH="$package_path" MIX_ENV=test mix deps.tree >"$tree_output"
      ! grep -Eqi 'pigeon|httpoison' "$tree_output" || fail "disabled fixture dependency tree contains APNs-only dependencies"
      [[ $(grep -Eic 'hackney' "$tree_output") -eq 1 ]] || fail "disabled fixture has a Hackney edge beyond the root tzdata baseline"
      awk '/tzdata ~> 1\.1/{seen = 1; next} seen && /hackney ~> 1\.17/{found = 1; exit} END {exit !found}' "$tree_output" || fail "disabled fixture lost the expected tzdata-to-Hackney baseline edge"
      ! grep -qi pigeon mix.lock || fail "disabled fixture lock contains pigeon"
      ! grep -qi httpoison mix.lock || fail "disabled fixture lock contains HTTPoison"
      env -u CHIMEWAY_APNS_ENABLED CHIMEWAY_PACKAGE_PATH="$package_path" MIX_ENV=test mix compile --warnings-as-errors >>"$output"
      env -u CHIMEWAY_APNS_ENABLED CHIMEWAY_PACKAGE_PATH="$package_path" MIX_ENV=test mix test >>"$output"
    )
  fi

  ! grep -q 'fixture-token-never-emitted' "$output" || fail "consumer output leaked the token sentinel"
}

if [[ "$focus" == "bridge_to_cas" || "$focus" == "runtime_success" || "$focus" == "strict_compile_probe" || "$focus" == "warning_gate_mutation" ]]; then
  run_consumer enabled
else
  run_consumer disabled
  run_consumer enabled
fi

# This is an intentionally narrow proof claim: it describes a synthetic sandbox
# handoff only, never Apple acceptance, device display, or protected-open proof.
printf '%s\n' '{"provider":"apns","outcome":"provider_accepted","environment":"sandbox","proof":"not_live_not_device_not_open"}'
