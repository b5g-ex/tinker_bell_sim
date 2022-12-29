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
      |> Enum.reduce([], fn {key, val}, acc -> if val == True do acc ++ [key] else acc end end)

    engine_connected_relay = state
      |> Enum.map(fn {key, val} -> {key, Map.get(val, :enginemap)} end)
      |> Enum.map(fn {key, val} -> {key, length(Map.values(val))} end)
      |> Enum.map(fn {key, val} -> if val == 0 do {key, False} else {key, True} end end)
      |> Enum.reduce([], fn {key, val}, acc -> if val == True do acc ++ [key] else acc end end)

    relaynetwork_bandwidth = device_connected_relay
      |> Enum.reduce(%{}, fn dcr_pid, acc -> Map.put_new(acc, dcr_pid, %{}) end)
      |> Enum.map(fn {key, _} ->
        {key, Enum.reduce(engine_connected_relay, %{}, fn ecr_pid, acc -> Map.put_new(acc, ecr_pid, if key == ecr_pid do 9999 else 500 + :rand.uniform(500) end) end)} end)
    relaynetwork_delay = device_connected_relay
      |> Enum.reduce(%{}, fn dcr_pid, acc -> Map.put_new(acc, dcr_pid, %{}) end)
      |> Enum.map(fn {key, _} ->
        {key, Enum.reduce(engine_connected_relay, %{}, fn ecr_pid, acc -> Map.put_new(acc, ecr_pid, if key == ecr_pid do 0 else 5 + :rand.uniform(20) end) end)} end)

    relaynetwork_bandwidth = Enum.reduce(relaynetwork_bandwidth, %{}, fn {key, val}, acc -> Map.put_new(acc, key, val) end)
    relaynetwork_delay = Enum.reduce(relaynetwork_delay, %{}, fn {key, val}, acc -> Map.put_new(acc, key, val) end)

    state = Map.put_new(state, :relaynetwork_bandwidth, relaynetwork_bandwidth)
    state = Map.put_new(state, :relaynetwork_delay, relaynetwork_delay)

    {:reply, state, state}
  end

  def handle_call({:assign_algorithm, devicepid, device_connected_relaypid, task}, _from, state) do

    case task.algo do
      "taskque" ->
        clustermap = state
          |> Map.delete(:relaynetwork_bandwidth)
          |> Map.delete(:relaynetwork_delay)
          |> Enum.map(fn {key, val} -> {key, Map.get(val, :clusterinfo)} end)
        cluster_taskque_num = Enum.map(clustermap, fn {key, val} -> {key, if val.cluster_taskque == "no engine" do :infinity else length(val.cluster_taskque) end} end)
        min_taskque_cluster_pid = cluster_taskque_num
          |> Enum.min_by(fn {_, val} -> val end)
          |> elem(0)

        #IO.inspect(min_taskque_cluster_pid, label: "assigned cluster")
        {:reply, min_taskque_cluster_pid, state}

      "delay" ->
        delaymap = Map.get(state.relaynetwork_delay, device_connected_relaypid)
        min_delay_cluster_pid = delaymap
          |> Enum.min_by(fn {_, val} -> val end)
          |> elem(0)

        #IO.inspect(min_delay_cluster_pid, label: "assigned cluster")
        {:reply, min_delay_cluster_pid, state}

      "bandwidth" ->
        bandwidthmap = Map.get(state.relaynetwork_bandwidth, device_connected_relaypid)
        max_bandwidth_cluster_pid = bandwidthmap
          |> Enum.max_by(fn {_, val} -> val end)
          |> elem(0)

        #IO.inspect(max_bandwidth_cluster_pid, label: "assigned cluster")
        {:reply, max_bandwidth_cluster_pid, state}

      "responsetime" ->
        cluster_responsetime_in_cluster = state
          |> Map.delete(:relaynetwork_bandwidth)
          |> Map.delete(:relaynetwork_delay)
          |> Enum.map(fn {key, val} -> {key, Map.get(val, :clusterinfo)} end)
          |> Enum.map(fn {key, val} -> {key, Map.get(val, :cluster_response_time)} end)
          |> Enum.map(fn {key, val} -> {key, elem(val, 0)} end)
        delaymap = Map.get(state.relaynetwork_delay, device_connected_relaypid)
        cluster_responsetime = cluster_responsetime_in_cluster
          |> Enum.map(fn {key, val} -> if val == :infinity do {key, val} else {key, val + Map.get(delaymap, key)} end end)
        IO.inspect cluster_responsetime
        min_responsetime_cluster_pid = cluster_responsetime
          |> Enum.min_by(fn {_, val} -> val end)
          |> elem(0)

        {:reply, min_responsetime_cluster_pid, state}
    end

  end

  def handle_cast({:update_relaymap, relaypid, new_relayinfo}, state) do
    state = Map.update!(state, relaypid, fn _ -> new_relayinfo end)
    #IO.inspect "engineinfo updated"
    {:noreply, state}
  end

  #Client API
  def start_link(relaymap \\ %{}) do
    GenServer.start_link(__MODULE__, relaymap, name: AlgoServer)
    for _ <- 0..4 do
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
