defmodule Mix.Tasks.TinkerBellSim do

  use Mix.Task

  @shortdoc "This is a program that can test performances of calculation-resource distribution algorithms"
  def run(_) do

    # This will start our application
    Mix.Task.run("app.start")

  end
end
