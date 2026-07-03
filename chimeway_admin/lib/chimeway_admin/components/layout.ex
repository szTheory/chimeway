defmodule ChimewayAdmin.Components.Layout do
  @moduledoc false

  use Phoenix.Component

  alias ChimewayAdmin.Routes

  attr(:title, :string, required: true)
  attr(:eyebrow, :string, default: "Chimeway Admin")
  attr(:active, :atom, default: :home)
  attr(:theme, :string, default: "system")
  attr(:description, :string, default: nil)
  slot(:actions)
  slot(:inner_block, required: true)

  def admin_shell(assigns) do
    ~H"""
    <main class="chimeway-admin" data-cw-theme={@theme}>
      <div class="cw-shell">
        <aside class="cw-sidebar" aria-label="Chimeway admin">
          <.brand />
          <nav class="cw-nav" aria-label="Admin sections">
            <.nav_item active={@active == :home} path={Routes.search_path()} label="Command Center" />
            <.nav_item active={@active == :traces} path={Routes.traces_path()} label="Trace Lookup" />
            <.nav_item active={@active == :feed} path={Routes.feed_path()} label="Feed Debug" />
            <.nav_item active={@active == :definitions} path={Routes.definitions_path()} label="Definitions" />
            <.nav_item active={@active == :health} path={Routes.health_path()} label="Health" />
            <.nav_item active={@active == :recovery} path={Routes.recovery_path()} label="Recovery" />
          </nav>
        </aside>

        <section class="cw-main">
          <header class="cw-page-header">
            <div>
              <p class="cw-eyebrow">{@eyebrow}</p>
              <h1>{@title}</h1>
              <p :if={@description} class="cw-page-description">{@description}</p>
            </div>
            <div :if={@actions != []} class="cw-page-actions">
              {render_slot(@actions)}
            </div>
          </header>

          {render_slot(@inner_block)}
        </section>
      </div>
    </main>
    """
  end

  defp brand(assigns) do
    ~H"""
    <div class="cw-brand">
      <span class="cw-brand__mark" aria-hidden="true">C</span>
      <div>
        <strong>Chimeway</strong>
        <span>Operator console</span>
      </div>
    </div>
    """
  end

  attr(:active, :boolean, required: true)
  attr(:path, :string, required: true)
  attr(:label, :string, required: true)

  defp nav_item(assigns) do
    ~H"""
    <.link navigate={@path} class={["cw-nav__item", @active && "cw-nav__item--active"]} aria-current={if @active, do: "page", else: nil}>
      <span>{@label}</span>
    </.link>
    """
  end
end
