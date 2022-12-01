defmodule GRServer do
  use GenServer

  #GenServer API
  def init(relayinfo) do
    {:ok, relayinfo}
  end

  def handle_call({:append_engineinfo, pid, engineinfo}, _from, state) do
    now_enginemap = state[:enginemap]
    new_enginemap = Map.put_new(now_enginemap, pid, engineinfo)
    state = Map.update!(state, :enginemap, fn now_enginemap -> new_enginemap end)
    {:reply, state, state}
  end

  def handle_call(:get_relayinfo, _from, state) do
    {:reply, state, state}
  end

  #client API
  def start_link(relayinfo \\ %{enginemap: %{}, taskmap: %{}}) do
    {:ok, mypid} = GenServer.start_link(__MODULE__, relayinfo)
    for times <- 0..4 do
      {:ok, pid} = GEServer.start_link()
      engineinfo = GenServer.call(pid, :get_engineinfo)
      GenServer.call(mypid, {:append_engineinfo, pid, engineinfo})
    end
    {:ok, mypid}
  end
end
