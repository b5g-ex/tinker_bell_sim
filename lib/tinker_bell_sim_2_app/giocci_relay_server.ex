defmodule GRServer do
  use GenServer

  # GenServer API
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

  def handle_cast(:initialize_clusterinfo, state) do
    cluster_taskque =
      state.enginemap
      |> Map.values()
      |> Enum.map(fn x -> Map.get(x, :taskque) end)
      |> Enum.reduce([], fn x, acc -> x ++ acc end)

    # clusterの平均flopsから課金額を決定したい
    cluster_flops_sum =
      state.enginemap
      |> Map.values()
      |> Enum.map(fn x -> Map.get(x, :hidden_parameter_flops) end)
      |> Enum.reduce(0, fn x, acc -> x + acc end)

    # 応答時間予測値の計算方法
    predway = 2
    # 応答時間予測値の計算方法2つ目・3つ目におけるパラメータ
    history_attenuation = 0.25

    state =
      Map.update!(state, :clusterinfo, fn _ ->
        if state.enginemap == %{} do
          %{
            cluster_taskque: "no engine",
            cluster_enginenum: 0,
            cluster_response_time: {:infinity, [], :infinity, [], predway, history_attenuation},
            cluster_fee: :infinity,
            cluster_fee_magnification: 1.0
          }
        else
          %{
            cluster_taskque: cluster_taskque,
            cluster_enginenum: Enum.count(state.enginemap),
            cluster_response_time: {0, [], 0, [], predway, history_attenuation},
            cluster_fee: cluster_flops_sum / Enum.count(state.enginemap),
            cluster_fee_magnification: 1.0
          }
        end
      end)

    {:noreply, state}
  end

  def handle_call(:update_clusterinfo, _from, state) do
    cluster_taskque =
      state.enginemap
      |> Map.values()
      |> Enum.map(fn x -> Map.get(x, :taskque) end)
      |> Enum.reduce([], fn x, acc -> x ++ acc end)

    clusterinfo = Map.get(state, :clusterinfo)

    clusterinfo =
      Map.update!(clusterinfo, :cluster_taskque, fn now_taskque ->
        if now_taskque == "no engine" do
          "no engine"
        else
          cluster_taskque
        end
      end)

    # clusterinfo = Map.update!(clusterinfo, :cluster_response_time, fn now_response_time -> if clusterinfo.cluster_taskque == [] do {0, []} else now_response_time end end)
    # IO.inspect clusterinfo.cluster_taskque
    cluster_taskque_average =
      if clusterinfo.cluster_enginenum == "no engine" do
        0
      else
        length(clusterinfo.cluster_taskque) / clusterinfo.cluster_enginenum
      end

    cluster_fee_magnification =
      if cluster_taskque_average <= elem(state.costmodel, 0) do
        1.0
      else
        :math.pow(elem(state.costmodel, 1), cluster_taskque_average - elem(state.costmodel, 0))
      end

    clusterinfo =
      Map.update!(clusterinfo, :cluster_fee_magnification, fn _ -> cluster_fee_magnification end)

    state = Map.update!(state, :clusterinfo, fn _ -> clusterinfo end)
    {:reply, state, state}
  end

  def handle_cast(
        {:send_task_response_time_in_cluster, processed_task, task_response_time_in_cluster},
        state
      ) do
    data_dir = GenServer.call(AlgoServer, :get_data_dir)

    File.write(
      data_dir <> "responsetime_in_cluster.txt",
      Float.to_string(task_response_time_in_cluster) <> "\n",
      [:append]
    )

    File.write(
      data_dir <> "clusterfee.txt",
      Float.to_string(elem(processed_task, 0) * elem(processed_task, 3) / 1000) <> "\n",
      [:append]
    )

    File.write(
      data_dir <> "responsetime_in_cluster_mem.txt",
      Float.to_string(task_response_time_in_cluster) <> "\n",
      [:append]
    )

    File.write(
      data_dir <> "clusterfee_mem.txt",
      Float.to_string(elem(processed_task, 0) * elem(processed_task, 3) / 1000) <> "\n",
      [:append]
    )

    old_clusterinfo = Map.get(state, :clusterinfo)

    new_clusterinfo =
      old_clusterinfo
      |> Map.update!(:cluster_response_time, fn {now_response_time, nowdata,
                                                 now_response_time_history, nowhistory, predway,
                                                 history_attenuation} ->
        case predway do
          0 ->
            # 直近の実測値の平均
            newdata =
              if length(nowdata) < 3 do
                nowdata ++ [task_response_time_in_cluster]
              else
                [_ | tl] = nowdata
                tl ++ [task_response_time_in_cluster]
              end

            new_response_time = Enum.sum(newdata) / length(newdata)

            newhistory =
              if length(nowhistory) < 30 do
                nowhistory ++ [task_response_time_in_cluster]
              else
                [_ | tl] = nowhistory
                tl ++ [task_response_time_in_cluster]
              end

            new_response_time_history = Enum.sum(newhistory) / length(newhistory)

            new_response_time =
              if old_clusterinfo.cluster_taskque == [] do
                new_response_time_history
              else
                new_response_time
              end

            {new_response_time, newdata, new_response_time_history, newhistory, predway,
             history_attenuation}

          1 ->
            # 更新法（RIXX以前）
            {task_response_time_in_cluster + now_response_time * history_attenuation, nowdata,
             now_response_time_history, nowhistory, predway, history_attenuation}

          2 ->
            # 更新法（RIXX以降）
            {task_response_time_in_cluster * (1 - history_attenuation) +
               now_response_time * history_attenuation, nowdata, now_response_time_history,
             nowhistory, predway, history_attenuation}
        end
      end)

    state = Map.update!(state, :clusterinfo, fn _ -> new_clusterinfo end)
    GenServer.cast(self(), {:record_responsetime, processed_task})
    {:noreply, state}
  end

  def handle_cast({:record_responsetime, processed_task}, state) do
    # 帰りの通信遅延
    rtr_delay_sleep =
      Task.async(fn ->
        :timer.sleep(elem(elem(processed_task, 2), 1))
        :ok
      end)

    Task.await(rtr_delay_sleep, :infinity)

    task_processed_time = :erlang.monotonic_time()
    task_responsetime = (task_processed_time - elem(processed_task, 1)) / :math.pow(10, 6)

    data_dir = GenServer.call(AlgoServer, :get_data_dir)

    File.write(data_dir <> "responsetime.txt", Float.to_string(task_responsetime) <> "\n", [
      :append
    ])

    File.write(data_dir <> "responsetime_mem.txt", Float.to_string(task_responsetime) <> "\n", [
      :append
    ])

    {:noreply, state}
  end

  def handle_call(:get_relayinfo, _from, state) do
    {:reply, state, state}
  end

  def handle_cast(:start_assigning, state) do
    devicepids = Map.keys(state.devicemap)

    new_devicemap =
      state
      |> Map.get(:devicemap)
      |> Enum.map(fn {devicepid, deviceinfo} ->
        {devicepid, Map.update!(deviceinfo, :creating_task, fn _ -> true end)}
      end)
      |> Enum.reduce(%{}, fn {devicepid, deviceinfo}, acc ->
        Map.put_new(acc, devicepid, deviceinfo)
      end)

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

  def handle_call({:assign_request, task}, _from, state) do
    {assigned_cluster_pid, rtr_delay} =
      GenServer.call(AlgoServer, {:assign_algorithm, self(), task})

    if rtr_delay != "tasknumlimit" do
      data_dir = GenServer.call(AlgoServer, :get_data_dir)

      File.write(
        data_dir <> "RtRDelay.txt",
        Integer.to_string(elem(rtr_delay, 0) + elem(rtr_delay, 1)) <> "\n",
        [:append]
      )

      File.write(
        data_dir <> "RtRDelay_mem.txt",
        Integer.to_string(elem(rtr_delay, 0) + elem(rtr_delay, 1)) <> "\n",
        [:append]
      )
    end

    if assigned_cluster_pid == "tasknumlimit" do
      {:reply, state, state}
    else
      if self() == assigned_cluster_pid do
        # File.write("clusterfee.txt",Float.to_string(state.clusterinfo.cluster_fee) <> "\n",[:append])
        task =
          Map.put_new(
            task,
            :fee_for_this_task,
            state.clusterinfo.cluster_fee * state.clusterinfo.cluster_fee_magnification
          )

        # クラスター内assignはタスクキュー数のみで決定
        engine_taskque_scores =
          state.enginemap
          |> Enum.map(fn {key, val} -> {key, Map.get(val, :taskque)} end)
          |> Enum.map(fn {key, val} -> {key, length(val)} end)

        assigned_engine_pid =
          engine_taskque_scores
          |> Enum.min_by(fn {_, val} -> val + (:rand.uniform(100) - 1) / 100 end)
          |> elem(0)

        # relayserver内のengine_taskqueを更新
        GenServer.cast(self(), {:update_engine_taskque_in_enginemap, task, assigned_engine_pid})

        # 行きの通信遅延
        rtr_delay_sleep =
          Task.async(fn ->
            :timer.sleep(elem(rtr_delay, 0))
            :ok
          end)

        Task.await(rtr_delay_sleep, :infinity)
        GenServer.cast(assigned_engine_pid, {:assign_task_to_engine, task, rtr_delay})
      else
        GenServer.cast(assigned_cluster_pid, {:assign_task_in_cluster, task, rtr_delay})
      end

      {:reply, state, state}
    end
  end

  def handle_cast({:assign_task_in_cluster, task, rtr_delay}, state) do
    # File.write("clusterfee.txt", Float.to_string(state.clusterinfo.cluster_fee) <> "\n",[:append])
    task =
      Map.put_new(
        task,
        :fee_for_this_task,
        state.clusterinfo.cluster_fee * state.clusterinfo.cluster_fee_magnification
      )

    # クラスター内assignはタスクキュー数のみで決定
    engine_taskque_scores =
      state.enginemap
      |> Enum.map(fn {key, val} -> {key, Map.get(val, :taskque)} end)
      |> Enum.map(fn {key, val} -> {key, length(val)} end)

    assigned_engine_pid =
      engine_taskque_scores
      |> Enum.min_by(fn {_, val} -> val + (:rand.uniform(100) - 1) / 100 end)
      |> elem(0)

    # relayserver内のengine_taskqueを更新
    GenServer.cast(self(), {:update_engine_taskque_in_enginemap, task, assigned_engine_pid})

    # 行きの通信遅延
    rtr_delay_sleep =
      Task.async(fn ->
        :timer.sleep(elem(rtr_delay, 0))
        :ok
      end)

    Task.await(rtr_delay_sleep, :infinity)
    GenServer.cast(assigned_engine_pid, {:assign_task_to_engine, task, rtr_delay})

    {:noreply, state}
  end

  def handle_cast({:update_engine_taskque_in_enginemap, task, assigned_engine_pid}, state) do
    # relayserver内のengine_taskqueを更新
    old_engineinfo =
      state
      |> Map.get(:enginemap)
      |> Map.get(assigned_engine_pid)

    new_engineinfo =
      old_engineinfo
      |> Map.update!(:taskque, fn pre -> pre ++ [task.flo] end)

    new_enginemap = Map.update!(state.enginemap, assigned_engine_pid, fn _ -> new_engineinfo end)
    state = Map.update!(state, :enginemap, fn _ -> new_enginemap end)
    {:noreply, state}
  end

  def handle_cast({:update_enginemap, enginepid, new_engineinfo}, state) do
    now_enginemap = state.enginemap
    new_enginemap = Map.update!(now_enginemap, enginepid, fn _ -> new_engineinfo end)
    state = Map.update!(state, :enginemap, fn _ -> new_enginemap end)

    # update_clusterinfoをする
    cluster_taskque =
      state.enginemap
      |> Map.values()
      |> Enum.map(fn x -> Map.get(x, :taskque) end)
      |> Enum.reduce([], fn x, acc -> x ++ acc end)

    clusterinfo = Map.get(state, :clusterinfo)

    clusterinfo =
      Map.update!(clusterinfo, :cluster_taskque, fn now_taskque ->
        if now_taskque == "no engine" do
          "no engine"
        else
          cluster_taskque
        end
      end)

    # clusterinfo = Map.update!(clusterinfo, :cluster_response_time, fn now_response_time -> if clusterinfo.cluster_taskque == [] do {0, []} else now_response_time end end)
    # IO.inspect clusterinfo.cluster_taskque

    cluster_taskque_average =
      if clusterinfo.cluster_enginenum == "no engine" do
        0
      else
        length(clusterinfo.cluster_taskque) / clusterinfo.cluster_enginenum
      end

    cluster_fee_magnification =
      if cluster_taskque_average <= elem(state.costmodel, 0) do
        1.0
      else
        :math.pow(elem(state.costmodel, 1), cluster_taskque_average - elem(state.costmodel, 0))
      end

    clusterinfo =
      Map.update!(clusterinfo, :cluster_fee_magnification, fn _ -> cluster_fee_magnification end)

    state = Map.update!(state, :clusterinfo, fn _ -> clusterinfo end)

    GenServer.cast(AlgoServer, {:update_relaymap, self(), state})

    {:noreply, state}
  end

  def handle_cast({:device_finish_creating_task, devicepid}, state) do
    now_devicemap = Map.get(state, :devicemap)

    new_devicemap =
      Map.update!(now_devicemap, devicepid, fn deviceinfo ->
        Map.update!(deviceinfo, :creating_task, fn _ -> false end)
      end)

    state = Map.update!(state, :devicemap, fn _ -> new_devicemap end)

    are_tasks_being_created? =
      state
      |> Map.get(:devicemap)

    # IO.inspect are_tasks_being_created?
    are_tasks_being_created? =
      are_tasks_being_created?
      |> Enum.map(fn {_, val} -> Map.get(val, :creating_task) end)
      |> Enum.max()

    # IO.inspect are_tasks_being_created?

    if are_tasks_being_created? == false do
      GenServer.cast(AlgoServer, {:relay_finish_handling_task, self()})
      # IO.inspect "finish handling tasks in relay"
    end

    {:noreply, state}
  end

  def handle_call(:initialize_clusterinfo_and_taskseed, _from, state) do
    GenServer.cast(self(), :initialize_clusterinfo)

    state =
      Map.update!(state, :initialize_info, fn {algonum, taskseed} -> {algonum + 1, taskseed} end)

    {algonum, taskseed} = state.initialize_info

    devicepids =
      state
      |> Map.get(:devicemap)
      |> Map.keys()

    if length(devicepids) == 0 do
      {:reply, state, state}
    else
      _ = :rand.seed(:exsss, taskseed)

      Enum.map(devicepids, fn devicepid -> {devicepid, :rand.uniform(1_000_000)} end)
      |> Enum.map(fn {devicepid, devicetaskseed} ->
        GenServer.cast(devicepid, {:set_randomseed, devicetaskseed})
        GenServer.cast(devicepid, {:set_algo, algonum})
      end)

      {:reply, state, state}
    end
  end

  # client API
  def start_link(randomseed, costmodel) do
    # initialize_info: {algonum, taskseed(relay)}
    relayinfo = %{
      enginemap: %{},
      devicemap: %{},
      clusterinfo: %{},
      initialize_info: {0, elem(randomseed, 3)},
      costmodel: costmodel
    }

    {:ok, mypid} = GenServer.start_link(__MODULE__, relayinfo)
    enginenum = elem(randomseed, 0)
    devicenum = elem(randomseed, 1)

    enginerandomseed =
      if enginenum > 0 do
        1..enginenum
      else
        1..1
      end

    devicerandomseed =
      if devicenum > 0 do
        1..devicenum
      else
        1..1
      end

    _ = :rand.seed(:exsss, elem(randomseed, 3))
    devicerandomseed = Enum.map(devicerandomseed, fn _ -> :rand.uniform(1_000_000) end)
    _ = :rand.seed(:exsss, elem(randomseed, 4))
    enginerandomseed = Enum.map(enginerandomseed, fn _ -> :rand.uniform(1_000_000) end)
    IO.inspect(enginerandomseed)
    IO.inspect(devicerandomseed)

    if enginenum > 0 do
      Enum.map(enginerandomseed, fn seed ->
        {:ok, pid} =
          GEServer.start_link(%{relaypid: mypid, randomseed: seed, flopsflag: elem(randomseed, 2)})

        engineinfo = GenServer.call(pid, :get_engineinfo)
        GenServer.call(mypid, {:append_engineinfo, pid, engineinfo})
        GenServer.cast(pid, :update_engineinfo)
      end)
    end

    if devicenum > 0 do
      {algonum, _} = relayinfo.initialize_info

      Enum.map(devicerandomseed, fn seed ->
        {:ok, pid} =
          EndDevice.start_link(%{
            taskflag: false,
            relaypid: mypid,
            randomseed: seed,
            algo: "taskque"
          })

        GenServer.call(
          mypid,
          {:append_deviceinfo, pid, %{taskflag: false, relaypid: mypid, creating_task: False}}
        )

        GenServer.cast(pid, {:set_algo, algonum})
      end)
    end

    GenServer.cast(mypid, :initialize_clusterinfo)
    {:ok, mypid}
  end
end
