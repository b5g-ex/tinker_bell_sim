defmodule GRServer do
  use GenServer

  #GenServer API
  def init(relayinfo) do
    {:ok, relayinfo}
  end

  def handle_call({:append_engineinfo, pid, engineinfo}, _from, state) do
    now_enginemap = state.enginemap
    new_enginemap = Map.put_new(now_enginemap, pid, engineinfo)
    state = Map.update!(state, :enginemap, fn now_enginemap -> new_enginemap end)
    {:reply, state, state}
  end

  def handle_call({:append_deviceinfo, pid, deviceinfo}, _from, state) do
    now_devicemap = state.devicemap
    new_devicemap = Map.put_new(now_devicemap, pid, deviceinfo)
    state = Map.update!(state, :devicemap, fn now_devicemap -> new_devicemap end)
    {:reply, state, state}
  end

  def handle_call(:get_relayinfo, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:start_assigning, _from, state) do
    state.devicemap
    |> Map.keys()
    |> Enum.map(fn pid -> GenServer.cast(pid, :taskflag_true)
                          GenServer.cast(pid, :create_task) end)
    {:reply, state, state}
  end

  def handle_call(:stop_assigning, _from, state) do
    state.devicemap
    |> Map.keys()
    |> Enum.map(fn pid -> GenServer.cast(pid, :taskflag_false) end)
    {:reply, state, state}
  end

  def handle_call({:assign_request, devicepid, task}, _from, state) do
    waiting_tasks = state.waiting_tasks
    waiting_tasks = Map.put_new(waiting_tasks, devicepid, task)
    state = Map.update!(state, :waiting_tasks, fn now -> waiting_tasks end)
    GenServer.call(AlgoServer, {:assign_algorithm, task})
    {:reply, state, state}
  end

  #client API
  def start_link(relayinfo \\ %{enginemap: %{}, devicemap: %{}, waiting_tasks: %{}}) do
    {:ok, mypid} = GenServer.start_link(__MODULE__, relayinfo)
    for times <- 0..2 do
      {:ok, pid} = GEServer.start_link()
      engineinfo = GenServer.call(pid, :get_engineinfo)
      GenServer.call(mypid, {:append_engineinfo, pid, engineinfo})
    end
    for times <- 0..2 do
      {:ok, pid} = EndDevice.start_link(%{taskflag: false, relaypid: mypid})
      GenServer.call(mypid, {:append_deviceinfo, pid, %{}})
    end
    {:ok, mypid}
  end
end
