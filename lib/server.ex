defmodule Server do
  @moduledoc """
  Your implementation of a Redis server
  """

  use Application
  import Utils

  @table_name :cache

  def start(_type, _args) do
    :ets.new(@table_name, [:public, :named_table])
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
    client
      |> recieve_data()
      |> decode_data()
      |> send_response(client)

    serve(client)
  end

  defp decode_data(data) do
    data
    |> String.trim()  # Remove leading/trailing whitespace
    |> String.replace(~r/\$\d{1,}/, "") # Replace a $<any_digit> with blank
    |> String.replace(~r/\*\d{1,}/, "") # Replace a *<any_digit> with blank
    |> String.split("\r\n")  # Split on newline characters
    |> Enum.filter(&(&1 != "")) # Remove empty strings from array
    |> List.update_at(0, &String.upcase/1) # Ensure command is uppercased
  end

  defp recieve_data(client) do
    {:ok, data} = :gen_tcp.recv(client, 0);
    data
  end

  defp send_response(["ECHO" | tail], client) do
    :gen_tcp.send(client, simple_string(tail))
  end

  defp send_response(["GET" | [key]], client) do
    :gen_tcp.send(client, get_value(key))
  end

  defp send_response(["SET", key, value, expiry_key, expiry | _tail], client) when expiry_key in ["px", "PX", "Px", "pX"] do
    :gen_tcp.send(client, store_value(key, value, :os.system_time(:millisecond) + String.to_integer(expiry)))
  end

  defp send_response(["SET", key | tail], client) do
    :gen_tcp.send(client, store_value(key, tail))
  end

  defp send_response(["PING" | _tail], client) do
    :gen_tcp.send(client, simple_string("PONG"))
  end

  defp store_value(key, val) do
    :ets.insert(@table_name, {key, val})
    simple_string("OK")
  end

  defp store_value(key, val, expiry) do
    :ets.insert(@table_name, {key, val, expiry})
    simple_string("OK")
  end

  defp get_value(key) do
    current_time = :os.system_time(:millisecond)

    case :ets.lookup(@table_name, key) do
      [{_, val}] -> bulk_string(val)
      [{_, val, timestamp}] when timestamp > current_time -> bulk_string(val)
      _ -> null()
    end
  end

end
