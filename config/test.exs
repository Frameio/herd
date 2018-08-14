use Mix.Config

config :flock, :test,
  discovery: Flock.MockDiscovery,
  cluster: Flock.MockCluster,
  pool: Flock.MockPool,
  router: Flock.Router.HashRing

config :flock, Flock.MockPool,
  worker_module: Flock.MockWorker