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

  def parse_reply(text) do
    text |> ElixirEmailReplyParser.Parser.read |> ElixirEmailReplyParser.Parser.reply
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
    text = if (Regex.match?(~r/(?!On.*On\s.+?wrote:)(On\s(.+?)wrote:)/s, text)) do
      # Remove all new lines from the reply header.
      Regex.replace(~r/(?!On.*On\s.+?wrote:)(On\s(.+?)wrote:)/s, text, fn x -> String.replace(x, "\n", "") end)
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
    {:ok, fragments} = scan_line([], false, nil, lines)

    %ElixirEmailReplyParser.EmailMessage{fragments: Enum.reverse(fragments)}
  end

  def reply(%ElixirEmailReplyParser.EmailMessage{fragments: fragments}) do
    fragments
    |> Enum.filter_map(fn f -> unless (f.hidden or f.quoted), do: f end,
      fn f -> f.content end)
    |> Enum.join("\n")
  end

  defp string_empty?(s) when is_bitstring(s) do
    String.trim(s) === ""
  end

  defp scan_line(fragments, _found_visible, nil, []), do: {:ok, Enum.reverse(fragments)}

  defp scan_line(fragments, found_visible, fragment, []) do
    if (fragment) do
      fragment = %{fragment | content: String.trim(Enum.join(fragment.lines, "\n")), lines: nil}
      if (fragment.headers) do
        found_visible = false
        fragments = for frag <- fragments, do: %{frag | hidden: true}
      end
      unless (found_visible) do
        if (fragment.quoted or fragment.headers or fragment.signature or (string_empty?(fragment.content))) do
          fragment = %{fragment | hidden: true}
        else
          found_visible = true
        end
      end
      fragments = [fragment | fragments]
    end
    scan_line(fragments, found_visible, nil, [])
  end

  defp scan_line(fragments, found_visible, fragment, [line | lines]) do
    is_quoted = Regex.match?(~r/^ *(>+)/, line)
    is_quote_header = Regex.match?(~r/On.*wrote:$/, line)
    is_header = is_quote_header or Regex.match?(~r/^(From|Sent|To|Subject): .+/, line)
    is_empty = string_empty?(line)

    if (fragment && is_empty) do
      [previous_line | _tail] = fragment.lines
      previous_line = String.trim(previous_line)
      if (Regex.match?(~r/(--|__|-\w)|(^Sent from my (\w+\s*){1,3})/, previous_line)) do
        fragment = %{fragment | content: String.trim(Enum.join(fragment.lines, "\n")), signature: true, lines: nil}
        if (fragment.headers) do
          found_visible = false
          fragments = for frag <- fragments, do: %{frag | hidden: true}
        end
        unless (found_visible) do
          if (fragment.quoted or fragment.headers or fragment.signature or (string_empty?(fragment.content))) do
            fragment = %{fragment | hidden: true}
          else
            found_visible = true
          end
        end
        fragments = [fragment | fragments]
        fragment = nil
      end
    end

    if (fragment && (((fragment.headers == is_header) and (fragment.quoted == is_quoted)) or (fragment.quoted and (is_quote_header or is_empty)))) do
      fragment = %{fragment | lines: [line | fragment.lines]}
    else
      if (fragment) do
        fragment = %{fragment | content: String.trim(Enum.join(fragment.lines, "\n")), lines: nil}
        if (fragment.headers) do
          found_visible = false
          fragments = for frag <- fragments, do: %{frag | hidden: true}
        end
        unless (found_visible) do
          if (fragment.quoted or fragment.headers or fragment.signature or (string_empty?(fragment.content))) do
            fragment = %{fragment | hidden: true}
          else
            found_visible = true
          end
        end
        fragments = [fragment | fragments]
        fragment = nil
      end
      fragment = %ElixirEmailReplyParser.Fragment{lines: [line], quoted: is_quoted, headers: is_header}
    end
    scan_line(fragments, found_visible, fragment, lines)
  end
end
