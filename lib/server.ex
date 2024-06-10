defmodule Server do
  @moduledoc """
  Your implementation of a Redis server
  """

  use Application
  import Utils

  @table_name :cache
  @default_port 6379

  def start(_type, _args) do
    args = parse_arguments();
    port = args[:port] |> String.to_integer() || @default_port

    children = [
      {Task.Supervisor, name: Server.TaskSupervisor},
      Supervisor.child_spec({Task, fn -> Server.listen(port) end}, restart: :permanent)
    ]

    :ets.new(@table_name, [:public, :named_table])
    Supervisor.start_link(children, strategy: :one_for_one, name: Server.Superviser)
  end

  @doc """
  Listen for incoming connections
  """
  def listen(port) do
    # You can use print statements as follows for debugging, they'll be visible when running tests.
    IO.puts("Logs from your program will appear here!")

    # Uncomment this block to pass the first stage
    #
    # Since the tester restarts your program quite often, setting SO_REUSEADDR
    # ensures that we don't run into 'Address already in use' errors
    args = parse_arguments();
    if args[:replicaof] do
      [replica_host | replica_port] = args[:replicaof] |> String.split(" ")

      IO.puts("Replicating to: #{replica_host}:#{replica_port}")
      store_value(:is_master, false)
      store_value(:replica_host, replica_host)
      store_value(:replica_port, replica_port)
    else
      store_value(:is_master, true)
    end

    {:ok, socket} = :gen_tcp.listen(port, [:binary, active: false, reuseaddr: true])
    accept_next(socket)
  end

  defp accept_next(listen_socket) do
    {:ok, client} = :gen_tcp.accept(listen_socket)
    {:ok, pid} = Task.Supervisor.start_child(Server.TaskSupervisor, fn -> serve(client) end)
    :ok = :gen_tcp.controlling_process(client, pid)

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

  defp send_response(["INFO", "replication"], client) do
    msg = case get_local_value(:is_master) do
        true -> "role:master"
        false -> "role:slave"
      end

    :gen_tcp.send(client, bulk_string(msg))
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

  defp get_local_value(key) do
    case :ets.lookup(@table_name, key) do
      [{_, val}] -> val
      [{_, val, _}] -> val
      _ -> nil
    end
  end

end
