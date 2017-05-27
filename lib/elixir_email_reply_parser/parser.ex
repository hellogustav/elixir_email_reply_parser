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
    re_en = ~r/(?!On.*On\s.+?wrote:)(On\s(.+?)wrote:)/s
    re_de1 = ~r/(schrieb\sam\s(.+?)um\s(.+?):)/s
    re_de2 = ~r/(Am\s(.+?)um\s(.+?)schrieb\s(.+?):)/s
    s
    |> remove_newlines_if_matched(re_en)
    |> remove_newlines_if_matched(re_de1)
    |> remove_newlines_if_matched(re_de2)
  end

  # For removal of all new lines from the reply header.
  @spec remove_newlines_if_matched(String.t, Regex.t) :: String.t
  defp remove_newlines_if_matched(s, re) do
    if (Regex.match?(re, s)) do
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
    or
    Regex.match?(~r/^Diese Nachricht wurde von mein.* gesendet\.?$/, s)
    or
    Regex.match?(~r/^Von mein.* gesendet\.?$/, s)
  end

  @spec string_quoted?(String.t) :: boolean
  defp string_quoted?(s) do
    Regex.match?(~r/^ *(>+)/, s)
  end

  @spec string_quote_header?(String.t) :: boolean
  defp string_quote_header?(s) do
    Regex.match?(~r/On.*wrote:$/, s)
    or
    Regex.match?(~r/^.+schrieb am.+um.+:$/, s)
    or
    Regex.match?(~r/^Am.+um.+schrieb.+:$/, s)
    or
    Regex.match?(~r/^-{5}Ursprüngliche Nachricht-{5}$/, s)
  end

  @spec string_email_header?(String.t) :: boolean
  defp string_email_header?(s) do
    Regex.match?(~r/^(From|Sent|To|Subject): .+/, s)
    or
    Regex.match?(~r/^\*?(Von|Gesendet|An|Betreff):\*? .+/, s)
  end

  defp scan_line({nil, fragments, _found_visible}, []) do
    {:ok, Enum.reverse(fragments)}
  end

  defp scan_line({_fragment, _fragments, _found_visible} = parameters, []) do
    parameters
    |> finish_fragment
    |> scan_line([])
  end

  defp scan_line({fragment, _fragments, _found_visible} = parameters, [line | lines]) do
    is_quoted = string_quoted?(line)
    is_quote_header = string_quote_header?(line)
    is_header = is_quote_header or string_email_header?(line)
    is_empty = string_empty?(line)

    parameters
    |> check_signature(is_empty, previous_line_signature?(fragment))
    |> process_line(line, is_quoted, is_header, is_quote_header, is_empty)
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

  defp hide_hidden({_fragment, _fragments, true = _found_visible} = parameters), do: parameters
  defp hide_hidden({%{quoted: true} = fragment, fragments, false}), do: {%{fragment | hidden: true}, fragments, false}
  defp hide_hidden({%{headers: true} = fragment, fragments, false}), do: {%{fragment | hidden: true}, fragments, false}
  defp hide_hidden({%{signature: true} = fragment, fragments, false}), do: {%{fragment | hidden: true}, fragments, false}
  defp hide_hidden({%{content: ""} = fragment, fragments, false}), do: {%{fragment | hidden: true}, fragments, false}
  defp hide_hidden({fragment, fragments, false}), do: {fragment, fragments, true}

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

  defp previous_line_signature?(nil) do
    false
  end

  defp previous_line_signature?(%{lines: [previous_line | _tail]} = _fragment) do
    previous_line
    |> String.trim
    |> string_signature?
  end

  defp check_signature(parameters, line_is_empty, previous_line_is_signature)
  defp check_signature(parameters, false , _), do: parameters
  defp check_signature(parameters, true, false), do: parameters
  defp check_signature({fragment, fragments, found_visible}, true, true), do: finish_fragment({mark_as_signature(fragment), fragments, found_visible})

  defp add_line_to_fragment({fragment, fragments, found_visible}, line) do
    fragment = %{fragment | lines: [line | fragment.lines]}
    {fragment, fragments, found_visible}
  end

  defp make_new_fragment({fragment, fragments, found_visible}, line, is_quoted, is_header) do
    {_fragment, fragments, found_visible} = finish_fragment({fragment, fragments, found_visible})
    fragment = %ElixirEmailReplyParser.Fragment{lines: [line], quoted: is_quoted, headers: is_header}
    {fragment, fragments, found_visible}
  end

  defp process_line(parameters, line, is_quoted, is_header, is_quote_header, is_empty)
  defp process_line({nil, _f, _fv} = p, l, q, h, _qh , _e), do: make_new_fragment(p, l, q, h)
  defp process_line({%{headers: h, quoted: q}, _f, _fv} = p, l, q, h, _qh, _e), do: add_line_to_fragment(p, l)
  defp process_line({%{quoted: true}, _f, _fv} = p, l, _q, _h, true, _e), do: add_line_to_fragment(p, l)
  defp process_line({%{quoted: true}, _f, _fv} = p, l, _q, _h, _qh, true), do: add_line_to_fragment(p, l)
  defp process_line(p, l, q, h, _qh, _e), do: make_new_fragment(p, l, q, h)
end
