defmodule ElixirEmailReplyParser.Parser do
  @moduledoc false

  def read(text) do
    lines =
      text
      |> normalize_line_endings
      |> handle_multiline
      |> draw_away_lines_with_underscores
      |> draw_away_signatures
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
    |> String.trim_trailing()
  end

  @spec normalize_line_endings(String.t) :: String.t
  defp normalize_line_endings(s) do
    String.replace(s, "\r\n", "\n")
  end

  # Check for multi-line reply headers. Some clients break up
  # the "On DATE, NAME <EMAIL> wrote:" line into multiple lines.
  @spec handle_multiline(String.t) :: String.t
  defp handle_multiline(s) do
    Enum.reduce([
          ~R/(?!On.*On\s.+?wrote:)(On\s(.+?)wrote:)/s,
          ~R/(schrieb\sam\s(.+?)um\s(.+?):)/s,
          ~R/(Am\s(.+?)um\s(.+?)schrieb\s(.+?):)/s ],
        s,
        &remove_newlines_if_matched/2)
  end

  # For removal of all new lines from the reply header.
  @spec remove_newlines_if_matched(Regex.t, String.t) :: String.t
  defp remove_newlines_if_matched(re, s) do
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
    Regex.replace(~R/([^\n])(?=\n_{7}_+)$/m, s, "\\1\n")
  end

  # Some users may write directly above signature markers
  # In order to ensure that these fragments are split correctly,
  # make sure that all lines with signature markers are preceded by
  # at least two newline characters.
  @spec draw_away_signatures(String.t) :: String.t
  defp draw_away_signatures(s) do
    Regex.replace(~R/([^\n])(?=\n-{2,}\s*\n)$/m, s, "\\1\n")
  end

  @spec string_empty?(String.t) :: boolean
  defp string_empty?(s) do
    String.trim(s) == ""
  end

  @spec match_at_least_one_regex?(String.t, [Regex.t]) :: boolean
  defp match_at_least_one_regex?(s, regexes)
  defp match_at_least_one_regex?(_, []), do: false
  defp match_at_least_one_regex?(s, [head | tail]), do: (Regex.match?(head, s) or match_at_least_one_regex?(s, tail))

  @spec string_signature?(String.t) :: boolean
  defp string_signature?(s) do
    match_at_least_one_regex?(s, [
        ~R/(^\s*--|^\s*__|^-\w)|(^Sent from my ([a-zA-Z0-9_-]+\s*){1,3})\.?$/,
        ~R/^Diese Nachricht wurde von mein.* gesendet\.?$/,
        ~R/^Von mein.* gesendet\.?$/,
        ~R/^Gesendet von mein.* ([a-zA-Z0-9_-]+\s*){1,3}\.?$/,
        ~R"^Get Outlook for (iOS|Android) <https?://[a-z0-9.-]+[a-zA-Z0-9/.,_:;#?%!@$&'()*+~=-]*>$",
        ~R"^Outlook für (iOS|Android) beziehen <https?://[a-z0-9.-]+[a-zA-Z0-9/.,_:;#?%!@$&'()*+~=-]*>$"])
  end

  @spec string_quoted?(String.t) :: boolean
  defp string_quoted?(s) do
    Regex.match?(~R/^ *(>+)/, s)
  end

  @spec string_quote_header?(String.t) :: boolean
  defp string_quote_header?(s) do
    match_at_least_one_regex?(s, [
        ~R/On.*wrote:$/,
        ~R/^.+schrieb am.+um.+:$/,
        ~R/^Am.+um.+schrieb.+:$/,
        ~R/^-{5}Ursprüngliche Nachricht-{5}$/])
  end

  @spec string_email_header?(String.t) :: boolean
  defp string_email_header?(s) do
    match_at_least_one_regex?(s, [
        ~R/^\*?(From|Sent|To|Subject):\*? .+/,
        ~R/^\*?(Von|Gesendet|An|Betreff):\*? .+/ ])
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
    content =
      fragment.lines
      |> Enum.join("\n")
      |> String.trim_leading()
    %{fragment | content: content, lines: nil}
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
    string_signature?(previous_line)
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
