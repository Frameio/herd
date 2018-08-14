defmodule Flock.Discovery.Config do
  @moduledoc """
  Creates config based service discovery with
  ```
  use Flock.Discovery.Config, path: {:app, :key}
  ```
  """

  defmacro __using__(path: {app, key}) do
    quote do
      def nodes(), do: Application.get_env(unquote(app), unquote(key))
    end
  end
end