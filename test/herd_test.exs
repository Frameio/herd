defmodule HerdTest do
  use ExUnit.Case, async: false

  alias Herd.{
    MockDiscovery,
    MockCluster,
    MockPool
  }

  setup do
    node = {"localhost", 123}
    :ok = MockDiscovery.update([node])
    clear_marked()
    send_health_check()
    :ok
  end

  test "It will populate the cluster on supervisor boot" do
    node = {"localhost", 123}
    verify_nodes_equal([node])

    assert MockCluster.get_node(:dummy) == {:ok, node}

    poolname = MockPool.poolname(node)

    :poolboy.transaction(poolname, fn worker ->
      assert GenServer.call(worker, :name) == :localhost_123
    end)
  end

  test "It will balance across multiple nodes" do
    nodes = [{"localhost", 123}, {"localhost", 234}]
    :ok = MockDiscovery.update(nodes)
    send_health_check()

    verify_nodes_equal(nodes)

    for k <- 1..4 do
      {:ok, node} = MockCluster.get_node(k)

      MockPool.poolname(node)
      |> :poolboy.transaction(fn worker ->
        assert GenServer.call(worker, :name) == MockPool.nodename(node)
      end)
    end
  end

  test "It will survive healthchecks" do
    nodes = [{"localhost", 123}, {"localhost", 234}]
    :ok = MockDiscovery.update(nodes)
    send_health_check()

    verify_nodes_present(nodes)

    nodes = [{"localhost", 123}]

    :ok = MockDiscovery.update(nodes)
    send_health_check()

    assert Registry.lookup(Herd.MockPool.Registry, :localhost_234) == []

    verify_nodes_equal(nodes)
    verify_nodes_present(nodes)

    nodes = [{"localhost", 567}, {"localhost", 234}]
    :ok = MockDiscovery.update(nodes)
    send_health_check()

    verify_nodes_equal(nodes)
    verify_nodes_present(nodes)
  end

  test "It won't drain a cluster" do
    nodes = [{"localhost", 567}, {"localhost", 234}]
    :ok = MockDiscovery.update(nodes)
    send_health_check()

    verify_nodes_equal(nodes)
    verify_nodes_present(nodes)

    :ok = MockDiscovery.update([])
    send_health_check()

    verify_nodes_equal(nodes)
    verify_nodes_present(nodes)
  end

  test "It will exclude marked nodes" do
    nodes = [{"localhost", 567}, {"localhost", 234}]
    :ok = MockDiscovery.update(nodes)
    send_health_check()

    verify_nodes_equal(nodes)
    verify_nodes_present(nodes)

    MockCluster.mark_node({"localhost", 567})
    verify_nodes_equal([{"localhost", 234}])
    verify_nodes_present([{"localhost", 234}])

    send_health_check()
    verify_nodes_equal([{"localhost", 234}])
    verify_nodes_present([{"localhost", 234}])

    MockCluster.mark_node({"localhost", 234})
    verify_nodes_equal([{"localhost", 234}])
    verify_nodes_present([{"localhost", 234}])
  end

  defp verify_nodes_equal(nodes) do
    servers = MockCluster.servers()
    assert MapSet.equal?(MapSet.new(servers), MapSet.new(nodes))
  end

  defp verify_nodes_present(nodes) do
    for node <- nodes do
      MockPool.poolname(node)
      |> :poolboy.transaction(fn worker ->
        assert GenServer.call(worker, :name) == MockPool.nodename(node)
      end)
    end
  end

  defp clear_marked() do
    GenServer.call(MockCluster, :clear_marked)
  end

  defp send_health_check() do
    send(MockCluster, :health_check)
    :timer.sleep(100)
  end
end
