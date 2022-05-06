defmodule TinkerBellSimServer do
  use GenServer

  #GenServer API
  def init(state) do
    {:ok, state}
  end

  def handle_call(:startworkterm, _from, state) do
    for times <- 0..4 do
      workerstate = GenServer.call(Enum.at(Map.keys(state),times), :sendstate)
      Map.get_and_update(state, Enum.at(Map.keys(state),times), fn current_state
        -> {current_state, workerstate}
      end)
    end
    {:reply, state, state}
  end

  def handle_call({:append_workerinfo, pid, calcpower}, _from, state) do
    state = Map.put_new(state, pid, calcpower)
    {:reply, state, state}
  end

  def handle_call(:getstate, _from, state) do
    {:reply, state, state}
  end

  #Client API
  def start_link(state \\ %{}) do
    GenServer.start_link(__MODULE__, state, name: Server)
    for times <- 0..4 do
      {:ok, pid} = TinkerBellSimWorker.start_link(100 * (times+1))
      GenServer.call(Server, {:append_workerinfo, pid, 100 * (times+1)})
    end

    GenServer.call(Server,:getstate)

  end

  def startworkterm do
    GenServer.call(Server,:startworkterm)
  end

end
