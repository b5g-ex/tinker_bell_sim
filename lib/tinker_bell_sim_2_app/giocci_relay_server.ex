defmodule GRServer do
  use GenServer

  #GenServer API
  def init(relayinfo) do
    {:ok, relayinfo}
  end

  def handle_call({:append_engineinfo, pid, engineinfo}, _from, state) do
    now_enginemap = state.enginemap
    new_enginemap = Map.put_new(now_enginemap, pid, engineinfo)
    state = Map.update!(state, :enginemap, fn _ -> new_enginemap end)
    {:reply, state, state}
  end

  def handle_call({:append_deviceinfo, pid, deviceinfo}, _from, state) do
    now_devicemap = state.devicemap
    new_devicemap = Map.put_new(now_devicemap, pid, deviceinfo)
    state = Map.update!(state, :devicemap, fn _ -> new_devicemap end)
    {:reply, state, state}
  end

  def handle_call(:initialize_clusterinfo, _from, state) do
    cluster_taskque = state.enginemap
      |> Map.values()
      |> Enum.map(fn x -> Map.get(x, :taskque) end)
      |> Enum.reduce([], fn x, acc -> x ++ acc end)
    state = Map.update!(state, :clusterinfo, fn _ -> if state.enginemap == %{} do %{cluster_taskque: "no engine", cluster_enginenum: 0, cluster_response_time: {:infinity, []}} else %{cluster_taskque: cluster_taskque, cluster_enginenum: Enum.count(state.enginemap), cluster_response_time: {0,[]}} end end)
    {:reply, state, state}
  end

  def handle_call(:update_clusterinfo, _from, state) do
    cluster_taskque = state.enginemap
      |> Map.values()
      |> Enum.map(fn x -> Map.get(x, :taskque) end)
      |> Enum.reduce([], fn x, acc -> x ++ acc end)
    new_clusterinfo = state
      |> Map.get(:clusterinfo)
      |> Map.update!(:cluster_taskque, fn now_taskque -> if now_taskque == "no engine" do "no engine" else cluster_taskque end end)
    state = Map.update!(state, :clusterinfo, fn _ -> new_clusterinfo end)
    {:reply, state, state}
  end

  def handle_cast({:send_task_response_time_in_cluster, task_response_time_in_cluster}, state) do
    new_clusterinfo = state
      |> Map.get(:clusterinfo)
      |> Map.update!(:cluster_response_time, fn {_, nowdata} ->
        newdata = if length(nowdata) < 10 do
          nowdata ++ [task_response_time_in_cluster]
          else
          [_ | tl] = nowdata
          tl ++ [task_response_time_in_cluster]
          end
        new_response_time = Enum.sum(newdata) / length(newdata)
        {new_response_time, newdata} end)
    state = Map.update!(state, :clusterinfo, fn _ -> new_clusterinfo end)
    {:noreply, state}
  end

  def handle_call(:get_relayinfo, _from, state) do
    {:reply, state, state}
  end

  def handle_cast(:start_assigning, state) do
    devicepids = Map.keys(state.devicemap)
    Enum.map(devicepids, fn pid -> GenServer.cast(pid, :taskflag_true)
      GenServer.cast(pid, :create_task) end)
    {:noreply, state}
  end

  def handle_cast(:stop_assigning, state) do
    state.devicemap
    |> Map.keys()
    |> Enum.map(fn pid -> GenServer.cast(pid, :taskflag_false) end)
    {:noreply, state}
  end

  def handle_call({:assign_request, devicepid, task}, _from, state) do

    assigned_cluster_pid = GenServer.call(AlgoServer, {:assign_algorithm, devicepid, self(), task})
    #IO.inspect({self(), assigned_cluster_pid}, label: "relay-to-relay") 標準出力
    if self() == assigned_cluster_pid do
      #クラスター内assignはタスクキュー数のみで決定
      engine_taskque_scores = state.enginemap
        |> Enum.map(fn {key, val} -> {key, Map.get(val, :taskque)} end)
        |> Enum.map(fn {key, val} -> {key, length(val)} end)
      assigned_engine_pid = engine_taskque_scores
        |> Enum.min_by(fn {key, val} -> val end)
        |> elem(0)

      GenServer.cast(assigned_engine_pid, {:assign_task_to_engine, task})

    else
      GenServer.cast(assigned_cluster_pid, {:assign_task_in_cluster, task})
    end

    {:reply, state, state}
  end

  def handle_cast({:assign_task_in_cluster,task}, state) do
    #クラスター内assignはタスクキュー数のみで決定
    engine_taskque_scores = state.enginemap
      |> Enum.map(fn {key, val} -> {key, Map.get(val, :taskque)} end)
      |> Enum.map(fn {key, val} -> {key, length(val)} end)
    assigned_engine_pid = engine_taskque_scores
      |> Enum.min_by(fn {key, val} -> val end)
      |> elem(0)

    GenServer.cast(assigned_engine_pid, {:assign_task_to_engine, task})

    {:noreply, state}
  end

  def handle_cast({:update_enginemap, enginepid, new_engineinfo}, state) do

    now_enginemap = state.enginemap
    new_enginemap = Map.update!(now_enginemap, enginepid, fn engineinfo -> new_engineinfo end)
    state = Map.update!(state, :enginemap, fn x -> new_enginemap end)

    #update_clusterinfoをする
    cluster_taskque = state.enginemap
      |> Map.values()
      |> Enum.map(fn x -> Map.get(x, :taskque) end)
      |> Enum.reduce([], fn x, acc -> x ++ acc end)
    new_clusterinfo = state
      |> Map.get(:clusterinfo)
      |> Map.update!(:cluster_taskque, fn now_taskque -> if now_taskque == "no engine" do "no engine" else cluster_taskque end end)
    state = Map.update!(state, :clusterinfo, fn _ -> new_clusterinfo end)

    GenServer.cast(AlgoServer, {:update_relaymap, self(), state})

    {:noreply, state}
  end

  #client API
  def start_link(relayinfo \\ %{enginemap: %{}, devicemap: %{}, clusterinfo: %{}}) do
    {:ok, mypid} = GenServer.start_link(__MODULE__, relayinfo)
    enginenum = :rand.uniform(3) - 1
    if enginenum != 0 do
      for times <- 1..enginenum do
        {:ok, pid} = GEServer.start_link(%{relaypid: mypid})
        engineinfo = GenServer.call(pid, :get_engineinfo)
        GenServer.call(mypid, {:append_engineinfo, pid, engineinfo})
        GenServer.cast(pid, :update_engineinfo)
      end
    end
    devicenum = :rand.uniform(3) - 1
    if devicenum != 0 do
      for times <- 0..:rand.uniform 4 do
        {:ok, pid} = EndDevice.start_link(%{taskflag: false, relaypid: mypid})
        GenServer.call(mypid, {:append_deviceinfo, pid, %{taskflag: false, relaypid: mypid}})
      end
    end
    GenServer.call(mypid, :initialize_clusterinfo)
    {:ok, mypid}
  end
end
