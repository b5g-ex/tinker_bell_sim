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

  def handle_call({:assign_algorithm, task}, _from, state) do
    #enginemapの更新をさせる
"""
    relaypids = Map.keys(state)
    IO.inspect relaypids
    Enum.map(relaypids, fn relaypid -> GenServer.call(relaypid, :update_enginemap) end)
"""
    #assign先の決定
    relaymaps = Map.values(state)
    enginemaps = Enum.map(relaymaps, fn x -> Map.get(x, :enginemap) end)
    integrated_enginemap = Enum.reduce(enginemaps, %{}, fn x, acc -> Map.merge(acc, x) end)
    #IO.inspect integrated_enginemap

    min_taskque_num = integrated_enginemap
      |> Map.values()
      |> Enum.map(fn engineinfo -> Map.get(engineinfo, :taskque) end)
      |> Enum.min()
    pid = integrated_enginemap
      |> Enum.find(fn {key, val} -> Map.get(val, :taskque) == min_taskque_num end)
      |> elem(0)

    IO.inspect(pid, label: "assigned engine")

    {:reply, state, state}
  end

  def handle_cast({:update_relaymap, relaypid, new_relayinfo}, state) do
    state = Map.update!(state, relaypid, fn relayinfo -> new_relayinfo end)
    #IO.inspect "engineinfo updated"
    {:noreply, state}
  end

  #Client API
  def start_link(relaymap \\ %{}) do
    GenServer.start_link(__MODULE__, relaymap, name: AlgoServer)
    for times <- 0..1 do
      {:ok, pid} = GRServer.start_link()
      relayinfo = GenServer.call(pid, :get_relayinfo)
      GenServer.call(AlgoServer, {:append_relayinfo, pid, relayinfo})
    end
    IO.inspect GenServer.call(AlgoServer, :get_relaymap)
  end

  def start_assigning() do
    GenServer.call(AlgoServer, :get_relaymap)
    |> Map.keys()
    |> Enum.map(fn pid -> GenServer.cast(pid, :start_assigning) end)
    {:ok}
  end

  #これやってもすぐタスク生成が止まらない　なぜ
  def stop_assigning() do
    GenServer.call(AlgoServer, :get_relaymap)
    |> Map.keys()
    |> Enum.map(fn pid -> GenServer.cast(pid, :stop_assigning) end)
    {:ok}
  end

end
