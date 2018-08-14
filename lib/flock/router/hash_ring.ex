defmodule Flock.Router.HashRing do
  @moduledoc """
  Hash Ring implementation of the Flock.Router behavior
  """
  @behaviour Flock.Router

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
      nodes -> {:ok, keys |> Enum.zip(nodes) |> Enum.into(%{})}
    end
  end
end