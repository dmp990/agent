defmodule Codingagent.CLI do
  @system_prompt """
  You are an expert software engineer assistant.
  """

  def main(args) do
    {opts, argv, _errors} =
      OptionParser.parse(args,
        switches: [help: :boolean, system: :string],
        aliases: [h: :help, s: :system]
      )

    if opts[:help] do
      IO.puts("Usage: mix agent [options]")
      IO.puts("Options:")
      IO.puts("  --help, -h             Show this help message")
      IO.puts("  --system, -s <prompt>  Set the system prompt")
    else
      system_prompt =
        case opts[:system] do
          nil ->
            @system_prompt

          first_word ->
            Enum.join([first_word | argv], " ")
        end

      loop([%{role: "system", content: system_prompt}])
    end
  end

  defp loop(chat_history) do
    case IO.gets("> ") |> String.trim() do
      "exit" ->
        IO.puts("Exiting...")
        :ok

      input ->
        chat_history = chat_history ++ [%{role: "user", content: input}]

        response =
          chat_history
          |> send_to_llm()

        # Continue the loop
        chat_history
        |> Kernel.++([%{role: "assistant", content: response}])
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
