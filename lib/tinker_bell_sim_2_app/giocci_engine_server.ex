#エンジンサーバーに関するリソース情報の生成機能のみ
defmodule GEServer do
  use GenServer

  #GenServer API
  def init(engineinfo) do
    {:ok, engineinfo}
  end

  def handle_call(:get_engineinfo, _from, state) do
    #engineinfo = Map.merge(state, %{taskque: GenServer.call(state.taskque_pid, :get_taskque)})
    {:reply, state, state}
  end

  def handle_call(:initialize_engineinfo, _from, state) do

    _ = :rand.seed(:exsss, state.randomseed)
    flops = 10000 + :rand.uniform 10000

    #engine to relay 通信特性はrelay to relay通信路に比べて十分強い通信路を想定し、考慮しなくて良いものとする
    #fee = :rand.uniform 10000 engineの使用料金は未検討

    #state = Map.merge(state, %{taskque_pid: taskque_pid, hidden_parameter_flops: flops})
    state = Map.merge(state, %{taskque: [], task_assigned_time: [], hidden_parameter_flops: flops, processing_tasks_flag: False})

    {:reply, state, state}
  end

  def handle_cast(:update_engineinfo, state) do

    #GenServer.cast(state.taskque_pid, :update_taskque)

    """
    :timer.sleep(100)
    flo_at_iter = round(state.hidden_parameter_flops * 0.1) #100msでの処理能力
    que = case length(state.taskque) do
      0 -> []
      1 -> [hd] = state.taskque
        if hd <= flo_at_iter do
          []
        else
          [hd - flo_at_iter]
        end
      _ -> [hd | tl] = state.taskque
        if hd <= flo_at_iter do
          [tlhead | tltail] = tl
          [tlhead + hd - flo_at_iter | tltail]
        else
          [hd - flo_at_iter | tl]
        end
    end
    state = Map.update!(state, :taskque, fn x -> que end) #head taskを100ms分減らす
    #[hdtask | tltask] = state.taskque
    #if hdtask <= 0 do
    #  [new_hdtask | new_tltask] = tltask
    #  state = Map.update!(state, :taskque, fn now -> [new_hdtask + hdtask | new_tltask] end)
    #end
    GenServer.cast(state.relaypid, {:update_enginemap, self(), state})

    GenServer.cast(self(), :update_engineinfo)
    """
    :timer.sleep(100)
    GenServer.cast(state.relaypid, {:update_enginemap, self(), state})
    GenServer.cast(self(), :update_engineinfo)

    {:noreply, state}
  end

  def handle_cast({:assign_task_to_engine, task}, state) do

    old_taskque_num = length(state.taskque)
    state = Map.update!(state, :taskque, fn x -> x ++ [task.flo] end)
    state = Map.update!(state, :task_assigned_time, fn x -> x ++ [:erlang.monotonic_time()] end)
    #IO.inspect({self(), state.taskque}, label: "assigned engine & taskque") 標準出力
    if old_taskque_num == 0 and state.processing_tasks_flag == False do
      #IO.inspect "gyoooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo"
      GenServer.cast(self(), :process_a_task)
    end

    {:noreply,state}
  end

  """
  def handle_cast(:process_a_task, state) do
    if length(state.taskque) > 0 do
      [hdtask | _] = state.taskque
      process_hdtask = Task.async(fn -> :timer.sleep(round(hdtask / state.hidden_parameter_flops * 1000)); :ok end)
      Task.await(process_hdtask, :infinity)
      finish_a_task = Task.async(fn -> GenServer.cast(self(), :finish_processing_a_task); :ok end)
      Task.await(finish_a_task, :infinity)
    end
    {:noreply, state}
  end

  def handle_cast(:finish_processing_a_task, state) do
    IO.inspect "in"
    state = Map.update!(state,:finishing_a_task_flag, fn _ -> True end)
    [_ | tltask] = state.taskque
    state = Map.update!(state, :taskque, fn _ -> tltask end)
    [hdtask_assigned_time | tltask_assigned_time] = state.task_assigned_time
    state = Map.update!(state, :task_assigned_time, fn _ -> tltask_assigned_time end)
    task_finished_time = :erlang.monotonic_time()
    task_response_time_in_cluster = (task_finished_time - hdtask_assigned_time) / :math.pow(10,6)
    #IO.inspect task_response_time_in_cluster
    GenServer.cast(state.relaypid, {:send_task_response_time_in_cluster, task_response_time_in_cluster})
    IO.inspect "out"
    GenServer.cast(self(), :process_a_task)
    state = Map.update!(state,:finishing_a_task_flag, fn _ -> False end)
    {:noreply, state}
  end
  """
  def handle_cast(:process_a_task, state) do

    #IO.inspect "kaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    state = Map.update!(state,:processing_tasks_flag, fn _ -> True end)

    [hdtask | _] = state.taskque
    process_hdtask = Task.async(fn -> :timer.sleep(round(hdtask / state.hidden_parameter_flops * 1000)); :ok end)
    Task.await(process_hdtask, :infinity)

    [_ | tltask] = state.taskque
    state = Map.update!(state, :taskque, fn _ -> tltask end)
    [hdtask_assigned_time | tltask_assigned_time] = state.task_assigned_time
    state = Map.update!(state, :task_assigned_time, fn _ -> tltask_assigned_time end)

    task_finished_time = :erlang.monotonic_time()
    task_response_time_in_cluster = (task_finished_time - hdtask_assigned_time) / :math.pow(10,6)
    #IO.inspect task_response_time_in_cluster
    GenServer.cast(state.relaypid, {:send_task_response_time_in_cluster, task_response_time_in_cluster})

    if length(state.taskque) > 0 do
      GenServer.cast(self(), :process_a_task)
    end
    state = Map.update!(state,:processing_tasks_flag, fn _ -> if length(state.taskque) == 0 do False else True end end)

    {:noreply, state}
  end

  #Client API
  def start_link(engineinfo \\ %{relaypid: 0, randomseed: 0}) do
    {:ok, mypid} = GenServer.start_link(__MODULE__, engineinfo)
    #{:ok, taskque_pid} = GETaskque.start_link(%{enginepid: self(), taskque: []})
    #GenServer.call(mypid, {:initialize_engineinfo, taskque_pid})
    GenServer.call(mypid, :initialize_engineinfo)
    {:ok, mypid}
  end
end
