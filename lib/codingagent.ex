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
      chat_history = chat_history ++ [%{role: "user", content: input}]

      response =
        chat_history
        |> send_to_llm()

      # Continue the loop
      (chat_history ++ [%{role: "assistant", content: response}])
      |> debug()
      |> loop()
    end
  end

  defp debug(chat_messages) do
    File.write!("debug.txt", inspect(chat_messages, pretty: true, limit: :infinity))
    chat_messages
  end

  defp send_to_llm(messages) do
    model_name = Application.get_env(:codingagent, :model_name)

    {:ok, agent_pid} = Agent.start_link(fn -> [] end)
    {:ok, buffer_pid} = Agent.start_link(fn -> "" end)

    Req.post!("http://localhost:11434/api/chat",
      json: %{model: model_name, stream: true, messages: messages},
      into: fn {:data, chunk}, {req, resp} ->
        buffer = Agent.get(buffer_pid, & &1) <> chunk
        lines = String.split(buffer, "\n")

        {complete_lines, [remaining]} = Enum.split(lines, -1)
        Agent.update(buffer_pid, fn _ -> remaining end)

        Enum.each(complete_lines, fn line ->
          case Jason.decode(line) do
            {:ok, %{"message" => %{"content" => content}}} ->
              IO.write(content)
              Agent.update(agent_pid, fn lst -> [content | lst] end)

            _ ->
              :ok
          end
        end)

        {:cont, {req, resp}}
      end
    )

    # Add a new line after the streaming output for better readability
    IO.puts("")

    full_content = agent_pid |> Agent.get(& &1) |> Enum.reverse() |> IO.iodata_to_binary()

    Agent.stop(agent_pid)
    Agent.stop(buffer_pid)

    full_content
  end
end
