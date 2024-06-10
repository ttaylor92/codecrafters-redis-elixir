defmodule Utils do
  def simple_string(str) do
    "+#{str}\r\n"
  end

  def bulk_string(str) do
    "$#{String.length(String.Chars.to_string(str))}\r\n#{str}\r\n"
  end

  def null, do: "$-1\r\n"

  def parse_arguments do
    {opts, _} = System.argv() |> OptionParser.parse!(switches: [key: :string])
    opts
  end
end
