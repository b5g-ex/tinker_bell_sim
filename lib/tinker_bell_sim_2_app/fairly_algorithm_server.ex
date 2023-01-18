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

  def handle_call({:append_relaynetwork_feature_table, relaynetworkseed}, _from, state) do
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

  def handle_cast(:initialize_tasknum, state) do
    state = Map.update(state, :tasknum, 0, fn _ -> 0 end)
    {:noreply, state}
  end

  def handle_call({:append_tasknumlimit, tasknumlimit}, _from, state) do
    IO.inspect "Debug 1"
    state = Map.put_new(state, :tasknumlimit, tasknumlimit)
    IO.inspect "Debug 2"
    {:reply, state, state}
  end

  def handle_cast({:initialize_creating_task_flag, initial_flag}, state) do
    relay_handling_task_flag = state
      |> Map.delete(:relaynetwork_bandwidth)
      |> Map.delete(:relaynetwork_delay)
      |> Map.delete(:tasknum)
      |> Map.delete(:tasknumlimit)
      |> Map.delete(:creating_task_flag)
      |> Map.keys()
      |> Enum.reduce(%{}, fn relaypid, acc ->
          devicemap = state
            |> Map.get(relaypid)
            |> Map.get(:devicemap)
          if devicemap == %{} do
            Map.put_new(acc, relaypid, false)
          else
            Map.put_new(acc, relaypid, initial_flag)
          end
        end)
    state = Map.update(state, :creating_task_flag, relay_handling_task_flag, fn _ -> relay_handling_task_flag end)
    {:noreply, state}
  end

  def handle_call({:assign_algorithm, devicepid, device_connected_relaypid, task}, _from, state) do

    state = Map.update!(state, :tasknum, fn prev -> prev + 1 end)
    #IO.inspect state.tasknum
    #IO.inspect state.creating_task_flag

    case task.algo do
      "taskque" ->
        clustermap = state
          |> Map.delete(:relaynetwork_bandwidth)
          |> Map.delete(:relaynetwork_delay)
          |> Map.delete(:tasknum)
          |> Map.delete(:tasknumlimit)
          |> Map.delete(:creating_task_flag)
          |> Enum.map(fn {key, val} -> {key, Map.get(val, :clusterinfo)} end)
        cluster_taskque_num = Enum.map(clustermap, fn {key, val} -> {key, if val.cluster_taskque == "no engine" do :infinity else length(val.cluster_taskque) end} end)
        min_taskque_cluster_pid = cluster_taskque_num
          |> Enum.min_by(fn {_, val} -> if val == :infinity do :infinity else val + (:rand.uniform(100) - 1) / 100 end end) #同率1位をランダムに選択したい
          |> elem(0)

        #デバッグ用標準出力↓
        clustermap = state
          |> Map.delete(:relaynetwork_bandwidth)
          |> Map.delete(:relaynetwork_delay)
          |> Map.delete(:tasknum)
          |> Map.delete(:tasknumlimit)
          |> Map.delete(:creating_task_flag)
          |> Enum.map(fn {key, val} -> {key, Map.get(val, :clusterinfo)} end)
          |> Enum.map(fn {key, val} -> {key, Map.get(val, :cluster_response_time), Map.get(val, :cluster_taskque), Map.get(val, :cluster_fee)} end)
          |> Enum.map(fn {key, val1, val2, val3} -> if val2 == "no engine" do {key, elem(val1, 0), val2, val3} else {key, elem(val1, 0), length(val2), val3} end end)
        #IO.inspect clustermap
        #デバッグ用標準出力↑

        #IO.inspect(min_taskque_cluster_pid, label: "assigned cluster")
        if state.tasknum == state.tasknumlimit do
          state
            |> Map.delete(:relaynetwork_bandwidth)
            |> Map.delete(:relaynetwork_delay)
            |> Map.delete(:tasknum)
            |> Map.delete(:tasknumlimit)
            |> Map.delete(:creating_task_flag)
            |> Map.keys()
            |> Enum.map(fn pid ->
                GenServer.cast(pid, :stop_assigning)
                {:ok}
              end)
        end
        if state.tasknum > state.tasknumlimit do
          {:reply, "tasknumlimit", state}
        else
          {:reply, min_taskque_cluster_pid, state}
        end

      "delay" ->
        delaymap = Map.get(state.relaynetwork_delay, device_connected_relaypid)
        min_delay_cluster_pid = delaymap
          |> Enum.min_by(fn {_, val} -> val end)
          |> elem(0)

        #デバッグ用標準出力↓
        clustermap = state
          |> Map.delete(:relaynetwork_bandwidth)
          |> Map.delete(:relaynetwork_delay)
          |> Map.delete(:tasknum)
          |> Map.delete(:tasknumlimit)
          |> Map.delete(:creating_task_flag)
          |> Enum.map(fn {key, val} -> {key, Map.get(val, :clusterinfo)} end)
          |> Enum.map(fn {key, val} -> {key, Map.get(val, :cluster_response_time), Map.get(val, :cluster_taskque), Map.get(val, :cluster_fee)} end)
          |> Enum.map(fn {key, val1, val2, val3} -> if val2 == "no engine" do {key, elem(val1, 0), val2, val3} else {key, elem(val1, 0), length(val2), val3} end end)
        #IO.inspect clustermap
        #デバッグ用標準出力↑

        #IO.inspect(min_delay_cluster_pid, label: "assigned cluster")
        if state.tasknum == state.tasknumlimit do
          state
            |> Map.delete(:relaynetwork_bandwidth)
            |> Map.delete(:relaynetwork_delay)
            |> Map.delete(:tasknum)
            |> Map.delete(:tasknumlimit)
            |> Map.delete(:creating_task_flag)
            |> Map.keys()
            |> Enum.map(fn pid ->
                GenServer.cast(pid, :stop_assigning)
                {:ok}
              end)
        end
        if state.tasknum > state.tasknumlimit do
          {:reply, "tasknumlimit", state}
        else
          {:reply, min_delay_cluster_pid, state}
        end

      "bandwidth" ->
        bandwidthmap = Map.get(state.relaynetwork_bandwidth, device_connected_relaypid)
        max_bandwidth_cluster_pid = bandwidthmap
          |> Enum.max_by(fn {_, val} -> val end)
          |> elem(0)

        #デバッグ用標準出力↓
        clustermap = state
          |> Map.delete(:relaynetwork_bandwidth)
          |> Map.delete(:relaynetwork_delay)
          |> Map.delete(:tasknum)
          |> Map.delete(:tasknumlimit)
          |> Map.delete(:creating_task_flag)
          |> Enum.map(fn {key, val} -> {key, Map.get(val, :clusterinfo)} end)
          |> Enum.map(fn {key, val} -> {key, Map.get(val, :cluster_response_time), Map.get(val, :cluster_taskque), Map.get(val, :cluster_fee)} end)
          |> Enum.map(fn {key, val1, val2, val3} -> if val2 == "no engine" do {key, elem(val1, 0), val2, val3} else {key, elem(val1, 0), length(val2), val3} end end)
        #IO.inspect clustermap
        #デバッグ用標準出力↑

        #IO.inspect(max_bandwidth_cluster_pid, label: "assigned cluster")
        if state.tasknum == state.tasknumlimit do
          state
            |> Map.delete(:relaynetwork_bandwidth)
            |> Map.delete(:relaynetwork_delay)
            |> Map.delete(:tasknum)
            |> Map.delete(:tasknumlimit)
            |> Map.delete(:creating_task_flag)
            |> Map.keys()
            |> Enum.map(fn pid -> GenServer.cast(pid, :stop_assigning) end)
        end
        if state.tasknum > state.tasknumlimit do
          {:reply, "tasknumlimit", state}
        else
          {:reply, max_bandwidth_cluster_pid, state}
        end

      "responsetime" ->
        cluster_responsetime_in_cluster = state
          |> Map.delete(:relaynetwork_bandwidth)
          |> Map.delete(:relaynetwork_delay)
          |> Map.delete(:tasknum)
          |> Map.delete(:tasknumlimit)
          |> Map.delete(:creating_task_flag)
          |> Enum.map(fn {key, val} -> {key, Map.get(val, :clusterinfo)} end)
          |> Enum.map(fn {key, val} -> {key, Map.get(val, :cluster_response_time)} end)
          |> Enum.map(fn {key, val} -> {key, elem(val, 0)} end)
        delaymap = Map.get(state.relaynetwork_delay, device_connected_relaypid)
        min_responsetime_cluster_pid = cluster_responsetime_in_cluster
          |> Enum.map(fn {key, val} -> if val == :infinity do {key, val} else {key, val + Map.get(delaymap, key)} end end)
          |> Enum.min_by(fn {_, val} -> if val == :infinity do :infinity else val + (:rand.uniform(100) - 1) / 100 end end) #同率1位をランダムに選択したい
          |> elem(0)

        #デバッグ用標準出力↓
        clustermap = state
          |> Map.delete(:relaynetwork_bandwidth)
          |> Map.delete(:relaynetwork_delay)
          |> Map.delete(:tasknum)
          |> Map.delete(:tasknumlimit)
          |> Map.delete(:creating_task_flag)
          |> Enum.map(fn {key, val} -> {key, Map.get(val, :clusterinfo)} end)
          |> Enum.map(fn {key, val} -> {key, Map.get(val, :cluster_response_time), Map.get(val, :cluster_taskque), Map.get(val, :cluster_fee)} end)
          |> Enum.map(fn {key, val1, val2, val3} -> if val2 == "no engine" do {key, elem(val1, 0), val2, val3} else {key, elem(val1, 0), length(val2), val3} end end)
        #IO.inspect clustermap
        #デバッグ用標準出力↑
        if state.tasknum == state.tasknumlimit do
          state
            |> Map.delete(:relaynetwork_bandwidth)
            |> Map.delete(:relaynetwork_delay)
            |> Map.delete(:tasknum)
            |> Map.delete(:tasknumlimit)
            |> Map.delete(:creating_task_flag)
            |> Map.keys()
            |> Enum.map(fn pid -> GenServer.cast(pid, :stop_assigning) end)
        end
        if state.tasknum > state.tasknumlimit do
          {:reply, "tasknumlimit", state}
        else
          {:reply, min_responsetime_cluster_pid, state}
        end

      "clusterfee" ->
        cluster_responsetime_and_fee_in_cluster = state
          |> Map.delete(:relaynetwork_bandwidth)
          |> Map.delete(:relaynetwork_delay)
          |> Map.delete(:tasknum)
          |> Map.delete(:tasknumlimit)
          |> Map.delete(:creating_task_flag)
          |> Enum.map(fn {key, val} -> {key, Map.get(val, :clusterinfo)} end)
          |> Enum.map(fn {key, val} -> {key, Map.get(val, :cluster_response_time), Map.get(val, :cluster_fee)} end)
          |> Enum.map(fn {key, val1, val2} -> {key, elem(val1, 0), val2} end)
        delaymap = Map.get(state.relaynetwork_delay, device_connected_relaypid)
        cluster_responsetime_and_fee = cluster_responsetime_and_fee_in_cluster
          |> Enum.map(fn {key, restime, fee} ->
              if restime == :infinity do
                {key, :infinity, :infinity}
              else
                if restime + Map.get(delaymap, key) >= task.restime_limit do
                  {key, restime + Map.get(delaymap, key), :infinity}
                else
                  {key, restime + Map.get(delaymap, key), fee}
                end
              end
            end)

        opt_fee_cluster_pid = cluster_responsetime_and_fee
          |> Enum.min_by(fn {_, _, fee} -> fee end)
          |> elem(0)

        #デバッグ用標準出力↓
        clustermap = state
          |> Map.delete(:relaynetwork_bandwidth)
          |> Map.delete(:relaynetwork_delay)
          |> Map.delete(:tasknum)
          |> Map.delete(:tasknumlimit)
          |> Map.delete(:creating_task_flag)
          |> Enum.map(fn {key, val} -> {key, Map.get(val, :clusterinfo)} end)
          |> Enum.map(fn {key, val} -> {key, Map.get(val, :cluster_response_time), Map.get(val, :cluster_taskque), Map.get(val, :cluster_fee)} end)
          |> Enum.map(fn {key, val1, val2, val3} -> if val2 == "no engine" do {key, elem(val1, 0), val2, val3} else {key, elem(val1, 0), length(val2), val3} end end)
        #IO.inspect clustermap
        #デバッグ用標準出力↑

        if state.tasknum == state.tasknumlimit do
          state
            |> Map.delete(:relaynetwork_bandwidth)
            |> Map.delete(:relaynetwork_delay)
            |> Map.delete(:tasknum)
            |> Map.delete(:tasknumlimit)
            |> Map.delete(:creating_task_flag)
            |> Map.keys()
            |> Enum.map(fn pid -> GenServer.cast(pid, :stop_assigning) end)
        end
        if state.tasknum > state.tasknumlimit do
          {:reply, "tasknumlimit", state}
        else
          {:reply, opt_fee_cluster_pid, state}
        end

    end

  end

  def handle_cast({:relay_finish_handling_task, relaypid}, state) do
    creating_task_flag = state
      |> Map.get(:creating_task_flag)
      |> Map.update!(relaypid, fn _ -> false end)
    state = Map.update!(state, :creating_task_flag, fn _ -> creating_task_flag end)

    are_tasks_being_handled_in_relay? = state
      |> Map.get(:creating_task_flag)
      |> Enum.map(fn {_, val} -> val end)
      |> Enum.max()

    if are_tasks_being_handled_in_relay? == false do
      GenServer.cast(AlgoServer, :wait_for_tasklists)
    end
    {:noreply, state}
  end

  def handle_cast(:wait_for_tasklists, state) do
    max_taskque_num = state
      |> Map.delete(:relaynetwork_bandwidth)
      |> Map.delete(:relaynetwork_delay)
      |> Map.delete(:tasknum)
      |> Map.delete(:tasknumlimit)
      |> Map.delete(:creating_task_flag)
      |> Enum.map(fn {_, val} -> Map.get(val, :clusterinfo) end)
      |> Enum.map(fn clusterinfo -> Map.get(clusterinfo, :cluster_taskque) end)
      |> Enum.map(fn cluster_taskque -> if cluster_taskque == "no engine" do 0 else length(cluster_taskque) end end)
      |> Enum.max()
    if max_taskque_num == 0 do
      GenServer.cast(AlgoServer, :initialize_parameters)
    else
      wait_for_tasklists = Task.async(fn -> :timer.sleep(1000); :ok end)
      Task.await(wait_for_tasklists)
      GenServer.cast(AlgoServer, :wait_for_tasklists)
    end
    {:noreply, state}
  end

  def handle_cast(:initialize_parameters, state) do
    {:ok, strdat} = File.read("responsetime.txt")
    floatdat = strdat
      |> String.split("\n")
      |> List.delete("")
      |> Enum.map(fn x -> elem(Float.parse(x),0) end)
    average_restime = Enum.sum(floatdat) / length(floatdat)
    File.write("responsetime_average.txt",Float.to_string(average_restime) <> "\n",[:append])

    {:ok, strdat} = File.read("clusterfee.txt")
    floatdat = strdat
      |> String.split("\n")
      |> List.delete("")
      |> Enum.map(fn x -> elem(Float.parse(x),0) end)
    sum_clusterfee = Enum.sum(floatdat)
    File.write("clusterfee_average.txt",Float.to_string(sum_clusterfee) <> "\n",[:append])

    File.write("responsetime.txt","")
    File.write("clusterfee.txt","")

    #パラメータを初期化して次の実験へ
    GenServer.cast(AlgoServer, :initialize_tasknum)
    relaypids = state
      |> Map.delete(:relaynetwork_bandwidth)
      |> Map.delete(:relaynetwork_delay)
      |> Map.delete(:tasknum)
      |> Map.delete(:tasknumlimit)
      |> Map.delete(:creating_task_flag)
      |> Map.keys()
    Enum.map(relaypids, fn relaypid -> GenServer.call(relaypid, :initialize_clusterinfo_and_taskseed) end)

    #start_assigning
    GenServer.cast(AlgoServer, {:initialize_creating_task_flag, true})
    Enum.map(relaypids, fn relaypid -> GenServer.cast(relaypid, :start_assigning) end)

    {:noreply, state}
  end

  def handle_cast({:update_relaymap, relaypid, new_relayinfo}, state) do
    state = Map.update!(state, relaypid, fn _ -> new_relayinfo end)
    #IO.inspect "engineinfo updated"
    {:noreply, state}
  end

  #Client API
  def start_link(taskseed, engineseed, tasknumlimit) do
    File.write("responsetime.txt","")
    File.write("clusterfee.txt","")
    File.write("responsetime_average.txt","")
    File.write("clusterfee_average.txt","")
    relayrandomseed = [{0,10,false},{0,10,false},{0,10,false},{5,5,false},{5,5,false},{5,5,false},{10,0,true},{10,0,true},{10,0,true}]
    #relayrandomseed = [{0,10,true},{0,10,true},{0,10,true},{5,5,true},{5,5,true},{5,5,true},{10,0,true},{10,0,true},{10,0,true}]
    #relayrandomseed = [{0,15,false},{5,20,false},{5,5,false},{5,5,false},{10,0,true},{10,0,true},{10,0,true}]
    _ = :rand.seed(:exsss, taskseed)
    relayrandomseed = Enum.map(relayrandomseed, fn {engine, device, flopsflag} -> {engine, device, flopsflag, :rand.uniform 1000000} end)
    _ = :rand.seed(:exsss, engineseed)
    relayrandomseed = Enum.map(relayrandomseed, fn {engine, device, flopsflag, devicerandomseed} -> {engine, device, flopsflag, devicerandomseed, :rand.uniform 1000000} end)
    GenServer.start_link(__MODULE__, %{}, name: AlgoServer)
    Enum.map(relayrandomseed, fn seed ->
      {:ok, pid} = GRServer.start_link(seed)
      relayinfo = GenServer.call(pid, :get_relayinfo)
      GenServer.call(AlgoServer, {:append_relayinfo, pid, relayinfo})
    end)
    GenServer.call(AlgoServer, {:append_relaynetwork_feature_table, :rand.uniform 1000000}) #engineseedによって固定されている
    GenServer.cast(AlgoServer, :initialize_tasknum)
    GenServer.call(AlgoServer, {:append_tasknumlimit, tasknumlimit})
    GenServer.cast(AlgoServer, {:initialize_creating_task_flag, false})
    IO.inspect GenServer.call(AlgoServer, :get_relaymap)
    IO.inspect relayrandomseed
  end

  def start_assigning() do
    GenServer.cast(AlgoServer, {:initialize_creating_task_flag, true})
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
