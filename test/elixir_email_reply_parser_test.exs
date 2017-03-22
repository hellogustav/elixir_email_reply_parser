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
  end


  defp get_email(name) do
    {:ok, content} = File.read("test/emails/#{name}.txt")
    ElixirEmailReplyParser.read(content)
  end

end
