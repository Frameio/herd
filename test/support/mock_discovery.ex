defmodule Flock.MockDiscovery do
  use GenServer
  @behaviour Flock.Discovery

  def start_link(), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def init([]), do: {:ok, []}

  def update(nodes), do: GenServer.call(__MODULE__, {:nodes, nodes})

  def nodes(), do: GenServer.call(__MODULE__, :nodes)

  def handle_call(:nodes, _, nodes), do: {:reply, nodes, nodes}
  def handle_call({:nodes, nodes}, _, _), do: {:reply, :ok, nodes}
end