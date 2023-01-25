defmodule Protohackers.Application do
  @moduledoc false

  use Application

  alias Protohackers.EchoServer

  @impl true
  def start(_type, _args) do
    children = [
      {EchoServer, [port: 5000]}
    ]

    opts = [strategy: :one_for_one, name: Protohackers.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
