defmodule ElixirEmailReplyParserTest do
  use ExUnit.Case
  doctest ElixirEmailReplyParser

  test "the truth" do
    assert 1 + 1 == 2
  end

  test "test_simple_body" do
    email_message = get_email('email_1_1')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message
    assert length(fragments) === 3
    for fragment <- fragments, do: %ElixirEmailReplyParser.Fragment{} = fragment

    assert (for fragment <- fragments, do: fragment.signature) === [false, true, true]
    assert (for fragment <- fragments, do: fragment.hidden) === [false, true, true]

    assert (String.contains?(Enum.at(fragments, 0).content, "folks" ))
    assert (String.contains?(Enum.at(fragments, 2).content, "riak-users"))
  end

  test "test_reads_bottom_message" do
    email_message = get_email('email_1_2')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message

    assert length(fragments) === 6

    assert (for fragment <- fragments, do: fragment.quoted) === [false, true, false, true, false, false]
    assert (for fragment <- fragments, do: fragment.signature) === [false, false, false, false, false, true]
    assert (for fragment <- fragments, do: fragment.hidden) === [false, false, false, true, true, true]

    assert (String.contains?(Enum.at(fragments, 0).content, "Hi" ))
    assert (String.contains?(Enum.at(fragments, 1).content, "On" ))
    assert (String.contains?(Enum.at(fragments, 3).content, ">" ))
    assert (String.contains?(Enum.at(fragments, 5).content, "riak-users"))
  end

  test "test_reads_inline_replies" do
    email_message = get_email('email_1_8')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message

    assert length(fragments) === 7

    assert (for fragment <- fragments, do: fragment.quoted) === [true, false, true, false, true, false, false]
    assert (for fragment <- fragments, do: fragment.signature) === [false, false, false, false, false, false, true]
    assert (for fragment <- fragments, do: fragment.hidden) === [false, false, false, false, true, true, true]
  end

  test "test_reads_top_post" do
    email_message = get_email('email_1_3')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message

    assert length(fragments) === 5
  end

  test "test_multiline_reply_headers" do
    email_message = get_email('email_1_6')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message

    assert (String.contains?(Enum.at(fragments, 0).content, "I get" ))
    assert (String.contains?(Enum.at(fragments, 1).content, "On" ))
  end

  test "test_captures_date_string" do
    email_message = get_email('email_1_4')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message

    assert (String.contains?(Enum.at(fragments, 0).content, "Awesome" ))
    assert (String.contains?(Enum.at(fragments, 1).content, "On" ))
    assert (String.contains?(Enum.at(fragments, 1).content, "Loader" ))
  end

  test "test_complex_body_with_one_fragment" do
    email_message = get_email('email_1_5')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message

    assert length(fragments) === 1
  end

  test "test_verify_reads_signature_correct" do
    email_message = get_email('correct_sig')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message

    assert length(fragments) === 2

    assert (for fragment <- fragments, do: fragment.quoted) === [false, false]
    assert (for fragment <- fragments, do: fragment.signature) === [false, true]
    assert (for fragment <- fragments, do: fragment.hidden) === [false, true]

    assert (String.contains?(Enum.at(fragments, 1).content, "--" ))
  end

  test "test_deals_with_windows_line_endings" do
    email_message = get_email('email_1_7')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message

    assert (String.contains?(Enum.at(fragments, 0).content, ":+1:" ))
    assert (String.contains?(Enum.at(fragments, 1).content, "On" ))
    assert (String.contains?(Enum.at(fragments, 1).content, "Steps 0-2" ))
  end

  test "test_parser_read" do
    content = get_email_content('email_1_2')

    email_message = ElixirEmailReplyParser.Parser.read(content)

    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message
    for fragment <- fragments, do: %ElixirEmailReplyParser.Fragment{} = fragment

    assert String.contains?(ElixirEmailReplyParser.Parser.reply(email_message), "You can list the keys for the bucket")
  end

  test "test_parser_reply" do
    email_message = get_email('email_1_2')

    reply_text = ElixirEmailReplyParser.Parser.reply(email_message)

    assert is_bitstring(reply_text)
    assert String.contains?(reply_text, "You can list the keys for the bucket")
  end

  test "test_reply_from_gmail" do
    content = get_email_content('email_gmail')

    assert ElixirEmailReplyParser.parse_reply(content) === "This is a test for inbox replying to a github message."
  end

  test "test_parse_out_just_top_for_outlook_reply" do
    content = get_email_content('email_2_1')

    assert ElixirEmailReplyParser.parse_reply(content) === "Outlook with a reply"
  end

  test "test_parse_out_just_top_for_outlook_with_reply_directly_above_line" do
    content = get_email_content('email_2_2')

    assert ElixirEmailReplyParser.parse_reply(content) === "Outlook with a reply directly above line"
  end

  test "test_sent_from_iphone" do
    content = get_email_content('email_iPhone')

    refute (String.contains?(ElixirEmailReplyParser.parse_reply(content), "Sent from my iPhone"))
  end

  test "test_email_one_is_not_on" do
    content = get_email_content('email_one_is_not_on')

    refute (String.contains?(ElixirEmailReplyParser.parse_reply(content), "On Oct 1, 2012, at 11:55 PM, Dave Tapley wrote:"))
  end

  test "test_partial_quote_header" do
    content = get_email_content('email_partial_quote_header')
    email_message = ElixirEmailReplyParser.Parser.read(content)
    reply_text = ElixirEmailReplyParser.Parser.reply(email_message)

    assert String.contains?(reply_text, "On your remote host you can run:" )
    assert String.contains?(reply_text, "telnet 127.0.0.1 52698")
    assert String.contains?(reply_text, "This should connect to TextMate")
  end

  test "test_email_headers_no_delimiter" do
    content = get_email_content('email_headers_no_delimiter')
    email_message = ElixirEmailReplyParser.Parser.read(content)
    reply_text = ElixirEmailReplyParser.Parser.reply(email_message)

    assert String.trim(reply_text) === "And another reply!"
  end

  test "test_doesnt_remove_signature_delimiter_in_mid_line" do
    email_message = get_email('email_sig_delimiter_in_middle_of_line')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message

    assert length(fragments) === 1
  end

  defp get_email_content(name) do
      {:ok, content} = File.read("test/emails/#{name}.txt")
      content
  end

  defp get_email(name) do
    ElixirEmailReplyParser.read(get_email_content(name))
  end

end
