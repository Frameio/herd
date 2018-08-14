defmodule Flock.Cluster do
  @moduledoc """
  Macro for generating a cluster manager.  It will create, populate and refresh
  a `Flock.Balancer` in an ets table by polling the configured `Flock.Discovery` implementation.
  
  Usage:

  ```
  defmodule MyFlockCluster do
    use Flock.Cluster, otp_app: :myapp, flock: :myflock
  end
  ```
  """
  require Logger

  defmacro __using__(opts) do
    app   = Keyword.get(opts, :otp_app)
    flock = Keyword.get(opts, :flock)
    health_check = Keyword.get(opts, :health_check, 60_000)
    table_name = :"#{app}_servers"
    quote do
      use GenServer
      import Flock.Cluster
      require Logger

      @otp unquote(app)
      @flock unquote(flock)
      @default_delay unquote(health_check)
      @table_name unquote(table_name)
      @discovery Application.get_env(@otp, @flock)[:discovery]
      @pool Application.get_env(@otp, @flock)[:pool]
      @router Application.get_env(@otp, @flock)[:router]
      @health_check unquote(health_check)

      def start_link(options) do
        GenServer.start_link(__MODULE__, options, name: __MODULE__)
      end

      def init(_) do
        servers = @discovery.nodes()
        Logger.info("starting cluster with servers: #{inspect(servers)}")

        ring = @router.new() |> @router.add_nodes(servers)

        table = :ets.new(@table_name, [:set, :protected, :named_table, read_concurrency: true])
        :ets.insert(table, {:lb, ring})
        @pool.initialize(servers)
        schedule_healthcheck()

        {:ok, table}
      end

      def servers(), do: servers(@table_name, @router)

      def get_node(key), do: get_node(@table_name, @router, key)

      def get_nodes(keys), do: get_nodes(@table_name, @router, keys)

      def handle_info(:health_check, table) do
        schedule_healthcheck()
        health_check(table, @router, @pool, @discovery)
      end

      defp get_router(), do: get_router(@table_name)

      defp schedule_healthcheck() do
        Process.send_after(self(), :health_check, @health_check)
      end
    end
  end

  def get_node(table, router, key) do
    with {:ok, lb} <- get_router(table), do: router.get_node(lb, key)
  end

  def get_nodes(table, router, keys) do
    with {:ok, lb} <- get_router(table), do: router.get_nodes(lb, keys)
  end

  def health_check(table, router, pool, discovery) do
    servers = discovery.nodes() |> MapSet.new()
    {:ok, lb} = get_router(table)
    current = router.nodes(lb) |> MapSet.new()

    added   = MapSet.difference(servers, current) |> MapSet.to_list()
    removed = MapSet.difference(current, servers) |> MapSet.to_list()

    handle_diff(added, removed, lb, router, pool, table)
  end

  def get_router(table) do
    case :ets.lookup(table, :lb) do
      [{:lb, ring}] -> {:ok, ring}
      _ -> {:error, :not_found}
    end
  end

  def servers(table, router) do
    case get_router(table) do
      {:ok, lb} -> router.nodes(lb)
      _ -> []
    end
  end

  defp handle_diff([], [], _, _, _, table), do: {:noreply, table}
  defp handle_diff(add, remove, lb, router, pool,  table) do
    Logger.info "Added #{inspect(add)} servers to cluster"
    Logger.info "Removed #{inspect(remove)} servers from cluster"

    lb = router.add_nodes(lb, add) |> router.remove_nodes(remove)

    :ets.insert(table, {:lb, lb})
    pool.handle_diff(add, remove)
    {:noreply, table}
  end
end