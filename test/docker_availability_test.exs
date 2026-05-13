defmodule DockerAvailabilityTest do
  use ExUnit.Case
  doctest DockerAvailability

  test "greets the world" do
    assert DockerAvailability.hello() == :world
  end
end
