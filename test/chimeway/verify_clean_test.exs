defmodule Chimeway.VerifyCleanTest do
  use ExUnit.Case, async: true

  @script Path.expand("scripts/ci/verify-clean.sh")
  @owned_prefix "chimeway-verify-clean-"

  setup do
    root = allocate_owned_repository!()
    on_exit(fn -> remove_owned_repository!(root) end)

    git!(root, ["init", "--quiet"])
    git!(root, ["config", "user.name", "Chimeway Verify Clean"])
    git!(root, ["config", "user.email", "verify-clean@chimeway.invalid"])
    File.write!(Path.join(root, "tracked.txt"), "baseline\n")
    git!(root, ["add", "tracked.txt"])
    git!(root, ["commit", "--quiet", "-m", "baseline"])

    %{root: root}
  end

  test "succeeds for a clean repository", %{root: root} do
    assert {"verify.clean: clean\n", 0} = run_guard(root)
  end

  test "fails and reports an unstaged tracked edit", %{root: root} do
    File.write!(Path.join(root, "tracked.txt"), "unstaged\n")

    assert {output, status} = run_guard(root)
    assert status != 0
    assert output =~ "verify.clean: repository is dirty"
    assert output =~ " M tracked.txt"
  end

  test "fails and reports a staged edit", %{root: root} do
    File.write!(Path.join(root, "tracked.txt"), "staged\n")
    git!(root, ["add", "tracked.txt"])

    assert {output, status} = run_guard(root)
    assert status != 0
    assert output =~ "verify.clean: repository is dirty"
    assert output =~ "M  tracked.txt"
  end

  test "fails and reports a nested non-ignored untracked file", %{root: root} do
    nested = Path.join(root, "nested")
    File.mkdir!(nested)
    File.write!(Path.join(nested, "new.txt"), "untracked\n")

    assert {output, status} = run_guard(root)
    assert status != 0
    assert output =~ "verify.clean: repository is dirty"
    assert output =~ "?? nested/new.txt"
  end

  test "ignored files preserve a clean result", %{root: root} do
    File.write!(Path.join(root, ".gitignore"), "ignored.log\n")
    git!(root, ["add", ".gitignore"])
    git!(root, ["commit", "--quiet", "-m", "ignore generated log"])
    File.write!(Path.join(root, "ignored.log"), "generated\n")

    assert {"verify.clean: clean\n", 0} = run_guard(root)
  end

  test "the stable Mix alias invokes the repository-owned guard" do
    mix_exs = File.read!("mix.exs")
    assert_verify_clean_alias!(mix_exs)

    mutated =
      String.replace(
        mix_exs,
        ~S("verify.clean": ["cmd bash scripts/ci/verify-clean.sh"]),
        ~S("verify.clean": ["cmd git diff --exit-code"]),
        global: false
      )

    refute mutated == mix_exs
    assert_raise ExUnit.AssertionError, fn -> assert_verify_clean_alias!(mutated) end
  end

  defp run_guard(root) do
    System.cmd("bash", [@script], cd: root, stderr_to_stdout: true)
  end

  defp git!(root, args) do
    {output, status} = System.cmd("git", args, cd: root, stderr_to_stdout: true)
    assert status == 0, "git #{Enum.join(args, " ")} failed:\n#{output}"
    output
  end

  defp assert_verify_clean_alias!(mix_exs) do
    assert mix_exs =~ ~S("verify.clean": ["cmd bash scripts/ci/verify-clean.sh"])
    refute mix_exs =~ ~S("verify.clean": ["cmd git diff --exit-code"])
  end

  defp allocate_owned_repository! do
    root =
      Path.join(
        Path.expand(System.tmp_dir!()),
        @owned_prefix <> Base.url_encode64(:crypto.strong_rand_bytes(18), padding: false)
      )

    case File.mkdir(root) do
      :ok -> root
      {:error, :eexist} -> allocate_owned_repository!()
      {:error, reason} -> raise File.Error, reason: reason, action: "create directory", path: root
    end
  end

  defp remove_owned_repository!(root) do
    expanded = Path.expand(root)
    temp_root = Path.expand(System.tmp_dir!())

    owned? =
      Path.dirname(expanded) == temp_root and
        String.starts_with?(Path.basename(expanded), @owned_prefix) and
        match?({:ok, %File.Stat{type: :directory}}, File.lstat(expanded))

    if owned? do
      File.rm_rf!(expanded)
    else
      raise ArgumentError, "refusing recursive cleanup outside an owned verify.clean repository"
    end
  end
end
