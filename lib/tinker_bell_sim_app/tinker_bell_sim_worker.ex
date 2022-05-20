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

  def handle_call({:set_randomseed, seed}, _from, workerstate) do
    _ = :rand.seed(:exsss, 200 * seed + seed)
    {:reply, workerstate, workerstate}
  end

  def handle_call(:newtask, _from, workerstate) do
    newtask = {(:rand.uniform 1000), self()}
    workerstate = Map.update(workerstate, :tasks, [], fn nowtasks ->
       nowtasks ++ [newtask]
    end)
    #IO.inspect workerstate
    {:reply, newtask, workerstate}
  end

  def handle_cast({:do_tasks,assignmap}, workerstate) do

    t1 = :erlang.monotonic_time()

    tasks = Map.get(assignmap,self())
    Enum.each(tasks, fn x -> :timer.sleep(elem(x,0)) end)

    t2 = :erlang.monotonic_time()

    time = :erlang.convert_time_unit(t2 - t1, :native, :microsecond)
    IO.inspect [self(),time]

    workerstate = Map.update(workerstate, :tasks, [], fn nowtasks -> [] end)

    {:noreply, workerstate}
  end

  #Client API
  def start_link(workerstate \\ %{}) do
    GenServer.start_link(__MODULE__, workerstate)
  end

end
