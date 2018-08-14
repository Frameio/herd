defmodule Flock.Discovery do
  @moduledoc """
  Behaviour for implementing service discovery on a given cluster.  This
  will be polled regularly to keep the cluster's state in sync
  """

  @doc """
  Return the node list
  """
  @callback nodes() :: [Flock.Router.flock_node]
end