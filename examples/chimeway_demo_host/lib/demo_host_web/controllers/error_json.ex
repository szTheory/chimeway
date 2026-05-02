defmodule DemoHostWeb.ErrorJSON do
  @moduledoc """
  Minimal JSON error view for Phoenix error handling.
  Returns a plain JSON body with status and message for error responses.
  """

  def render(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end
