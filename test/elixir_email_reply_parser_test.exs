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


  defp get_email(name) do
    {:ok, content} = File.read("test/emails/#{name}.txt")
    ElixirEmailReplyParser.read(content)
  end

end
