#エンジンサーバーに関するリソース情報の生成機能のみ
defmodule GEServer do
  use GenServer

  #GenServer API
  def init(engineinfo) do
    {:ok, engineinfo}
  end

  def handle_call(:get_engineinfo, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:initialize_engineinfo, _from, state) do

    flops = :rand.uniform 10000
    """
    engine to relay 通信特性はr-r通信路に比べて十分強い通信路を想定し、考慮しなくて良いものとする
    bandwidth = :rand.uniform 100000
    delay = :rand.uniform 100000
    jitter = :rand.uniform 100000
    packetloss = :rand.uniform 10
    """
    #fee = :rand.uniform 10000 engineの使用料金は未検討

    #state = Map.merge(state, %{taskque: taskque_num, RtE_bandwidth: bandwidth, RtE_delay: delay, RtE_jitter: jitter, RtE_packetloss: packetloss, fee: fee})
    state = Map.merge(state, %{taskque: [100,200,300], hidden_parameter_flops: flops})

    {:reply, state, state}
  end

  def handle_cast(:update_engineinfo, state) do

    :timer.sleep(100)
    state = Map.update!(state, :taskque, fn now -> now end) #head taskを100ms分減らす
    GenServer.cast(state.relaypid, {:update_enginemap, self(), state})

    GenServer.cast(self(), :update_engineinfo)

    {:noreply, state}
  end

  def handle_cast({:assign_task_to_engine, task},state) do

    state = Map.update!(state, :taskque, fn x -> x ++ [task.flo] end)
    IO.inspect state.taskque

    {:noreply,state}
  end

  #Client API
  def start_link(engineinfo \\ %{relaypid: 0}) do
    {:ok, mypid} = GenServer.start_link(__MODULE__, engineinfo)
    GenServer.call(mypid, :initialize_engineinfo)
    {:ok, mypid}
  end
end
