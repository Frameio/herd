defmodule Herd.Cluster do
  @moduledoc """
  Macro for generating a cluster manager.  It will create, populate and refresh
  a `Herd.Balancer` in an ets table by polling the configured `Herd.Discovery` implementation.

  Usage:

  ```
  defmodule MyHerdCluster do
    use Herd.Cluster, otp_app: :myapp,
                      router: MyRouter,
                      discovery: MyDiscovery,
                      pool: MyPool
  end
  ```
  """
  require Logger

  defmodule State do
    defstruct table: nil, marked_nodes: MapSet.new(), restored_nodes: []
  end

  defmacro __using__(opts) do
    app          = Keyword.get(opts, :otp_app)
    health_check = Keyword.get(opts, :health_check, 60_000)
    router       = Keyword.get(opts, :router, Herd.Router.HashRing)
    discovery    = Keyword.get(opts, :discovery)
    pool         = Keyword.get(opts, :pool)
    table_name = :"#{app}_servers"
    mark_duration = Keyword.get(opts, :mark_duration, 30_000)
    mark_lookback = Keyword.get(opts, :mark_lookback, 300_000)
    max_backoff = Keyword.get(opts, :max_backoff, 300_000)

    quote do
      use GenServer
      import Herd.Cluster
      require Logger

      @otp unquote(app)
      @table_name unquote(table_name)
      @health_check unquote(health_check)
      @mark_duration unquote(mark_duration)
      @mark_lookback unquote(mark_lookback)
      @max_backoff unquote(max_backoff)
      @router unquote(router)
      @discovery unquote(discovery)
      @pool unquote(pool)

      def start_link(options) do
        GenServer.start_link(__MODULE__, options, name: __MODULE__)
      end

      def init(_) do
        servers = @discovery.nodes()
        Logger.info("starting cluster with servers: #{inspect(servers)}")

        ring =
          @router.new()
          |> @router.add_nodes(servers)

        table = :ets.new(@table_name, [:set, :protected, :named_table, read_concurrency: true])
        :ets.insert(table, {:lb, ring})
        @pool.initialize(servers)
        schedule_healthcheck()

        {:ok, %State{table: table}}
      end

      def servers(), do: servers(@table_name, @router)

      def get_node(key), do: get_node(@table_name, @router, key)

      def get_nodes(keys), do: get_nodes(@table_name, @router, keys)

      def mark_node(node), do: GenServer.call(__MODULE__, {:mark_node, node})

      def handle_call({:mark_node, node}, _from, state) do
        marked_nodes = MapSet.put(state.marked_nodes, node)
        remove_node(state.table, node)

        restored_nodes = discard_expired(state.restored_nodes)
        count = restored_nodes |> Enum.filter(fn {n, _} -> n == node end) |> length()
        delay = min(round(@mark_duration * :math.pow(2, count)), @max_backoff)
        schedule_restore_node(node, delay)

        Logger.info "Marked #{inspect(node)} as unavailable for #{delay}ms"
        {:reply, :ok, %State{state | marked_nodes: marked_nodes, restored_nodes: restored_nodes}}
      end

      def handle_info(:health_check, state) do
        schedule_healthcheck()
        health_check(state.table, @router, @pool, @discovery, state.marked_nodes)
        {:noreply, state}
      end

      def handle_info({:restore_node, node}, state) do
        marked_nodes = MapSet.delete(state.marked_nodes, node)
        restored_nodes = [{node, DateTime.utc_now()} | discard_expired(state.restored_nodes)]
        {:noreply, %State{state | marked_nodes: marked_nodes, restored_nodes: restored_nodes}}
      end

      defp get_router(), do: get_router(@table_name)

      defp schedule_healthcheck() do
        Process.send_after(self(), :health_check, @health_check)
      end

      defp schedule_restore_node(node, delay) do
        Process.send_after(self(), {:restore_node, node}, delay)
      end

      defp discard_expired(restored_nodes) do
        now = DateTime.utc_now()
        Enum.filter(restored_nodes, fn {_, t} -> DateTime.diff(now, t, :millisecond) > @mark_lookback end)
      end

      defp remove_node(table, node) do
        {:ok, lb} = get_router(table)
        lb = @router.remove_nodes(lb, [node])
        nodes = @router.nodes(lb) |> MapSet.new() |> MapSet.delete(node)

        # don't completely drain the cluster
        if MapSet.size(nodes) > 0 do
          :ets.insert(table, {:lb, lb})
          @pool.handle_diff([], [node])
        end
      end
    end
  end

  def get_node(table, router, key) do
    with {:ok, lb} <- get_router(table), do: router.get_node(lb, key)
  end

  def get_nodes(table, router, keys) do
    with {:ok, lb} <- get_router(table), do: router.get_nodes(lb, keys)
  end

  def health_check(table, router, pool, discovery, marked_nodes) do
    servers = discovery.nodes() |> MapSet.new() |> MapSet.difference(marked_nodes) |> MapSet.to_list()
    do_health_check(table, router, pool, servers)
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

  # never drain the cluster to guard against bad service disco methods
  defp do_health_check(table, _router, _pool, []), do: {:noreply, table}
  defp do_health_check(table, router, pool, nodes) do
    servers   = MapSet.new(nodes)
    {:ok, lb} = get_router(table)
    current   = router.nodes(lb) |> MapSet.new()

    added   = MapSet.difference(servers, current) |> MapSet.to_list()
    removed = MapSet.difference(current, servers) |> MapSet.to_list()

    handle_diff(added, removed, lb, router, pool, table)
  end

  defp handle_diff([], [], _, _, _, table), do: {:noreply, table}
  defp handle_diff(add, remove, lb, router, pool,  table) do
    Logger.info "Added #{inspect(add)} servers to cluster"
    Logger.info "Removed #{inspect(remove)} servers from cluster"

    lb = router.add_nodes(lb, add) |> router.remove_nodes(remove)

    :ets.insert(table, {:lb, lb})
    pool.handle_diff(add, remove)
  end
end
