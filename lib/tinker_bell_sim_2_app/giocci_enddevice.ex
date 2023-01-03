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

  def handle_cast(:create_task, state) do
    :timer.sleep(2000 + :rand.uniform 2000)
    #create task ↓
    task = %{flo: 1000 + :rand.uniform(2000), algo: "responsetime", restime_limit: 1000}
    #IO.inspect(self(), label: "task request from Device") 標準出力
    GenServer.call(state.relaypid, {:assign_request, self(), task})
    #create task ↑
    if state.taskflag do
      GenServer.cast(self(), :create_task)
    end
    {:noreply, state}
  end

  #Client API
  def start_link(deviceinfo \\ %{taskflag: false, relaypid: 0, randomseed: 0}) do
    {:ok, mypid} = GenServer.start_link(__MODULE__, deviceinfo)
    _ = :rand.seed(:exsss, deviceinfo.randomseed)
    {:ok, mypid}
  end
end
