defmodule Protohackers.EchoServer do
  use GenServer
  require Logger

  defstruct [:port, :listen_socket, :supervisor]

  @timeout :timer.seconds(1)
  @max_bytes 100 * 1024

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl GenServer
  def init(opts) do
    port = Keyword.fetch!(opts, :port)
    {:ok, supervisor} = Task.Supervisor.start_link(max_children: 100)

    listen_options = [
      mode: :binary,
      active: false,
      reuseaddr: true,
      exit_on_close: false
    ]

    case :gen_tcp.listen(port, listen_options) do
      {:ok, listen_socket} ->
        Logger.info("Starting echo server on port #{port}")
        init_state = %__MODULE__{port: port, listen_socket: listen_socket, supervisor: supervisor}
        {:ok, init_state, {:continue, :accept}}

      {:error, error} ->
        {:stop, error}
    end
  end

  @impl GenServer
  def handle_continue(:accept, state) do
    case :gen_tcp.accept(state.listen_socket) do
      {:ok, socket} ->
        Task.Supervisor.start_child(state.supervisor, fn -> handle_connection(socket) end)
        {:noreply, state, {:continue, :accept}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  defp handle_connection(socket) do
    case recv_until_closed(socket) do
      {:ok, data} -> :gen_tcp.send(socket, data)
      {:error, error} -> Logger.error("EchoServer failed to receive data - #{inspect(error)}")
    end

    :gen_tcp.close(socket)
  end

  defp recv_until_closed(socket, buffer \\ [], buffer_size \\ 0) do
    case :gen_tcp.recv(socket, 0, @timeout) do
      {:ok, data} when buffer_size + byte_size(data) > @max_bytes -> {:error, :buffer_overflow}
      {:ok, data} -> recv_until_closed(socket, [buffer, data], buffer_size + byte_size(data))
      {:error, :closed} -> {:ok, buffer}
      {:error, reason} -> {:error, reason}
    end
  end
end
