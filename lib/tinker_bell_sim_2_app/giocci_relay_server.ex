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
    #clusterの平均flopsから課金額を決定したい
    cluster_flops_sum = state.enginemap
      |> Map.values()
      |> Enum.map(fn x -> Map.get(x, :hidden_parameter_flops) end)
      |> Enum.reduce(0, fn x, acc -> x + acc end)
    state = Map.update!(state, :clusterinfo, fn _ -> if state.enginemap == %{} do %{cluster_taskque: "no engine", cluster_enginenum: 0, cluster_response_time: {:infinity, []}, cluster_fee: :infinity} else %{cluster_taskque: cluster_taskque, cluster_enginenum: Enum.count(state.enginemap), cluster_response_time: {0,[]}, cluster_fee: (cluster_flops_sum / Enum.count(state.enginemap))} end end)
    {:reply, state, state}
  end

  def handle_call(:update_clusterinfo, _from, state) do
    cluster_taskque = state.enginemap
      |> Map.values()
      |> Enum.map(fn x -> Map.get(x, :taskque) end)
      |> Enum.reduce([], fn x, acc -> x ++ acc end)
    clusterinfo = Map.get(state,:clusterinfo)
    clusterinfo = Map.update!(clusterinfo, :cluster_taskque, fn now_taskque -> if now_taskque == "no engine" do "no engine" else cluster_taskque end end)
    clusterinfo = Map.update!(clusterinfo, :cluster_response_time, fn now_response_time -> if clusterinfo.cluster_taskque == [] do {0, []} else now_response_time end end)
    #IO.inspect clusterinfo.cluster_taskque
    state = Map.update!(state, :clusterinfo, fn _ -> clusterinfo end)
    {:reply, state, state}
  end

  def handle_cast({:send_task_response_time_in_cluster, task_response_time_in_cluster}, state) do
    File.write("responsetime.txt",Float.to_string(task_response_time_in_cluster) <> "\n",[:append])
    old_clusterinfo = Map.get(state, :clusterinfo)
    new_clusterinfo = old_clusterinfo
      |> Map.update!(:cluster_response_time, fn {_, nowdata} ->
          newdata = if length(nowdata) < 10 do
            nowdata ++ [task_response_time_in_cluster]
          else
            [_ | tl] = nowdata
            tl ++ [task_response_time_in_cluster]
          end
          new_response_time = Enum.sum(newdata) / length(newdata)
          {new_response_time, newdata}
        end)
    state = Map.update!(state, :clusterinfo, fn _ -> new_clusterinfo end)
    {:noreply, state}
  end

  def handle_call(:get_relayinfo, _from, state) do
    {:reply, state, state}
  end

  def handle_cast(:start_assigning, state) do
    devicepids = Map.keys(state.devicemap)

    new_devicemap = state
      |> Map.get(:devicemap)
      |> Enum.map(fn {devicepid, deviceinfo} -> {devicepid, Map.update!(deviceinfo, :creating_task, fn _ -> true end)} end)
      |> Enum.reduce(%{}, fn {devicepid, deviceinfo}, acc -> Map.put_new(acc, devicepid, deviceinfo) end)
    state = Map.update!(state, :devicemap, fn _ -> new_devicemap end)

    Enum.map(devicepids, fn pid ->
      GenServer.cast(pid, :taskflag_true)
      GenServer.cast(pid, :create_task)
    end)
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
    if assigned_cluster_pid == "tasknumlimit" do
      {:reply, state, state}
    else
      if self() == assigned_cluster_pid do
        File.write("clusterfee.txt",Float.to_string(state.clusterinfo.cluster_fee) <> "\n",[:append])
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
  end

  def handle_cast({:assign_task_in_cluster,task}, state) do
    File.write("clusterfee.txt",Float.to_string(state.clusterinfo.cluster_fee) <> "\n",[:append])
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
    clusterinfo = Map.get(state,:clusterinfo)
    clusterinfo = Map.update!(clusterinfo, :cluster_taskque, fn now_taskque -> if now_taskque == "no engine" do "no engine" else cluster_taskque end end)
    clusterinfo = Map.update!(clusterinfo, :cluster_response_time, fn now_response_time -> if clusterinfo.cluster_taskque == [] do {0, []} else now_response_time end end)
    #IO.inspect clusterinfo.cluster_taskque
    state = Map.update!(state, :clusterinfo, fn _ -> clusterinfo end)

    GenServer.cast(AlgoServer, {:update_relaymap, self(), state})

    {:noreply, state}
  end

  def handle_cast({:device_finish_creating_task, devicepid}, state) do

    now_devicemap = Map.get(state, :devicemap)
    new_devicemap = Map.update!(now_devicemap, devicepid, fn deviceinfo -> Map.update!(deviceinfo, :creating_task, fn _ -> false end) end)
    state = Map.update!(state, :devicemap, fn _ -> new_devicemap end)

    are_tasks_being_created? = state
      |> Map.get(:devicemap)
    IO.inspect are_tasks_being_created?
    are_tasks_being_created? = are_tasks_being_created?
      |> Enum.map(fn {_, val} -> Map.get(val, :creating_task) end)
      |> Enum.max()
    IO.inspect are_tasks_being_created?

    if are_tasks_being_created? == false do
      GenServer.cast(AlgoServer, {:relay_finish_handling_task, self()})
      IO.inspect "finish handling tasks in relay"
    end
    {:noreply, state}
  end

  def handle_call(:initialize_taskseed, _from, state) do
    state = Map.update!(state, :initialize_info, fn {algo, taskseed} -> {algo + 1, taskseed} end)
    {algo, taskseed} = state.initialize_info

    state
      |> Map.get(:devicemap)
      |> Map.keys()
      |> Enum.map(fn devicepid ->
        GenServer.cast(devicepid, {:set_randomseed, taskseed})
        GenServer.cast(devicepid, {:set_algo, algo})
      end)

    {:reply, state, state}
  end

  #client API
  def start_link(randomseed) do
    relayinfo = %{enginemap: %{}, devicemap: %{}, clusterinfo: %{}, initialize_info: {0, elem(randomseed, 2)}}
    {:ok, mypid} = GenServer.start_link(__MODULE__, relayinfo)
    enginenum = elem(randomseed, 0)
    devicenum = elem(randomseed, 1)
    enginerandomseed = if enginenum > 0 do 1..enginenum else 1..1 end
    devicerandomseed = if devicenum > 0 do 1..devicenum else 1..1 end
    _ = :rand.seed(:exsss, elem(randomseed, 2))
    devicerandomseed = Enum.map(devicerandomseed, fn _ -> :rand.uniform 1000000 end)
    _ = :rand.seed(:exsss, elem(randomseed, 3))
    enginerandomseed = Enum.map(enginerandomseed, fn _ -> :rand.uniform 1000000 end)
    IO.inspect enginerandomseed
    IO.inspect devicerandomseed

    if enginenum > 0 do
      Enum.map(enginerandomseed, fn seed ->
        {:ok, pid} = GEServer.start_link(%{relaypid: mypid, randomseed: seed})
        engineinfo = GenServer.call(pid, :get_engineinfo)
        GenServer.call(mypid, {:append_engineinfo, pid, engineinfo})
        GenServer.cast(pid, :update_engineinfo)
      end)
    end
    if devicenum > 0 do
      Enum.map(devicerandomseed, fn seed ->
        {:ok, pid} = EndDevice.start_link(%{taskflag: false, relaypid: mypid, randomseed: seed, algo: "taskque"})
        GenServer.call(mypid, {:append_deviceinfo, pid, %{taskflag: false, relaypid: mypid, creating_task: False}})
      end)
    end
    GenServer.call(mypid, :initialize_clusterinfo)
    {:ok, mypid}
  end
end
