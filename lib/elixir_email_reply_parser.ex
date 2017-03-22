defmodule ElixirEmailReplyParser do
  @moduledoc """
  Documentation for ElixirEmailReplyParser.
  """

  @doc """
  Hello world.

  ## Examples

      iex> ElixirEmailReplyParser.hello
      :world

  """
  def hello do
    :world
  end

  def read(text) do
    ElixirEmailReplyParser.Parser.read(text)
  end
end

defmodule ElixirEmailReplyParser.Fragment do
  defstruct [
    signature: false,
    headers: false,
    hidden: false,
    quoted: false,
    content: nil,
    lines: []
  ]
end

defmodule ElixirEmailReplyParser.EmailMessage do
  defstruct [
    fragments: []
  ]
end

defmodule ElixirEmailReplyParser.Parser do
  def read(text) do
    lines = String.split(text, "\n")
    fragments = for line <- lines, do: %ElixirEmailReplyParser.Fragment{content: "#{line}"}
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments}
  end
end
