defmodule TinkerBellSimServer do
  use GenServer

  #GenServer API
  def init(state) do
    {:ok, state}
  end

  def handle_cast({:startworkterm, value}, state) do
    GenServer.cast(Enum.at(state,1),{:sendstate, 0})
  end

  def handle_call({:append_pid, pid}, _from, state) do
    {:reply, pid, [state | pid]}
  end

  #Client API
  def start_link(state \\ []) do
    GenServer.start_link(__MODULE__, state, name: Server)
    for times <- 1..5 do
      {:ok, pid} = TinkerBellSimWorker.start_link(times * 100)
      GenServer.call(Server, {:append_pid, pid})
    end
  end

  def startworkterm do
    GenServer.cast(Server,{:startworkterm, 0})
  end
end
