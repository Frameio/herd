use Mix.Config

config :herd, :test,
  discovery: Herd.MockDiscovery,
  cluster: Herd.MockCluster,
  pool: Herd.MockPool,
  router: Herd.Router.HashRing

config :herd, Herd.MockPool,
  worker_module: Herd.MockWorker