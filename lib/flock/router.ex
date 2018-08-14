defmodule Flock.Router do
  @moduledoc """
  Manages load balancing between nodes in the cluster, for example
  through a hash ring
  """

  @type router :: term
  @type flock_node :: term

  @doc """
  Initialize a new load router
  """
  @callback new() :: router

  @doc """
  Return all nodes in the router
  """
  @callback nodes(lb :: router) :: [flock_node]

  @doc """
  Add nodes to the router
  """
  @callback add_nodes(lb :: router, nodes :: [flock_node]) :: router

  @doc """
  Remove nodes from the router
  """
  @callback remove_nodes(lb :: router, nodes :: [flock_node]) :: router

  @doc """
  Gets a node from the router using the given key
  """
  @callback get_node(lb :: router, key :: term) :: {:ok, flock_node} | {:error, any}

  @doc """
  Gets nodes mapped by the given keys
  """
  @callback get_nodes(lb :: router, keys :: [term]) :: {:ok, %{term => flock_node}} | {:error, any}
end