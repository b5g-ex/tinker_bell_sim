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
    flops = if state.flopsflag do 5000 + :rand.uniform 10000 else 500 + :rand.uniform 1000 end
    #File.write("flops2.txt",Integer.to_string(flops) <> "\n",[:append])

    #engine to relay 通信特性はrelay to relay通信路に比べて十分強い通信路を想定し、考慮しなくて良いものとする

    state = Map.merge(state, %{taskque: [], task_assigned_time: [], hidden_parameter_flops: flops, processing_tasks_flag: False})

    {:reply, state, state}
  end

  def handle_cast(:update_engineinfo, state) do

    :timer.sleep(100)
    GenServer.cast(state.relaypid, {:update_enginemap, self(), state})
    GenServer.cast(self(), :update_engineinfo)

    {:noreply, state}
  end

  def handle_cast({:assign_task_to_engine, task, rtr_delay}, state) do

    old_taskque_num = length(state.taskque)
    state = Map.update!(state, :taskque, fn x -> x ++ [{task.flo, task.task_produced_time, rtr_delay, task.fee_for_this_task}] end)
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
    processing_time = round(elem(hdtask, 0) / state.hidden_parameter_flops * 1000)
    process_hdtask = Task.async(fn -> :timer.sleep(processing_time); :ok end)
    Task.await(process_hdtask, :infinity)

    [_ | tltask] = state.taskque
    state = Map.update!(state, :taskque, fn _ -> tltask end)
    [hdtask_assigned_time | tltask_assigned_time] = state.task_assigned_time
    state = Map.update!(state, :task_assigned_time, fn _ -> tltask_assigned_time end)

    task_finished_time = :erlang.monotonic_time()
    task_response_time_in_cluster = (task_finished_time - hdtask_assigned_time) / :math.pow(10,6)
    #IO.inspect task_response_time_in_cluster
    GenServer.cast(state.relaypid, {:send_task_response_time_in_cluster, hdtask, task_response_time_in_cluster, processing_time})

    if length(state.taskque) > 0 do
      GenServer.cast(self(), :process_a_task)
    end
    state = Map.update!(state,:processing_tasks_flag, fn _ -> if length(state.taskque) == 0 do False else True end end)

    {:noreply, state}
  end

  #Client API
  def start_link(engineinfo \\ %{relaypid: 0, randomseed: 0, flopsflag: false}) do
    {:ok, mypid} = GenServer.start_link(__MODULE__, engineinfo)
    GenServer.call(mypid, :initialize_engineinfo)
    {:ok, mypid}
  end
end
