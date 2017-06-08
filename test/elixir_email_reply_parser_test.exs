defmodule ElixirEmailReplyParserTest do
  use ExUnit.Case, async: true
  doctest ElixirEmailReplyParser

  test "test_simple_body" do
    email_message = get_email('email_1_1')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message
    assert length(fragments) == 3
    for fragment <- fragments, do: %ElixirEmailReplyParser.Fragment{} = fragment

    assert (for fragment <- fragments, do: fragment.signature) == [false, true, true]
    assert (for fragment <- fragments, do: fragment.hidden) == [false, true, true]

    assert String.contains?(Enum.at(fragments, 0).content, "folks" )
    assert String.contains?(Enum.at(fragments, 2).content, "riak-users")
  end

  test "test_reads_bottom_message" do
    email_message = get_email('email_1_2')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message

    assert length(fragments) == 6

    assert (for fragment <- fragments, do: fragment.quoted) == [false, true, false, true, false, false]
    assert (for fragment <- fragments, do: fragment.signature) == [false, false, false, false, false, true]
    assert (for fragment <- fragments, do: fragment.hidden) == [false, false, false, true, true, true]

    assert String.contains?(Enum.at(fragments, 0).content, "Hi" )
    assert String.contains?(Enum.at(fragments, 1).content, "On" )
    assert String.contains?(Enum.at(fragments, 3).content, ">" )
    assert String.contains?(Enum.at(fragments, 5).content, "riak-users")
  end

  test "test_reads_inline_replies" do
    email_message = get_email('email_1_8')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message

    assert length(fragments) == 7

    assert (for fragment <- fragments, do: fragment.quoted) == [true, false, true, false, true, false, false]
    assert (for fragment <- fragments, do: fragment.signature) == [false, false, false, false, false, false, true]
    assert (for fragment <- fragments, do: fragment.hidden) == [false, false, false, false, true, true, true]
  end

  test "test_reads_top_post" do
    email_message = get_email('email_1_3')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message

    assert length(fragments) == 5
  end

  test "test_multiline_reply_headers" do
    email_message = get_email('email_1_6')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message

    assert String.contains?(Enum.at(fragments, 0).content, "I get" )
    assert String.contains?(Enum.at(fragments, 1).content, "On" )
  end

  test "test_captures_date_string" do
    email_message = get_email('email_1_4')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message

    assert String.contains?(Enum.at(fragments, 0).content, "Awesome" )
    assert String.contains?(Enum.at(fragments, 1).content, "On" )
    assert String.contains?(Enum.at(fragments, 1).content, "Loader" )
  end

  test "test_complex_body_with_one_fragment" do
    email_message = get_email('email_1_5')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message

    assert length(fragments) == 1
  end

  test "test_verify_reads_signature_correct" do
    email_message = get_email('correct_sig')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message

    assert length(fragments) == 2

    assert (for fragment <- fragments, do: fragment.quoted) == [false, false]
    assert (for fragment <- fragments, do: fragment.signature) == [false, true]
    assert (for fragment <- fragments, do: fragment.hidden) == [false, true]

    assert String.contains?(Enum.at(fragments, 1).content, "--" )
  end

  test "test_deals_with_windows_line_endings" do
    email_message = get_email('email_1_7')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message

    assert String.contains?(Enum.at(fragments, 0).content, ":+1:" )
    assert String.contains?(Enum.at(fragments, 1).content, "On" )
    assert String.contains?(Enum.at(fragments, 1).content, "Steps 0-2" )
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

    assert ElixirEmailReplyParser.parse_reply(content) == "This is a test for inbox replying to a github message."
  end

  test "test_parse_out_just_top_for_outlook_reply" do
    content = get_email_content('email_2_1')

    assert ElixirEmailReplyParser.parse_reply(content) == "Outlook with a reply"
  end

  test "test_parse_out_just_top_for_outlook_with_reply_directly_above_line" do
    content = get_email_content('email_2_2')

    assert ElixirEmailReplyParser.parse_reply(content) == "Outlook with a reply directly above line"
  end

  test "test_sent_from_iphone" do
    content = get_email_content('email_iPhone')

    refute String.contains?(ElixirEmailReplyParser.parse_reply(content), "Sent from my iPhone")
  end

  test "test_email_one_is_not_on" do
    content = get_email_content('email_one_is_not_on')

    refute String.contains?(ElixirEmailReplyParser.parse_reply(content), "On Oct 1, 2012, at 11:55 PM, Dave Tapley wrote:")
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

    assert String.trim(reply_text) == "And another reply!"
  end

  test "test_multiple_on" do
    email_message = get_email('greedy_on')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message

    assert length(fragments) == 3
    assert Regex.match?(~r/^On your remote host/, Enum.at(fragments, 0).content)
    assert Regex.match?(~r/^On 9 Jan 2014/, Enum.at(fragments, 1).content)


    assert (for fragment <- fragments, do: fragment.quoted) == [false, true, false]
    assert (for fragment <- fragments, do: fragment.signature) == [false, false, false]
    assert (for fragment <- fragments, do: fragment.hidden) == [false, true, true]
  end

  test "test_pathological_emails" do
    content = get_email_content('pathological')

    {computation_time, reply_text} = :timer.tc(&ElixirEmailReplyParser.parse_reply/1, [content])

    assert(computation_time < 1000000, "Took too long")

    assert reply_text == "I think you're onto something. I will try to fix the problem as soon as I\nget back to a computer."
  end

  test "test_doesnt_remove_signature_delimiter_in_mid_line" do
    email_message = get_email('email_sig_delimiter_in_middle_of_line')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message

    assert length(fragments) == 1
  end

  test "german_reply_1" do
    content = get_email_content("de/german1")

    assert ElixirEmailReplyParser.parse_reply(content) == "Danke, Adam\n\nMir geht es gut.\n\nEva"
  end

  test "german_reply_2" do
    content = get_email_content("de/german2")

    assert ElixirEmailReplyParser.parse_reply(content) == "Danke, Adam\n\nMir geht es gut.\n\nEva"
  end

  test "german_reply_3" do
      content = get_email_content("de/german3")

      assert ElixirEmailReplyParser.parse_reply(content) == "Danke, Adam\n\nMir geht es gut.\n\nEva"
    end

  test "german_footer_1" do
    content = get_email_content("de/german_footer_1")

    assert ElixirEmailReplyParser.parse_reply(content) == "Hallo Adam\n\nGut, und dir?\n\nEva\n\nMag. Eva Musterfrau\nA-1000 Wien, Grüngasse 1\nTel: +44-7700-900333"
  end

  test "german_footer_2" do
    content = get_email_content("de/german_footer_2")

    assert ElixirEmailReplyParser.parse_reply(content) == "Danke, auch gut."
  end

  test "german_footer_3" do
    content = get_email_content("de/german_footer_3")

    assert ElixirEmailReplyParser.parse_reply(content) == "Danke, Adam\n\nMir geht es gut.\n\nEva"
  end

  test "german_headers" do
    content = get_email_content("de/german_headers")

    assert ElixirEmailReplyParser.parse_reply(content) == "Hallo Adam\n\nGut, und dir?\n\nEva\n\nMag. Eva Musterfrau\nA-1000 Wien, Grüngasse 1\nTel: +44-7700-900333"
  end

  test "german_reply_1_multiline_header" do
    content = get_email_content("de/german1_multiline")

    assert ElixirEmailReplyParser.parse_reply(content) == "Danke, Adam\n\nMir geht es gut.\n\nEva"
  end

  test "german_reply_2_multiline_header" do
    content = get_email_content("de/german2_multiline")

    assert ElixirEmailReplyParser.parse_reply(content) == "Danke, Adam\n\nMir geht es gut.\n\nEva"
  end

  test "ruby_test_reads_simple_body" do
    email_message = get_email('email_1_1')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message
    assert length(fragments) == 3
    for fragment <- fragments, do: %ElixirEmailReplyParser.Fragment{} = fragment

    assert (for fragment <- fragments, do: fragment.quoted) == [false, false, false]
    assert (for fragment <- fragments, do: fragment.signature) == [false, true, true]
    assert (for fragment <- fragments, do: fragment.hidden) == [false, true, true]

    assert Enum.at(fragments, 0).content == "Hi folks

