defmodule Server do
  @moduledoc """
  Your implementation of a Redis server
  """

  use Application

  def start(_type, _args) do
    Supervisor.start_link([{Task, fn -> Server.listen() end}], strategy: :one_for_one)
  end

  @doc """
  Listen for incoming connections
  """
  def listen() do
    # You can use print statements as follows for debugging, they'll be visible when running tests.
    IO.puts("Logs from your program will appear here!")

    # Uncomment this block to pass the first stage
    #
    # Since the tester restarts your program quite often, setting SO_REUSEADDR
    # ensures that we don't run into 'Address already in use' errors
    {:ok, socket} = :gen_tcp.listen(6379, [:binary, active: false, reuseaddr: true])
    accept_next(socket)
  end

  defp accept_next(listen_socket) do
    {:ok, client} = :gen_tcp.accept(listen_socket)
    Task.start_link(fn -> serve(client) end)

    accept_next(listen_socket)
  end

  defp serve(client) do
    data = client
      |> recieve_data()
      |> decode_data()

    IO.puts(data)
    send_response(data, client)

    serve(client)
  end

  defp decode_data(data) do
    data
    |> String.trim()  # Remove leading/trailing whitespace
    |> String.split("\r\n")  # Split on newline characters
    |> Enum.chunk_every(2)  # Group consecutive elements into pairs
    |> Enum.map(fn [_command, value] -> String.slice(value, 1, byte_size(value) - 1) end)
  end

  defp recieve_data(client) do
    {:ok, data} = :gen_tcp.recv(client, 0);
    data
  end

  defp send_response([head | tail], client) do
    case String.upcase(head) do
      "ECHO" -> :gen_tcp.send(client, tail)
      "PING" -> :gen_tcp.send(client, "+PONG\r\n")
      _ -> :gen_tcp.send(client, "Invalid command found: #{head}")
    end
  end
end
