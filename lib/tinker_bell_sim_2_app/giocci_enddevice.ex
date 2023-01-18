#不定期にタスクを発生させ、Relayにタスク情報を送る機能のみ
defmodule EndDevice do
  use GenServer

  #GenServer API
  def init(deviceinfo) do
    {:ok, deviceinfo}
  end

  def handle_cast(:taskflag_true, state) do
    state = Map.replace!(state, :taskflag, true)
    {:noreply, state}
  end

  def handle_cast(:taskflag_false, state) do
    state = Map.replace!(state, :taskflag, false)
    {:noreply, state}
  end

  def handle_cast({:set_randomseed, seed}, state) do
    state = Map.update!(state, :randomseed, fn _ -> seed end)
    {:noreply, state}
  end

  def handle_cast({:set_algo, algonum}, state) do
    state = Map.update!(state, :algo, fn _ ->
      case algonum do
        #各iterationにおけるアルゴリズム決定部分
        #algonumは今何回目の試行かを示すパラメータ(0-indexed)
        #アルゴリズム名称は
        # taskque       タスクキュー最小Clusterへ割付
        # delay         R-R通信遅延最小化
        # bandwidth     R-R通信帯域幅最大化
        # responsetime  応答時間最小化
        # clusterfee    Cluster利用コスト最適化（応答時間予測値が55行目のrestime_limitを超えないClusterの中でコスト最小のものを選択）
        x when 0 <= x and x <= 1 -> "taskque"
        x when 2 <= x and x <= 2 -> "delay"
        x when 3 <= x and x <= 3 -> "bandwidth"
        x when 4 <= x and x <= 4 -> "responsetime"
        x when 5 <= x and x <= 5 -> "clusterfee"
        _ -> raise "end" #指定回数の試行が終わったらエラーを吐かせて止めます
      end
    end)
    {:noreply, state}
  end

  def handle_cast(:create_task, state) do
    _ = :rand.seed(:exsss, state.randomseed)
    timerrand = :rand.uniform 5000
    #File.write("outputtimer2.txt",Integer.to_string(timerrand) <> "\n",[:append])
    :timer.sleep(2500 + timerrand) #5秒平均
    #create task ↓
    florand = :rand.uniform 5000
    #File.write("outputflo2.txt",Integer.to_string(florand) <> "\n",[:append])
    task = %{flo: 2500 + florand, algo: state.algo, restime_limit: 10000} #restime_limitはCluster利用コスト最適化における応答時間の閾値
    #IO.inspect(self(), label: "task request from Device") 標準出力
    GenServer.call(state.relaypid, {:assign_request, self(), task})

    state = Map.update!(state, :randomseed, fn _ -> timerrand + florand end)

    #create task ↑
    if state.taskflag do
      GenServer.cast(self(), :create_task)
    else
      GenServer.cast(state.relaypid, {:device_finish_creating_task, self()})
      #IO.inspect "finish creating tasks in device"
    end
    {:noreply, state}
  end

  #Client API
  def start_link(deviceinfo \\ %{taskflag: false, relaypid: 0, randomseed: 0, algo: "taskque"}) do
    {:ok, mypid} = GenServer.start_link(__MODULE__, deviceinfo)
    {:ok, mypid}
  end
end
