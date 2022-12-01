defmodule GEServer do
  use GenServer

  #GenServer API
  def init(engineinfo) do
    {:ok, engineinfo}
  end

  def handle_call(:initialize_engineinfo, _from, state) do
    taskque_num = :rand.uniform 10
    bandwidth = :rand.uniform 100000
    delay = :rand.uniform 100000
    jitter = :rand.uniform 100000
    packetloss = :rand.uniform 10
    fee = :rand.uniform 10000
    pid = :rand.uniform 1000000
    state = %{taskque: taskque_num, RtE_bandwidth: bandwidth, RtE_delay: delay, RtE_jitter: jitter, RtE_packetloss: packetloss, fee: fee}

    {:reply, state, state}
  end

  def handle_call(:get_engineinfo, _from, state) do
    {:reply, state, state}
  end

  #Client API
  def start_link(engineinfo \\ %{}) do
    {:ok, mypid} = GenServer.start_link(__MODULE__, engineinfo)
    GenServer.call(mypid, :initialize_engineinfo)
    {:ok, mypid}
  end
end
