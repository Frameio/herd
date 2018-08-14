defmodule Flock do
  @moduledoc """
  A flock consists of three modules, a Cluster, a Pool, and a Supervisor.  The cluster manages an
  ets table of all the current nodes to balance across, the pool supervises connection pools to each node, and a Supervisor supervises the cluster and the pool.  They can be created more or less like so:

  ```elixir
  defmodule Flock.MockCluster do
    use Flock.Cluster, otp_app: :flock, flock: :test
  end

  defmodule Flock.MockPool do
    use Flock.Pool, otp_app: :flock, flock: :test
  end

  defmodule Flock.MockSupervisor do
    use Flock.Supervisor, otp_app: :flock, flock: :test
  end
  ```

  Then they are configured like: 

  ```elixir
  config :flock, :test, # for the :test flock name under the :flock app
    discovery: Flock.MockDiscovery,
    cluster: Flock.MockCluster,
    pool: Flock.MockPool,
    router: Flock.Router.HashRing

  config :flock, Flock.MockPool,
    worker_module: Flock.MockWorker # configure the poolboy worker
  ```

  You would then need to add Flock.MockSupervisor to your application's supervision tree.

  If you want to bring your own router you can implement the `Flock.Router` behaviour,
  and if you want to implement a service discovery mechanism, simply implement the `Flock.Discovery`
  behaviour.  The library comes built with a hash ring based router and a config based discovery
  mechanism
  """
end
