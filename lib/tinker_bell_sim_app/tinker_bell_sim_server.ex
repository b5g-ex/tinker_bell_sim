defmodule TinkerBellSimServer do
  use GenServer

  #GenServer API
  def init(state) do
    {:ok, state}
  end

  def handle_call({:update_worker_state, id}, _from, state) do
    pid = Enum.at(Map.keys(state), id)
    workerstate = GenServer.call(pid, :get_workerstate)
    IO.inspect workerstate
    state = Map.update(state, pid, 0, fn _ -> Map.get(workerstate,:calcpower) end)
    state = Map.update(state, :tasks, 0, fn nowtasks -> nowtasks ++ Map.get(workerstate,:tasks) end)
    {:reply, state, state}
  end

  def handle_call({:append_workerinfo, pid, calcpower}, _from, state) do
    state = Map.put_new(state, pid, calcpower)
    {:reply, state, state}
  end

  def handle_call(:create_assignmap_and_tasks, _from, state) do
    state = Map.put_new(state, :assignmap, %{})
    state = Map.put_new(state, :tasks, [])
    {:reply, state, state}
  end

  def handle_call(:getstate, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:let_workers_create_newtask, _from, state) do
    for times <- 2..6 do
      for tasknum <- 0..:rand.uniform 3 do
        GenServer.call(Enum.at(Map.keys(state),times),:newtask)
      end
      GenServer.call(Enum.at(Map.keys(state),times),:get_workerstate)
    end
    {:reply, state, state}
  end

  def handle_call(:get_tasklist_length, _from, state) do
    tasklist_length = state
      |> Map.fetch(:tasks)
      |> elem(1)
      |> length()
    {:reply, tasklist_length, state}
  end

  def handle_call(:assign_tasks_greedy, _from, state) do
    tasklist = state
      |> Map.fetch(:tasks)
      |> elem(1)
    assignmap = state
      |> Map.fetch(:assignmap)
      |> elem(1)
    max_calcpower = state
      |> Map.values()
      |> tl()
      |> tl()
      |> Enum.max()
    #IO.inspect max_calcpower
    pid = state
      |>Enum.find(fn {key, val} -> val == max_calcpower end)
      |>elem(0)
    #IO.inspect pid

    {assignedtask,tasklist} = List.pop_at(tasklist,0)
    #IO.inspect {assignedtask,tasklist}

    assignmap = Map.update(assignmap, pid, [], fn nowtasks -> nowtasks ++ [assignedtask] end)
    state = %{state | tasks: tasklist}
    state = %{state | assignmap: assignmap}
    state = Map.update(state, pid, [], fn x -> x - elem(assignedtask,0) end)

    {:reply, state, state}
  end

  def handle_call({:initialize_assignmap,id}, _from, state) do
    assignmap = Map.get(state,:assignmap)
    assignmap = Map.update(assignmap, Enum.at(Map.keys(state),id), [], fn nowtasks -> nowtasks end)
    state = %{state | assignmap: assignmap}
    {:reply, state, state}
  end

  def handle_call(:let_workers_do_tasks, _from, state) do
    for times <- 2..6 do
      GenServer.call(Enum.at(Map.keys(state),times),{:do_tasks, Map.get(state,:assignmap)})
    end
    {:reply, state, state}
  end

  #Client API
  def start_link(state \\ %{}) do
    GenServer.start_link(__MODULE__, state, name: Server)
    for times <- 0..4 do
      {:ok, pid} = TinkerBellSimWorker.start_link(%{calcpower: 100 * (times+1)})
      GenServer.call(pid, :create_tasklist)
      GenServer.call(Server, {:append_workerinfo, pid, 200 * (times+1)})
    end

    GenServer.call(Server,:create_assignmap_and_tasks)
    GenServer.call(Server,:getstate)

    TinkerBellSimServer.startworkterm
    TinkerBellSimServer.create_tasks

  end

  def startworkterm do
    for times <- 2..6 do
      GenServer.call(Server,{:update_worker_state, times})
    end
    GenServer.call(Server,:getstate)
  end

  def create_tasks do
    GenServer.call(Server,:let_workers_create_newtask)
    for times <- 2..6 do
      GenServer.call(Server,{:update_worker_state, times})
    end
    GenServer.call(Server,:getstate)
  end

"""
  def get_tasks_from_workers do
    for times <- 2..6 do
      GenServer.call(Server,{:get_tasks_from_workers, times})
    end
  end
"""

  def assign_tasks_greedy do

    for times <- 2..6 do
      GenServer.call(Server, {:initialize_assignmap, times})
    end

    assign_iteration = GenServer.call(Server,:get_tasklist_length)

    for times <- 1..assign_iteration do
      GenServer.call(Server,:assign_tasks_greedy)
    end

    GenServer.call(Server,:getstate)

  end

  def do_tasks do
    GenServer.call(Server,:let_workers_do_tasks)
  end

end
