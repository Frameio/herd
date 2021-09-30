defmodule Herd.MockCluster do
  use Herd.Cluster, otp_app: :herd,
                    pool: Herd.MockPool,
                    discovery: Herd.MockDiscovery,
                    router: Herd.Router.HashRing # defaults to Herd.Router.HashRing

  def clear_marked do
    GenServer.call(__MODULE__, :clear_marked)
  end

  def handle_call(:clear_marked, _from, state) do
    {:reply, :ok, %Herd.Cluster.State{state | marked_nodes: MapSet.new(), restored_nodes: []}}
  end
end

defmodule Herd.MockPool do
  use Herd.Pool, otp_app: :herd
end

defmodule Herd.MockSupervisor do
  use Herd.Supervisor, otp_app: :herd,
                       pool: Herd.MockPool,
                       cluster: Herd.MockCluster
end

defmodule Herd.MockWorker do
  use GenServer
  def start_link(name), do: GenServer.start_link(__MODULE__, name)

  def init(name), do: {:ok, name}

  def handle_call(:name, _, name), do: {:reply, name, name}
end
