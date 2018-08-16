defmodule Herd.Pool do
  @moduledoc """
  Builds a connection pool manager for a given herd.  The manager has a number of overrideable
  functions, including:

  * spec_for_node/1 - infers a child spec for a given node in the cluster
  * nodename/1 - generates an atom for a given node
  * poolname/1 - generates a {:via, Registry, {MyRegistry, name}} tuple for a given node
  * worker_config/1 - generates the worker config only for a given node. Note that pool config
      is inferred from `Application.get_env(app, __MODULE__)` by default which might be sufficient
      for configuring poolboy.

  Use with:

  ```
  defmodule MyHerdPool do
    use Herd.Pool, otp_app: :myapp, herd: :myherd
  end
  ```
  """
  defmacro __using__(opts) do
    app = Keyword.get(opts, :otp_app)
    quote do
      use DynamicSupervisor
      import Herd.Pool

      alias Memcachir.Util

      @otp unquote(app)
      @default_pool_config [
        strategy: :lifo,
        size: 10,
        max_overflow: 10
      ]
      @registry Module.concat(__MODULE__, Registry)

      def start_link(options) do
        DynamicSupervisor.start_link(__MODULE__, options, name: __MODULE__)
      end

      def init(_options) do
        DynamicSupervisor.init(strategy: :one_for_one)
      end

      def spec_for_node(node) do
        pool = pool_conf()
               |> Keyword.put(:name, poolname(node))
               |> pool_config()

        name = nodename(node)
        %{id: name, start: {:poolboy, :start_link, [pool, worker_config(node)]}}
      end

      def poolname(node), do: {:via, Registry, {@registry, nodename(node)}}

      def nodename({host, port}), do: :"#{host}_#{port}"

      def worker_config(node), do: nodename(node)

      def pool_config(config), do: config

      def start_node({host, port} = node) do
        spec = spec_for_node(node)
        DynamicSupervisor.start_child(__MODULE__, spec)
      end

      def terminate_node(node), do: terminate_node(__MODULE__, @registry, nodename(node))

      def initialize(servers), do: handle_diff(servers, [])

      def handle_diff(adds, removes), do: handle_diff(__MODULE__, adds, removes)

      defp config(), do: Application.get_env(@otp, __MODULE__, [])

      defp pool_conf(), do: @default_pool_config |> Keyword.merge(config())

      defoverridable [spec_for_node: 1, nodename: 1, poolname: 1, worker_config: 1, pool_config: 1]
    end
  end

  def terminate_node(pool, registry, node) do
    registry
    |> Registry.lookup(node)
    |> case do
      [{pid, _}] -> DynamicSupervisor.terminate_child(pool, pid)
      _ -> :ok
    end
  end

  def handle_diff(pool, adds, removes) do
    for add <- adds, do: pool.start_node(add)
    for remove <- removes, do: pool.terminate_node(remove)
  end
end