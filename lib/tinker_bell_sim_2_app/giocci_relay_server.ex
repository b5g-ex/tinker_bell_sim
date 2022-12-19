defmodule GRServer do
  use GenServer

  #GenServer API
  def init(relayinfo) do
    {:ok, relayinfo}
  end

  def handle_call({:append_engineinfo, pid, engineinfo}, _from, state) do
    now_enginemap = state.enginemap
    new_enginemap = Map.put_new(now_enginemap, pid, engineinfo)
    state = Map.update!(state, :enginemap, fn now_enginemap -> new_enginemap end)
    {:reply, state, state}
  end

  def handle_call({:append_deviceinfo, pid, deviceinfo}, _from, state) do
    now_devicemap = state.devicemap
    new_devicemap = Map.put_new(now_devicemap, pid, deviceinfo)
    state = Map.update!(state, :devicemap, fn now_devicemap -> new_devicemap end)
    {:reply, state, state}
  end

  def handle_call(:update_clusterinfo, _from, state) do
    cluster_taskque = state.enginemap
      |> Map.values()
      |> Enum.map(fn x -> Map.get(x, :taskque) end)
      |> Enum.reduce([], fn x, acc -> x ++ acc end)
    state = Map.update!(state, :clusterinfo, fn now -> %{cluster_taskque: cluster_taskque} end)
    {:reply, state, state}
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
    waiting_tasks = state.waiting_tasks
    waiting_tasks = Map.put_new(waiting_tasks, devicepid, task)
    state = Map.update!(state, :waiting_tasks, fn now -> waiting_tasks end)

    assigned_cluster_pid = GenServer.call(AlgoServer, {:assign_algorithm, task})
    if self() == assigned_cluster_pid do
      #クラスター内assignはタスクキュー数のみで決定
      engine_taskque_scores = state.enginemap
        |> Enum.map(fn {key, val} -> {key, Map.get(val, :taskque)} end)
        |> Enum.map(fn {key, val} -> {key, length(val)} end)
      min_taskque_num = engine_taskque_scores
        |> Enum.map(fn {key, val} -> val end)
        |> Enum.min()
      assigned_engine_pid = engine_taskque_scores
        |> Enum.find(fn {key, val} -> val == min_taskque_num end)
        |> elem(0)

      GenServer.cast(assigned_engine_pid, {:assign_task_to_engine, task})

    else
      GenServer.cast(assigned_cluster_pid, {:assign_task_in_cluster,task})
    end

    {:reply, state, state}
  end

  def handle_cast({:assign_task_in_cluster,task}, state) do
    #クラスター内assignはタスクキュー数のみで決定
    engine_taskque_scores = state.enginemap
      |> Enum.map(fn {key, val} -> {key, Map.get(val, :taskque)} end)
      |> Enum.map(fn {key, val} -> {key, length(val)} end)
    min_taskque_num = engine_taskque_scores
      |> Enum.map(fn {key, val} -> val end)
      |> Enum.min()
    assigned_engine_pid = engine_taskque_scores
      |> Enum.find(fn {key, val} -> val == min_taskque_num end)
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
    state = Map.update!(state, :clusterinfo, fn now -> %{cluster_taskque: cluster_taskque} end)

    GenServer.cast(AlgoServer, {:update_relaymap, self(), state})

    {:noreply, state}
  end

  #client API
  def start_link(relayinfo \\ %{enginemap: %{}, devicemap: %{}, clusterinfo: %{}, waiting_tasks: %{}}) do
    {:ok, mypid} = GenServer.start_link(__MODULE__, relayinfo)
    for times <- 0..2 do
      {:ok, pid} = GEServer.start_link(%{relaypid: mypid})
      engineinfo = GenServer.call(pid, :get_engineinfo)
      GenServer.call(mypid, {:append_engineinfo, pid, engineinfo})
      GenServer.cast(pid, :update_engineinfo)
    end
    for times <- 0..2 do
      {:ok, pid} = EndDevice.start_link(%{taskflag: false, relaypid: mypid})
      GenServer.call(mypid, {:append_deviceinfo, pid, %{taskflag: false, relaypid: mypid}})
    end
    GenServer.call(mypid, :update_clusterinfo)
    {:ok, mypid}
  end
end
