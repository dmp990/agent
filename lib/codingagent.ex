defmodule Codingagent.CLI do
  def main(_args) do
    loop()
  end

  defp loop(chat_history \\ []) do
    input = IO.gets("> ")

    if String.trim(input) == "exit" do
      IO.puts("Exiting...")
      :ok
    else
      chat_history =
        [%{role: "user", content: input} | chat_history]
        |> Enum.reverse()

      response =
        chat_history
        |> send_to_llm()

      # Print the response
      IO.puts(response)

      # Continue the loop
      [%{role: "assistant", content: response} | chat_history] |> Enum.reverse() |> loop()
    end
  end

  defp send_to_llm(messages) do
    model_name = Application.get_env(:codingagent, :model_name)

    response =
      Req.post!("http://localhost:11434/api/chat",
        json: %{model: model_name, stream: false, messages: messages}
      )

    response.body["message"]["content"]
  end
end
