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
    # Normalize line endings.
    text = String.replace(text, "\r\n", "\n")

    # Check for multi-line reply headers. Some clients break up
    # the "On DATE, NAME <EMAIL> wrote:" line into multiple lines.
    text = if (Regex.match?(~r/^(?!On.*On\s.+?wrote:)(On\s(.+?)wrote:)$/m, text)) do
      # Remove all new lines from the reply header.
      Regex.replace(~r/^(?!On.*On\s.+?wrote:)(On\s(.+?)wrote:)$/, text, fn x -> String.replace(x, "\n", "") end)
    else
      text
    end

    # Some users may reply directly above a line of underscores.
    # In order to ensure that these fragments are split correctly,
    # make sure that all lines of underscores are preceded by
    # at least two newline characters.
    text = Regex.replace(~r/([^\n])(?=\n_{7}_+)$/m, text, "\\1\n")
    lines = String.split(text, "\n")
    lines = Enum.reverse(lines)
    {:ok, fragments} = scan_line([], nil, lines)

    %ElixirEmailReplyParser.EmailMessage{fragments: Enum.reverse(fragments)}
  end

  defp scan_line(fragments, nil, []), do: {:ok, fragments}

  defp scan_line(fragments, nil, [line | lines]) do
    fragment = %ElixirEmailReplyParser.Fragment{content: "#{line}"}
    scan_line([fragment | fragments], nil, lines)
  end

  defp scan_line(fragments, fragment, lines) do
    scan_line([fragment | fragments], nil, lines)
  end
end
