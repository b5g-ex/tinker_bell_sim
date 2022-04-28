defmodule TinkerBellSimServer do
  use GenServer

  #GenServer API
  def init(state) do
    {:ok, state}
  end

  def handle_cast({:randommessage, value}, state) do

  end

  #Client API
  def start_link(state \\ []) do
    GenServer.start_link(__MODULE__, state, name: Server)
  end

  def startworkterm(workername) do
    workername.getworkerstate(workername,Server)
    receive do
      {sender,calcpower} ->
        IO.puts calcpower
    end
  end
end
