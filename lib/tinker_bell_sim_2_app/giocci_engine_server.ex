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

    flops = :rand.uniform 100000
    """
    engine to relay 通信特性はr-r通信路に比べて十分強い通信路を想定し、考慮しなくて良いものとする
    bandwidth = :rand.uniform 100000
    delay = :rand.uniform 100000
    jitter = :rand.uniform 100000
    packetloss = :rand.uniform 10
    """
    #fee = :rand.uniform 10000 engineの使用料金は未検討

    #state = Map.merge(state, %{taskque: taskque_num, RtE_bandwidth: bandwidth, RtE_delay: delay, RtE_jitter: jitter, RtE_packetloss: packetloss, fee: fee})
    state = Map.merge(state, %{taskque: [], hidden_parameter_flops: flops})

    {:reply, state, state}
  end

  def handle_cast(:update_engineinfo, state) do

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

    {:noreply, state}
  end

  def handle_cast({:assign_task_to_engine, task},state) do

    state = Map.update!(state, :taskque, fn x -> x ++ [task.flo] end)
    IO.inspect({state.taskque, self()}, label: "engine taskque")

    {:noreply,state}
  end

  #Client API
  def start_link(engineinfo \\ %{relaypid: 0}) do
    {:ok, mypid} = GenServer.start_link(__MODULE__, engineinfo)
    GenServer.call(mypid, :initialize_engineinfo)
    {:ok, mypid}
  end
end
