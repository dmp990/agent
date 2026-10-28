defmodule CodingagentTest do
  use ExUnit.Case
  doctest Codingagent

  test "greets the world" do
    assert Codingagent.hello() == :world
  end
end
