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
