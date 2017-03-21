defmodule ElixirEmailReplyParserTest do
  use ExUnit.Case
  doctest ElixirEmailReplyParser

  test "the truth" do
    assert 1 + 1 == 2
  end

  test "test_simple_body" do
    {:ok, message} = get_email('email_1_1')
  end


  defp get_email(name) do
    {:ok, content} = File.open("test/emails/#{name}.txt")
    ElixirEmailReplyParser.read(content)
  end

end
