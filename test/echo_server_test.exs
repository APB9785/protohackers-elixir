defmodule Protohackers.EchoServerTest do
  use ExUnit.Case, async: true

  @port 5000
  @timeout 5000

  test "echoes anything back" do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", @port, mode: :binary, active: false)
    assert :gen_tcp.send(socket, "foo") == :ok
    assert :gen_tcp.send(socket, "bar") == :ok
    :gen_tcp.shutdown(socket, :write)
    assert :gen_tcp.recv(socket, 0, @timeout) == {:ok, "foobar"}
  end

  @tag :capture_log
  test "echo server has a max buffer size" do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", 5000, mode: :binary, active: false)
    assert :gen_tcp.send(socket, :binary.copy("a", 1024 * 100 + 1)) == :ok
    assert :gen_tcp.recv(socket, 0) == {:error, :closed}
  end

  test "handles multiple concurrent connections" do
    tasks =
      for _ <- 1..4 do
        Task.async(fn ->
          {:ok, socket} = :gen_tcp.connect(~c"localhost", @port, mode: :binary, active: false)
          assert :gen_tcp.send(socket, "foo") == :ok
          assert :gen_tcp.send(socket, "bar") == :ok
          :gen_tcp.shutdown(socket, :write)
          assert :gen_tcp.recv(socket, 0, @timeout) == {:ok, "foobar"}
        end)
      end

    Enum.each(tasks, &Task.await/1)
  end
end
