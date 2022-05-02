defmodule TinkerBellSimWorker do
  use GenServer

  #GenServer API
  def init(calcpower) do
    {:ok, calcpower}
  end

  def handle_cast({:sendstate, 0}, calcpower) do
    IO.puts "cast to worker ok"
  end

  #Client API
  def start_link(calcpower \\ []) do
    GenServer.start_link(__MODULE__, calcpower)
  end

end
