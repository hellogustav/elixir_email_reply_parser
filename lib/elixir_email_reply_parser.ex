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
    {:ok, fragments} = scan_line({nil, [], false}, lines)

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

  defp string_signature?(s) when is_bitstring(s) do
    Regex.match?(~r/(^\s*--|^\s*__|^-\w)|(^Sent from my (\w+\s*){1,3})/, s)
  end

  defp string_quoted?(s) when is_bitstring(s) do
    Regex.match?(~r/^ *(>+)/, s)
  end

  defp string_quote_header?(s) when is_bitstring(s) do
    Regex.match?(~r/On.*wrote:$/, s)
  end

  defp string_email_header?(s) when is_bitstring(s) do
    Regex.match?(~r/^(From|Sent|To|Subject): .+/, s)
  end

  defp scan_line({nil, fragments, _found_visible}, []) do
    {:ok, Enum.reverse(fragments)}
  end

  defp scan_line({_fragment, _fragments, _found_visible} = parameters, []) do
    parameters
    |> finish_fragment
    |> scan_line([])
  end

  defp scan_line({_fragment, _fragments, _found_visible} = parameters, [line | lines]) do
    parameters
    |> check_signature(string_empty?(line))
    |> process_line(line)
    |> scan_line(lines)
  end

  defp consolidate_lines(fragment) do
    %{fragment | content: String.trim(Enum.join(fragment.lines, "\n")), lines: nil}
  end

  defp mark_as_signature(fragment) do
    %{fragment | signature: true}
  end

  defp hide_headers({fragment, fragments, found_visible} = parameters) do
    if (fragment.headers) do
      found_visible = false
      fragments = for frag <- fragments, do: %{frag | hidden: true}
      {fragment, fragments, found_visible}
    else
      parameters
    end
  end

  defp hide_hidden({fragment, fragments, found_visible} = parameters) do
    if (found_visible) do
      parameters
    else
      if (fragment.quoted or fragment.headers or fragment.signature or (string_empty?(fragment.content))) do
        {%{fragment | hidden: true}, fragments, found_visible}
      else
        {fragment, fragments, true}
      end
    end
  end

  defp add_fragment({fragment, fragments, found_visible}) do
    {nil, [fragment | fragments], found_visible}
  end

  defp finish_fragment({nil, _fragments, _found_visible} = parameters) do
    parameters
  end

  defp finish_fragment({fragment, fragments, found_visible}) do
    fragment = consolidate_lines(fragment)
    {fragment, fragments, found_visible}
    |> hide_headers
    |> hide_hidden
    |> add_fragment
  end

  defp check_signature(parameters, false) do
    parameters
  end

  defp check_signature({nil, _fragments, _found_visible} = parameters, true) do
    parameters
  end

  defp check_signature({fragment, fragments, found_visible} = parameters, true) do
    [previous_line | _tail] = fragment.lines
    is_previous_line_signature =
      previous_line
      |> String.trim
      |> string_signature?
    if (is_previous_line_signature) do
      fragment = mark_as_signature(fragment)
      finish_fragment({fragment, fragments, found_visible})
    else
      parameters
    end
  end

  defp process_line({fragment, fragments, found_visible}, line) do
    is_quoted = string_quoted?(line)
    is_quote_header = string_quote_header?(line)
    is_header = is_quote_header or string_email_header?(line)
    is_empty = string_empty?(line)

    if (fragment && (((fragment.headers == is_header) and (fragment.quoted == is_quoted)) or (fragment.quoted and (is_quote_header or is_empty)))) do
      fragment = %{fragment | lines: [line | fragment.lines]}
      {fragment, fragments, found_visible}
    else
      {_fragment, fragments, found_visible} = finish_fragment({fragment, fragments, found_visible})
      fragment = %ElixirEmailReplyParser.Fragment{lines: [line], quoted: is_quoted, headers: is_header}
      {fragment, fragments, found_visible}
    end
  end
end