What is the best way to clear a Riak bucket of all key, values after \nrunning a test?
I am currently using the Java HTTP API.\n"
    assert Enum.at(fragments, 1).content == "-Abhishek Kona\n\n"
  end

  test "ruby_test_reads_top_post" do
    email_message = get_email('email_1_3')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message
    assert length(fragments) == 5

    assert (for fragment <- fragments, do: fragment.quoted) == [false, false, true, false, false]
    assert (for fragment <- fragments, do: fragment.signature) == [false, true, true, true, true]
    assert (for fragment <- fragments, do: fragment.hidden) == [false, true, false, false, true]

    assert Regex.match?(~R/^Oh thanks.\n\nHaving/, Enum.at(fragments, 0).content)
    assert Regex.match?(~R/^-A/, Enum.at(fragments, 1).content)
    assert Regex.match?(~R/^On [^\:]+\:/, Enum.at(fragments, 2).content)
    assert Regex.match?(~R/^_/, Enum.at(fragments, 4).content)
  end

  test "ruby_test_reads_bottom_post" do
    email_message = get_email('email_1_2')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message
    assert length(fragments) == 6

    assert (for fragment <- fragments, do: fragment.quoted) == [false, true, false, true, false, false]
    assert (for fragment <- fragments, do: fragment.signature) == [false, false, false, false, false, true]
    assert (for fragment <- fragments, do: fragment.hidden) == [false, false, false, true, true, true]

    assert Enum.at(fragments, 0).content ==  "Hi,"
    assert Regex.match?(~R/^On [^\:]+\:/, Enum.at(fragments, 1).content)
    assert Regex.match?(~R/^You can list/, Enum.at(fragments, 2).content)
    assert Regex.match?(~R/^> /, Enum.at(fragments, 3).content)
    assert Regex.match?(~R/^_/, Enum.at(fragments, 5).content)
  end

  test "ruby_test_reads_inline_replies" do
    email_message = get_email('email_1_8')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message
    assert length(fragments) == 7

    assert (for fragment <- fragments, do: fragment.quoted) == [true, false, true, false, true, false, false]
    assert (for fragment <- fragments, do: fragment.signature) == [false, false, false, false, false, false, true]
    assert (for fragment <- fragments, do: fragment.hidden) == [false, false, false, false, true, true, true]

    assert Regex.match?(~R/^On [^\:]+\:/, Enum.at(fragments, 0).content)
    assert Regex.match?(~R/^I will reply/, Enum.at(fragments, 1).content)
    assert String.contains?(Enum.at(fragments, 2).content, "okay?")
    assert Regex.match?(~R/^and under this./, Enum.at(fragments, 3).content)
    assert Regex.match?(~R/inline/, Enum.at(fragments, 4).content)
    assert Enum.at(fragments, 5).content == "\n"
    assert Enum.at(fragments, 6).content == "--\nHey there, this is my signature\n"
  end

  test "ruby_test_recognizes_date_string_above_quote" do
    email_message = get_email('email_1_4')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message

    assert Regex.match?(~R/^Awesome/, Enum.at(fragments, 0).content)
    assert Regex.match?(~R/^On/, Enum.at(fragments, 1).content)
    assert Regex.match?(~R/Loader/, Enum.at(fragments, 1).content)
  end

  test "ruby_test_a_complex_body_with_only_one_fragment" do
    email_message = get_email('email_1_5')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message
    assert length(fragments) == 1
  end

  test "ruby_test_reads_email_with_correct_signature" do
    email_message = get_email('correct_sig')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message
    assert length(fragments) == 2

    assert (for fragment <- fragments, do: fragment.quoted) == [false, false]
    assert (for fragment <- fragments, do: fragment.signature) == [false, true]
    assert (for fragment <- fragments, do: fragment.hidden) == [false, true]

    assert Regex.match?(~R/^-- \nrick/, Enum.at(fragments, 1).content)
  end

  test "ruby_test_deals_with_multiline_reply_headers" do
    email_message = get_email('email_1_6')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message

    assert Regex.match?(~R/^I get/, Enum.at(fragments, 0).content)
    assert Regex.match?(~R/^On/, Enum.at(fragments, 1).content)
    assert Regex.match?(~R/Was this/, Enum.at(fragments, 1).content)
  end

  test "ruby_test_deals_with_windows_line_endings" do
    email_message = get_email('email_1_7')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message

    assert Regex.match?(~R/:\+1:/, Enum.at(fragments, 0).content)
    assert Regex.match?(~R/^On/, Enum.at(fragments, 1).content)
    assert Regex.match?(~R/Steps 0-2/, Enum.at(fragments, 1).content)
  end

  test "ruby_test_handles_non_ascii_characters" do
    non_ascii_body = "Here’s a test."

    assert ElixirEmailReplyParser.parse_reply(non_ascii_body) == non_ascii_body
  end

  test "modified_ruby_test_returns_only_the_visible_fragments_as_a_string" do
    email_message = get_email('email_1_2')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message

    assert ElixirEmailReplyParser.Parser.reply(email_message) == fragments |> Enum.filter_map(&(!(&1.hidden || &1.quoted)), &(&1.content)) |> Enum.join("\n") |> String.trim_trailing()
  end

  test "ruby_test_parse_out_just_top_for_outlook_reply" do
    body = get_email_content("email_2_1")
    assert ElixirEmailReplyParser.parse_reply(body) == "Outlook with a reply"
  end

  test "ruby_test_parse_out_just_top_for_outlook_with_reply_directly_above_line" do
    body = get_email_content("email_2_2")
    assert ElixirEmailReplyParser.parse_reply(body) == "Outlook with a reply directly above line"
  end

  test "ruby_test_parse_out_sent_from_iPhone" do
    body = get_email_content("email_iPhone")
    assert ElixirEmailReplyParser.parse_reply(body) == "Here is another email"
  end

  test "ruby_test_parse_out_sent_from_BlackBerry" do
    body = get_email_content("email_BlackBerry")
    assert ElixirEmailReplyParser.parse_reply(body) == "Here is another email"
  end

  test "ruby_test_parse_out_send_from_multiword_mobile_device" do
    body = get_email_content("email_multi_word_sent_from_my_mobile_device")
    assert ElixirEmailReplyParser.parse_reply(body) == "Here is another email"
  end

  test "ruby_test_do_not_parse_out_send_from_in_regular_sentence" do
    body = get_email_content("email_sent_from_my_not_signature")
    assert ElixirEmailReplyParser.parse_reply(body) == "Here is another email\n\nSent from my desk, is much easier then my mobile phone."
  end

  test "ruby_test_retains_bullets" do
    body = get_email_content("email_bullets")
    assert ElixirEmailReplyParser.parse_reply(body) == "test 2 this should list second\n\nand have spaces\n\nand retain this formatting\n\n\n   - how about bullets\n   - and another"
  end

  test "ruby_test_one_is_not_on" do
    email_message = get_email('email_one_is_not_on')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message

    assert Regex.match?(~R/One outstanding question/, Enum.at(fragments, 0).content)
    assert Regex.match?(~R/^On Oct 1, 2012/, Enum.at(fragments, 1).content)
  end

  test "ruby_test_multiple_on" do
    email_message = get_email('greedy_on')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message

    assert (for fragment <- fragments, do: fragment.quoted) == [false, true, false]
    assert (for fragment <- fragments, do: fragment.signature) == [false, false, false]
    assert (for fragment <- fragments, do: fragment.hidden) == [false, true, true]

    assert Regex.match?(~R/^On your remote host/, Enum.at(fragments, 0).content)
    assert Regex.match?(~R/^On 9 Jan 2014/, Enum.at(fragments, 1).content)
  end

  test "ruby_test_doesnt_remove_signature_delimiter_in_mid_line" do
    email_message = get_email('email_sig_delimiter_in_middle_of_line')
    %ElixirEmailReplyParser.EmailMessage{fragments: fragments} = email_message

    assert length(fragments) == 1
  end

  defp get_email_content(name) do
    {:ok, content} = File.read("test/emails/#{name}.txt")
    content
  end

  defp get_email(name) do
    ElixirEmailReplyParser.read(get_email_content(name))
  end

end
