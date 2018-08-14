defmodule Flock.Supervisor do
  @moduledoc """
  Creates a Supervisor for the flock's internal registry, it's pool of pools,
  and the cluster.  Use with:

  ```
  defmodule MyFlockSupervisor do
    use Flock.Supervisor, otp_app: :my_app, flock: :my_flock
  end
  """
  defmacro __using__(opts) do
    app   = Keyword.get(opts, :otp_app)
    flock = Keyword.get(opts, :flock)
    quote do
      use Supervisor
      @otp unquote(app)
      @flock unquote(flock)
      @flock Application.get_env(@otp, @flock)
      @pool @flock[:pool]
      @cluster @flock[:cluster]

      @supervisor_config Application.get_env(@otp, __MODULE__, [])

      def start_link(options) do
        Supervisor.start_link(__MODULE__, options, name: __MODULE__)
      end

      def init(options) do
        opts = Keyword.put(@supervisor_config, :strategy, :one_for_one)

        children = [
          # needs to be started FIRST
          worker(Registry, [[name: Module.concat(@pool, Registry), keys: :unique]]),
          supervisor(@pool, [options]),
          worker(@cluster, [options]),
        ]

        supervise(children, opts)
      end
    end
  end
end