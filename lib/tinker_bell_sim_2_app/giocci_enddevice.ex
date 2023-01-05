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

  def handle_cast(:set_randomseed, state) do
    _ = :rand.seed(:exsss, state.randomseed)
    {:noreply, state}
  end

  def handle_cast(:create_task, state) do
    _ = :rand.seed(:exsss, state.randomseed)
    timerrand = :rand.uniform 2000
    #File.write("outputtimer2.txt",Integer.to_string(timerrand) <> "\n",[:append])
    :timer.sleep(2000 + timerrand)
    #create task ↓
    florand = :rand.uniform 2000
    #File.write("outputflo2.txt",Integer.to_string(florand) <> "\n",[:append])
    task = %{flo: 1000 + florand, algo: "bandwidth", restime_limit: 1000}
    #IO.inspect(self(), label: "task request from Device") 標準出力
    GenServer.call(state.relaypid, {:assign_request, self(), task})

    state = Map.update!(state, :randomseed, fn _ -> timerrand + florand end)

    #create task ↑
    if state.taskflag do
      GenServer.cast(self(), :create_task)
    end
    {:noreply, state}
  end

  #Client API
  def start_link(deviceinfo \\ %{taskflag: false, relaypid: 0, randomseed: 0}) do
    {:ok, mypid} = GenServer.start_link(__MODULE__, deviceinfo)
    GenServer.cast(self(), :set_randomseed)
    {:ok, mypid}
  end
end
