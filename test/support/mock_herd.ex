defmodule Herd.MockCluster do
  use Herd.Cluster, otp_app: :herd, herd: :test
end

defmodule Herd.MockPool do
  use Herd.Pool, otp_app: :herd, herd: :test
end

defmodule Herd.MockSupervisor do
  use Herd.Supervisor, otp_app: :herd, herd: :test
end

defmodule Herd.MockWorker do
  use GenServer
  def start_link(name), do: GenServer.start_link(__MODULE__, name)

  def init(name), do: {:ok, name}

  def handle_call(:name, _, name), do: {:reply, name, name}
end