defmodule ElixirEmailReplyParser do
  @moduledoc """
  Main ElixirEmailReplyParser module
  """

  @doc false
  def read(text) do
    ElixirEmailReplyParser.Parser.read(text)
  end

  @doc ~S"""
  Extracts reply from provided email body string

  ## Parameters

    - text: Email body content as a string

  ## Examples

      iex> email_content = "Hi!\n\n How are you?\n__________\nFrom: Some Author\n\n Previous email"
      iex> ElixirEmailReplyParser.parse_reply(email_content)
      "Hi!\n\n How are you?"

  """
  @spec parse_reply(String.t) :: String.t
  def parse_reply(text) do
    text |> ElixirEmailReplyParser.Parser.read |> ElixirEmailReplyParser.Parser.reply
  end
end

defmodule ElixirEmailReplyParser.Fragment do
  @moduledoc false

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
  @moduledoc false

  defstruct [
    fragments: []
  ]
end

defmodule ElixirEmailReplyParser.Parser do
  @moduledoc false

  def read(text) do
    lines =
      text
      |> normalize_line_endings
      |> handle_multiline
      |> draw_away_lines_with_underscores
      |> String.split("\n")
      |> Enum.reverse

    {:ok, fragments} = scan_line({nil, [], false}, lines)

    %ElixirEmailReplyParser.EmailMessage{fragments: Enum.reverse(fragments)}
  end

  def reply(%ElixirEmailReplyParser.EmailMessage{fragments: fragments}) do
    fragments
    |> Enum.filter(fn f -> unless (f.hidden or f.quoted), do: true end)
    |> Enum.map(fn f -> f.content end)
    |> Enum.join("\n")
  end

  @spec normalize_line_endings(String.t) :: String.t
  defp normalize_line_endings(s) do
    String.replace(s, "\r\n", "\n")
  end

  # Check for multi-line reply headers. Some clients break up
  # the "On DATE, NAME <EMAIL> wrote:" line into multiple lines.
  @spec handle_multiline(String.t) :: String.t
  defp handle_multiline(s) do
    re = ~r/(?!On.*On\s.+?wrote:)(On\s(.+?)wrote:)/s

    if (Regex.match?(re, s)) do
      # Remove all new lines from the reply header.
      Regex.replace(re, s, fn x -> String.replace(x, "\n", "") end)
    else
      s
    end
  end

  # Some users may reply directly above a line of underscores.
  # In order to ensure that these fragments are split correctly,
  # make sure that all lines of underscores are preceded by
  # at least two newline characters.
  @spec draw_away_lines_with_underscores(String.t) :: String.t
  defp draw_away_lines_with_underscores(s) do
    Regex.replace(~r/([^\n])(?=\n_{7}_+)$/m, s, "\\1\n")
  end

  @spec string_empty?(String.t) :: boolean
  defp string_empty?(s) do
    String.trim(s) == ""
  end

  @spec string_signature?(String.t) :: boolean
  defp string_signature?(s) do
    Regex.match?(~r/(^\s*--|^\s*__|^-\w)|(^Sent from my (\w+\s*){1,3})/, s)
  end

  @spec string_quoted?(String.t) :: boolean
  defp string_quoted?(s) do
    Regex.match?(~r/^ *(>+)/, s)
  end

  @spec string_quote_header?(String.t) :: boolean
  defp string_quote_header?(s) do
    Regex.match?(~r/On.*wrote:$/, s)
  end

  @spec string_email_header?(String.t) :: boolean
  defp string_email_header?(s) do
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

  defp hide_headers({%{headers: false}, _fragments, _found_visible} = parameters) do
    parameters
  end

  defp hide_headers({fragment, fragments, _found_visible}) do
    fragments = Enum.map(fragments, fn f -> %{f | hidden: true} end)
    {fragment, fragments, false}
  end

  defp hide_hidden({_fragment, _fragments, true = _found_visible} = parameters) do
    parameters
  end

  defp hide_hidden({fragment, fragments, false = _found_visible}) do
    if (fragment.quoted or fragment.headers or fragment.signature or (string_empty?(fragment.content))) do
      {%{fragment | hidden: true}, fragments, false}
    else
      {fragment, fragments, true}
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
