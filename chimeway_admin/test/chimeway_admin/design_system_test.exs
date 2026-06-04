defmodule ChimewayAdmin.DesignSystemTest do
  use ExUnit.Case, async: true

  alias ChimewayAdmin.Assets

  @css Assets.inline_css()

  test "packaged stylesheet stays scoped and framework-free" do
    assert @css =~ "@layer cw.tokens"
    assert @css =~ ":where(.chimeway-admin)"
    refute @css =~ "@tailwind"
    refute @css =~ "bootstrap"
    refute @css =~ "shadcn"
    refute @css =~ "radix"
  end

  test "exposes required design token families" do
    assert_tokens([
      "--cw-space-xs: 4px",
      "--cw-space-sm: 8px",
      "--cw-space-md: 16px",
      "--cw-space-lg: 24px",
      "--cw-space-xl: 32px",
      "--cw-space-2xl: 48px",
      "--cw-space-3xl: 64px",
      "--cw-font-family-sans: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif",
      "--cw-font-family-mono: \"IBM Plex Mono\", ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace",
      "--cw-font-size-label: 14px",
      "--cw-font-size-body: 16px",
      "--cw-font-size-heading: 20px",
      "--cw-font-size-display: 28px",
      "--cw-line-height-label: 1.35",
      "--cw-line-height-body: 1.5",
      "--cw-line-height-heading: 1.2",
      "--cw-line-height-display: 1.15",
      "--cw-font-weight-regular: 400",
      "--cw-font-weight-semibold: 600",
      "--cw-radius-sm: 5px",
      "--cw-radius-md: 8px",
      "--cw-radius-pill: 999px",
      "--cw-shadow-panel: 0 16px 42px rgb(16 32 39 / 0.08)",
      "--cw-focus-ring: var(--cw-blue)",
      "--cw-focus-offset: 3px",
      "--cw-z-sidebar: 10",
      "--cw-z-focus: 50",
      "--cw-motion-fast: 120ms ease-out",
      "--cw-motion-pressed: 80ms ease-out"
    ])
  end

  test "exposes status tone text surface and border tokens" do
    for tone <- ~w(success warning danger info neutral),
        role <- ~w(text surface border) do
      assert @css =~ "--cw-status-#{tone}-#{role}"
    end
  end

  test "exposes light dark and system theme state branches" do
    assert_tokens([
      "data-cw-theme=\"light\"",
      "data-cw-theme=\"dark\"",
      "data-cw-theme=\"system\"",
      "@media (prefers-color-scheme: dark)",
      "--cw-surface-hover",
      "--cw-surface-active",
      "--cw-control-bg",
      "--cw-control-hover",
      "--cw-control-active",
      "--cw-control-disabled-bg",
      "--cw-control-disabled-fg",
      "--cw-border-strong",
      "--cw-focus-halo",
      "--cw-button-primary-bg",
      "--cw-button-primary-fg",
      "--cw-button-danger-bg",
      "--cw-button-danger-fg",
      "--cw-table-row-hover",
      "--cw-row-bg",
      "--cw-row-hover",
      "--cw-link-fg"
    ])
  end

  test "sampled light and dark color pairs meet contrast thresholds" do
    assert_contrast("#102027", "#fffdf8", 4.5)
    assert_contrast("#5e6b72", "#fffdf8", 4.5)
    assert_contrast("#ffffff", "#0e7c86", 4.5)
    assert_contrast("#ffffff", "#b83232", 4.5)
    assert_contrast("#fffdf8", "#07131a", 4.5)
    assert_contrast("#b8c5c9", "#10232c", 4.5)
    assert_contrast("#9adbcf", "#07131a", 4.5)
    assert_contrast("#d6a84f", "#07131a", 3.0)
  end

  test "responsive and long-content protections are contracted" do
    assert_tokens([
      "@media (max-width: 900px)",
      "@media (max-width: 640px)",
      "grid-template-columns: 1fr",
      "overflow-x: auto",
      "overflow-wrap: anywhere",
      "min-width: 0",
      "min-height: 40px",
      "min-height: 44px",
      "--cw-motion-fast",
      "--cw-motion-pressed",
      ".cw-search-form",
      ".cw-summary-list",
      ".cw-table-wrap",
      ".cw-copy-id",
      ".cw-row",
      ".cw-row-link",
      ".cw-metric-grid",
      ".cw-page-header",
      ".cw-nav__item"
    ])
  end

  test "motion is reduced-motion safe and hover does not lift buttons" do
    assert @css =~ "@media (prefers-reduced-motion: reduce)"
    assert @css =~ "transition-duration: 0.001ms"
    assert @css =~ "scroll-behavior: auto"
    refute @css =~ ".cw-button:hover {\n    transform: translateY(-1px);"
  end

  defp assert_tokens(tokens) do
    for token <- tokens do
      assert @css =~ token
    end
  end

  defp assert_contrast(foreground, background, minimum) do
    ratio = contrast_ratio(foreground, background)
    assert ratio >= minimum
  end

  defp contrast_ratio(foreground, background) do
    lighter =
      foreground
      |> relative_luminance()
      |> max(relative_luminance(background))

    darker =
      foreground
      |> relative_luminance()
      |> min(relative_luminance(background))

    (lighter + 0.05) / (darker + 0.05)
  end

  defp relative_luminance(hex) do
    hex
    |> rgb()
    |> Enum.map(&linear_channel/1)
    |> then(fn [r, g, b] -> 0.2126 * r + 0.7152 * g + 0.0722 * b end)
  end

  defp rgb("#" <> <<r::binary-size(2), g::binary-size(2), b::binary-size(2)>>) do
    for channel <- [r, g, b], do: channel |> String.to_integer(16) |> Kernel./(255)
  end

  defp linear_channel(channel) when channel <= 0.03928, do: channel / 12.92
  defp linear_channel(channel), do: :math.pow((channel + 0.055) / 1.055, 2.4)
end
