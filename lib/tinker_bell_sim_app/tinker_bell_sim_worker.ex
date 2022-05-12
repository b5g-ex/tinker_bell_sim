defmodule TinkerBellSimWorker do
  use GenServer

  #GenServer API
  def init(workerstate) do
    {:ok, workerstate}
  end

  def handle_call(:get_workerstate, _from, workerstate) do
    {:reply, workerstate, workerstate}
  end

  def handle_call(:create_tasklist, _from, workerstate) do
    workerstate = Map.put_new(workerstate, :tasks, [])
    {:reply, workerstate, workerstate}
  end

  def handle_call(:newtask, _from, workerstate) do
    newtask = {(:rand.uniform 100), self()}
    workerstate = Map.update(workerstate, :tasks, [], fn nowtasks ->
       nowtasks ++ [newtask]
    end)
    IO.inspect workerstate
    {:reply, newtask, workerstate}
  end

  #Client API
  def start_link(workerstate \\ %{}) do
    GenServer.start_link(__MODULE__, workerstate)
  end

end
