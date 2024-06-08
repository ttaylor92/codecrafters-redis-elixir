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
    serve(socket)
  end

  defp serve(socket) do
    # Receive data from the current client concurrently
    Task.async(fn ->
      {:ok, _data} = receive do
        {^socket, data} -> data
      end
      # Process the data (potentially in a separate function)
      # ...
    end)

    # Accept the next connection concurrently
    {:ok, client} = :gen_tcp.accept(socket)

    # Send response to the current client
    data = recieve_data(socket)
    send_response(data, socket)

    # Close the connection after processing the request
    :gen_tcp.close(socket)

    # Recursively serve the next client
    serve(client)
  end

  defp recieve_data(socket) do
    {:ok, data} = :gen_tcp.recv(socket, 0);
    data
  end

  defp send_response(data, client) do
    IO.puts(data)
    :gen_tcp.send(client, "+PONG\r\n")
  end
end
