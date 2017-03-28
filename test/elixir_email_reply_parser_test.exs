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


  defp get_email(name) do
    {:ok, content} = File.read("test/emails/#{name}.txt")
    ElixirEmailReplyParser.read(content)
  end

end
