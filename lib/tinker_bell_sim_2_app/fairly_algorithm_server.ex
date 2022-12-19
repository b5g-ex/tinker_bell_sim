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

  def handle_call(:append_relaynetwork_feature_table, _from, state) do
    device_connected_relay = state
      |> Enum.map(fn {key, val} -> {key, Map.get(val, :devicemap)} end)
      |> Enum.map(fn {key, val} -> {key, length(Map.values(val))} end)
      |> Enum.map(fn {key, val} -> if val == 0 do {key, False} else {key, True} end end)
      |> Enum.reduce([], fn {key, val}, acc -> if val do acc ++ [key] end end)
    IO.inspect device_connected_relay
    engine_connected_relay = state
      |> Enum.map(fn {key, val} -> {key, Map.get(val, :enginemap)} end)
      |> Enum.map(fn {key, val} -> {key, length(Map.values(val))} end)
      |> Enum.map(fn {key, val} -> if val == 0 do {key, False} else {key, True} end end)
      |> Enum.reduce([], fn {key, val}, acc -> if val do acc ++ [key] end end)
    IO.inspect engine_connected_relay

    {:reply, state, state}
  end

  def handle_call({:assign_algorithm, task}, _from, state) do

    case task.algo do
      "taskque" ->
        clustermap = Enum.map(state, fn {key, val} -> {key, Map.get(val, :clusterinfo)} end)
        cluster_taskque_scores = Enum.map(clustermap, fn {key, val} -> {key, length(val.cluster_taskque)} end)
        min_taskque_num = cluster_taskque_scores
          |> Enum.map(fn {key, val} -> val end)
          |> Enum.min()
        pid = cluster_taskque_scores
          |> Enum.find(fn {key, val} -> val == min_taskque_num end)
          |> elem(0)

        IO.inspect(pid, label: "assigned cluster")
        {:reply, pid, state}

      "delay" ->
        {:reply, "error", state}

      "bandwidth" ->
        {:reply, "error", state}
    end

  end

  def handle_cast({:update_relaymap, relaypid, new_relayinfo}, state) do
    state = Map.update!(state, relaypid, fn relayinfo -> new_relayinfo end)
    #IO.inspect "engineinfo updated"
    {:noreply, state}
  end

  #Client API
  def start_link(relaymap \\ %{}) do
    GenServer.start_link(__MODULE__, relaymap, name: AlgoServer)
    for times <- 0..4 do
      {:ok, pid} = GRServer.start_link()
      relayinfo = GenServer.call(pid, :get_relayinfo)
      GenServer.call(AlgoServer, {:append_relayinfo, pid, relayinfo})
    end
    GenServer.call(AlgoServer, :append_relaynetwork_feature_table)
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
