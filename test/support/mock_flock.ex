defmodule Flock.MockCluster do
  use Flock.Cluster, otp_app: :flock, flock: :test
end

defmodule Flock.MockPool do
  use Flock.Pool, otp_app: :flock, flock: :test
end

defmodule Flock.MockSupervisor do
  use Flock.Supervisor, otp_app: :flock, flock: :test
end

defmodule Flock.MockWorker do
  use GenServer
  def start_link(name), do: GenServer.start_link(__MODULE__, name)

  def init(name), do: {:ok, name}

  def handle_call(:name, _, name), do: {:reply, name, name}
end