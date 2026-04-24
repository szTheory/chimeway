defmodule ChimewayTest do
  use ExUnit.Case

  test "exports trigger/3" do
    assert function_exported?(Chimeway, :trigger, 3)
  end
end
