defmodule ChimewayAdmin.Components.Core do
  @moduledoc false

  use Phoenix.Component

  attr(:class, :string, default: nil)
  slot(:inner_block, required: true)

  def card(assigns) do
    ~H"""
    <section class={["cw-card", @class]}>
      {render_slot(@inner_block)}
    </section>
    """
  end

  attr(:variant, :atom, default: :secondary, values: [:primary, :secondary, :ghost, :danger])
  attr(:type, :string, default: "button")
  attr(:rest, :global)
  slot(:inner_block, required: true)

  def button(assigns) do
    ~H"""
    <button type={@type} class={["cw-button", "cw-button--#{@variant}"]} {@rest}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr(:navigate, :string, default: nil)
  attr(:href, :string, default: nil)
  attr(:variant, :atom, default: :secondary, values: [:primary, :secondary, :ghost, :danger])
  attr(:rest, :global)
  slot(:inner_block, required: true)

  def link_button(assigns) do
    ~H"""
    <.link navigate={@navigate} href={@href} class={["cw-button", "cw-button--#{@variant}"]} {@rest}>
      {render_slot(@inner_block)}
    </.link>
    """
  end

  attr(:label, :string, required: true)
  attr(:name, :string, required: true)
  attr(:value, :string, default: "")
  attr(:type, :string, default: "text")
  attr(:hint, :string, default: nil)
  attr(:required, :boolean, default: false)
  attr(:rest, :global)

  def text_input(assigns) do
    assigns = assign_new(assigns, :id, fn -> "cw-input-#{assigns.name}" end)

    ~H"""
    <label class="cw-field" for={@id}>
      <span class="cw-field__label">{@label}</span>
      <span :if={@hint} class="cw-field__hint">{@hint}</span>
      <input id={@id} class="cw-input" type={@type} name={@name} value={@value} required={@required} {@rest} />
    </label>
    """
  end

  attr(:label, :string, required: true)
  attr(:name, :string, required: true)
  attr(:value, :string, default: "")
  attr(:options, :list, required: true)
  attr(:rest, :global)

  def select(assigns) do
    assigns = assign_new(assigns, :id, fn -> "cw-select-#{assigns.name}" end)

    ~H"""
    <label class="cw-field" for={@id}>
      <span class="cw-field__label">{@label}</span>
      <select id={@id} class="cw-select" name={@name} {@rest}>
        <option :for={{label, value} <- @options} value={value} selected={to_string(value) == to_string(@value)}>
          {label}
        </option>
      </select>
    </label>
    """
  end

  attr(:title, :string, required: true)
  attr(:body, :string, required: true)
  attr(:tone, :atom, default: :neutral, values: [:neutral, :success, :warning, :danger])

  def empty_state(assigns) do
    ~H"""
    <section class={["cw-empty", "cw-empty--#{@tone}"]}>
      <p class="cw-empty__title">{@title}</p>
      <p class="cw-empty__body">{@body}</p>
    </section>
    """
  end

  attr(:label, :string, required: true)
  attr(:value, :any, required: true)

  def copyable_id(assigns) do
    ~H"""
    <span class="cw-copy-id" title={to_string(@value)}>
      <span class="cw-copy-id__label">{@label}</span>
      <code>{format_value(@value)}</code>
    </span>
    """
  end

  defp format_value(nil), do: "—"
  defp format_value(""), do: "—"
  defp format_value(value), do: to_string(value)
end
