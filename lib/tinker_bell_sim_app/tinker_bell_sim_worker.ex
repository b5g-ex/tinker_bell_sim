defmodule TinkerBellSimWorker do
  use GenServer

  #GenServer API
  def init(workerstate) do
    {:ok, workerstate}
  end

  def handle_call(:sendstate, _from, workerstate) do
    #workerstate = [workerstate, :rand.uniform 50]
    {:reply, workerstate, workerstate}
  end

  #Client API
  def start_link(workerstate \\ []) do
    GenServer.start_link(__MODULE__, workerstate)
  end

end
