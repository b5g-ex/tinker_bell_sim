defmodule TinkerBellSimServer do
  use GenServer

  #GenServer API
  def init(state) do
    {:ok, state}
  end

  def handle_call(:startworkterm, _from, state) do
    for times <- 0..4 do
      workerstate = GenServer.call(Enum.at(Enum.at(state, times),0), :sendstate)
      #IO.inspect workerstate
      #GenServer.call(Server, {:append_workerstate, workerstate, times})
      #Enum.at(Enum.at(state, 0), times) = workerstate
    end
    {:reply, state, state}
  end

  def handle_call({:append_workerinfo, pid, calcpower}, _from, state) do
    Map.put(state, pid, calcpower)
    {:reply, state, state}
  end

  #Client API
  def start_link(state \\ %{}) do
    GenServer.start_link(__MODULE__, state, name: Server)
    for times <- 0..4 do
      {:ok, pid} = TinkerBellSimWorker.start_link(100 * (times+1))
      GenServer.call(Server, {:append_workerinfo, pid, 100 * (times+1)})
    end
  end

  def startworkterm do
    GenServer.call(Server,:startworkterm)
  end

end
