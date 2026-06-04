config =
  "config/config.exs"
  |> Config.Reader.read!(env: :test)

Application.put_all_env(config, persistent: true)

Code.require_file("test/test_helper.exs")

ExUnit.configure(trace: true, include: [sigra: true], exclude: [:test])

Code.require_file("test/chimeway/integrations/sigra_auth_harness_test.exs")
Code.require_file("test/chimeway/integrations/sigra_auth_lifecycle_test.exs")

result = ExUnit.run()

System.halt(if result.failures == 0, do: 0, else: 1)
