defmodule Herd.Supervisor do
  @moduledoc """
  Creates a Supervisor for the herd's internal registry, it's pool of pools,
  and the cluster.  Use with:

  ```
  defmodule MyHerdSupervisor do
    use Herd.Supervisor, otp_app: :my_app,
                         cluster: MyCluster,
                         pool: MyPool
  end
  """
  defmacro __using__(opts) do
    app     = Keyword.get(opts, :otp_app)
    pool    = Keyword.get(opts, :pool)
    cluster = Keyword.get(opts, :cluster)
    quote do
      use Supervisor
      @otp unquote(app)
      @pool unquote(pool)
      @cluster unquote(cluster)


      def start_link(options) do
        Supervisor.start_link(__MODULE__, options, name: __MODULE__)
      end

      def init(options) do
        opts = Keyword.put(supervisor_config(), :strategy, :one_for_one)

        children = [
          # needs to be started FIRST
          worker(Registry, [[name: Module.concat(@pool, Registry), keys: :unique]]),
          supervisor(@pool, [options]),
          worker(@cluster, [options]),
        ]

        supervise(children, opts)
      end

      def supervisor_config(), do: Application.get_env(@otp, __MODULE__, [])
    end
  end
end