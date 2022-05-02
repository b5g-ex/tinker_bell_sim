defmodule TinkerBellSimServer do
  use GenServer

  #GenServer API
  def init(state) do
    {:ok, state}
  end

  def handle_call(:startworkterm, _from, state) do
    for times <- 0..4 do
      workerstate = GenServer.call(Enum.at(state, times), :sendstate)
      IO.inspect workerstate
      #GenServer.call(Server, {:append_workerstate, workerstate, times})
      state = state ++ workerstate
    end
    {:reply, state, state}
  end

  def handle_call({:append_pid, pid}, _from, state) do
    {:reply, pid, state ++ [pid]}
  end
"""
  def handle_call({:append_workerstate, value, index}, _from, state) do
    #Enum.at(state, index) = [Enum.at(state, index)] ++ value
    {:reply, value, state}
    {:reply, value, state ++ value}
  end
"""
  #Client API
  def start_link(state \\ []) do
    GenServer.start_link(__MODULE__, state, name: Server)
    for times <- 1..5 do
      {:ok, pid} = TinkerBellSimWorker.start_link(times * 100)
      GenServer.call(Server, {:append_pid, pid})
    end
  end

  def startworkterm do
    GenServer.call(Server,:startworkterm)
  end
end
