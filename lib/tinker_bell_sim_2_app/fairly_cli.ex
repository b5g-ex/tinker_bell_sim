defmodule TinkerBellSim2App.FairlyCli do
  def main(args) do
    if length(args) != 3 do
      IO.puts("Usage: fairly_cli <taskseed> <engineseed> <tasknumlimit>")
      IO.puts("  taskseed: random seed for task generation")
      IO.puts("  engineseed: random seed for engine flops, R-R Network Delay&BW")
      IO.puts("  tasknumlimit: number of tasks in a taskset")
      System.halt(1)
    end

    params =
      args
      |> Enum.map(fn arg -> String.to_integer(arg) end)

    FAServer.start_link(params)
    FAServer.start_assigning()

    receive do
      {:message_type, _value} ->
        nil
        # wait for the FAServer to (error)exit
    end
  end
end
