defmodule Herd.Router.HashRing do
  @moduledoc """
  Hash Ring implementation of the Herd.Router behavior
  """
  @behaviour Herd.Router

  def new(), do: HashRing.new()

  def nodes(ring), do: HashRing.nodes(ring) 

  def add_nodes(ring, nodes), do: Enum.reduce(nodes, ring, &HashRing.add_node(&2, &1))

  def remove_nodes(ring, nodes), do: Enum.reduce(nodes, ring, &HashRing.remove_node(&2, &1))

  def get_node(ring, key) do
    case HashRing.key_to_node(ring, key) do
      {:error, {:invalid_ring, reason}} -> {:error, reason}
      node -> {:ok, node}
    end
  end

  def get_nodes(ring, keys) do
    keys
    |> Enum.map(&get_node(ring, &1))
    |> case do
      [{:error, _} | _] -> {:error, :invalid_ring}
      nodes -> {:ok, keys |> Enum.zip(drop_ok(nodes)) |> Enum.into(%{})}
    end
  end

  defp drop_ok(nodes) when is_list(nodes), do: Enum.map(nodes, &drop_ok/1)
  defp drop_ok({:ok, node}), do: node
  defp drop_ok(node), do: node
end