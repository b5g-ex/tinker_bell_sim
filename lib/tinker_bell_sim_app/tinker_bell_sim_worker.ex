defmodule TinkerBellSimWorker do
  use GenServer

  #GenServer API
  def init(calcpower) do
    {:ok, calcpower}
  end

  def handle_cast({:sendstate, value}, calcpower) do
    send Server, {self(), calcpower}
  end

  #Client API
  def start_link(name,calcpower \\ []) do
    GenServer.start_link(__MODULE__, calcpower, name: name)
  end

  def getworkerstate(workername,servername) do
    GenServer.cast(workername,{:randommessage, value // []})
  end
end
