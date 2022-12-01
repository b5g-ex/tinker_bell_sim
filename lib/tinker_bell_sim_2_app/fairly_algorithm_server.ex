defmodule FAServer do
  use GenServer

  #GenServer API
  def init(relaymap) do
    {:ok, relaymap}
  end

  def handle_call(:get_relaymap, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:append_relayinfo, pid, relayinfo}, _from, state) do
    state = Map.put_new(state, pid, relayinfo)
    {:reply, state, state}
  end

  #Client API
  def start_link(relaymap \\ %{}) do
    GenServer.start_link(__MODULE__, relaymap, name: AlgoServer)
    for times <- 0..4 do
      {:ok, pid} = GRServer.start_link()
      relayinfo = GenServer.call(pid, :get_relayinfo)
      GenServer.call(AlgoServer, {:append_relayinfo, pid, relayinfo})
    end
    GenServer.call(AlgoServer, :get_relaymap)
  end

end
