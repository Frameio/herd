# Herd

Herd is a pure elixir client for a clustered system like memcached, redis or etcd.  It can launch
(supervised) connection pools for each node, pool a service discovery mechanism to keep the cluster
in sync, and route to individual nodes using a configurable mechanism.

The library is designed to be as pluggable as possible, so it's built around a few generator macros
that will define all the components you'll need to create a clustered connection.

## Installation

The package can be installed by adding `herd` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:herd, "~> 0.1.0"}
  ]
end
```

## Configuration

A herd consists of three modules, a Cluster, a Pool, and a Supervisor.  The cluster manages an
ets table of all the current nodes to balance across, the pool supervises connection pools to each node, and a Supervisor supervises the cluster and the pool.  They can be created more or less like so:

```elixir
defmodule Herd.MockCluster do
  use Herd.Cluster, otp_app: :herd, herd: :test
end

defmodule Herd.MockPool do
  use Herd.Pool, otp_app: :herd, herd: :test
end

defmodule Herd.MockSupervisor do
  use Herd.Supervisor, otp_app: :herd, herd: :test
end
```

Then they are configured like: 

```elixir
config :herd, :test, # for the :test herd name under the :herd app
  discovery: Herd.MockDiscovery,
  cluster: Herd.MockCluster,
  pool: Herd.MockPool,
  router: Herd.Router.HashRing

config :herd, Herd.MockPool,
  worker_module: Herd.MockWorker # configure the poolboy worker
```

You would then need to add `Herd.MockSupervisor` to your application's supervision tree.

If you want to bring your own router you can implement the `Herd.Router` behaviour,
and if you want to implement a service discovery mechanism, simply implement the `Herd.Discovery`
behaviour.  The library comes built with a hash ring based router and a config based discovery
mechanism
