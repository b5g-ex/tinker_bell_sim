defmodule TinkerBellSimTest do
  use ExUnit.Case
  doctest TinkerBellSim

  test "greets the world" do
    assert TinkerBellSim.hello() == :world
  end
end
