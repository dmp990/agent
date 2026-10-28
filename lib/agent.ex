defmodule Agent.CLI do
  @system_prompt """
  You are a helpful assistant that can execute tools. You explain concepts in simple terms and are honest about what you know and don't know. You are also a good programmer and can write code in multiple programming languages.
  """

  alias Agent.Tools
  alias Agent.LLM

  def main(args) do
    args
    |> OptionParser.parse(
      switches: [help: :boolean, system: :string],
      aliases: [h: :help, s: :system]
    )
    |> run()
  end

  defp run({[help: true], _argv, _errors}) do
    IO.puts("Usage: mix agent [options]")
    IO.puts("Options:")
    IO.puts("  --help, -h             Show this help message")
    IO.puts("  --system, -s <prompt>  Set the system prompt")
  end

  defp run({opts, argv, _errors}) do
    system_prompt =
      case opts[:system] do
        nil ->
          @system_prompt

        first_word ->
          Enum.join([first_word | argv], " ")
      end

    loop([%{role: "system", content: system_prompt}])
  end

  defp loop(chat_history) do
    case IO.gets("> ") |> String.trim() do
      opt when opt in ["exit", "quit", "q"] ->
        IO.puts("Exiting...")
        :ok

      input ->
        case send_to_llm(chat_history ++ [%{role: "user", content: input}]) do
          {:ok, content, updated_history} ->
            IO.puts(content)

            updated_history
            |> debug()
            |> loop()

          {:error, reason} ->
            IO.puts("Error: #{inspect(reason)}")
            loop(chat_history)
        end
    end
  end

  defp debug(message, file_name \\ "debug.txt", append \\ false) do
    modes = if append, do: [:append], else: []
    content = inspect(message, pretty: true, limit: :infinity) <> "\n"
    File.write!(file_name, content, modes)
    message
  end

  defp send_to_llm(messages) do
    case LLM.chat(messages, Tools.definitions()) do
      # Tool call
      {:ok, %{"tool_calls" => [_ | _] = tool_calls} = message} ->
        # Run each tool
        new_messages =
          Enum.map(tool_calls, fn tool_call -> run_tool(tool_call) end)

        # Recurse!
        send_to_llm(messages ++ [message | new_messages])

      {:ok, %{"content" => content} = message} ->
        {:ok, content, messages ++ [message]}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp run_tool(%{"function" => %{"name" => name, "arguments" => args}} = call) do
    IO.puts("Executing tool: #{name}")
    result = Tools.execute(name, args)

    %{role: "tool", tool_call_id: Map.get(call, "id"), content: to_string(result)}
  end
end
