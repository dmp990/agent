defmodule Agent.CLI do
  @system_prompt """
  You are a helpful assitant that can execute tools. You explain concepts in simple terms and are honest about what you know and don't know. You are also a good programmer and can write code in multiple programming languages.
  """

  alias Agent.Tools
  alias Agent.LLM

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

        case send_to_llm(chat_history) do
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
          Enum.reduce(tool_calls, messages ++ [message], fn tool_call, acc ->
            tool_id = tool_call["id"]
            name = tool_call["function"]["name"]
            args = tool_call["function"]["arguments"]

            IO.puts("Executing tool: #{name}")
            result = Tools.execute(name, args)

            acc ++ [%{role: "tool", tool_call_id: tool_id, content: to_string(result)}]
          end)

        # Recurse!
        send_to_llm(new_messages)

      {:ok, %{"content" => content} = message} ->
        {:ok, content, messages ++ [message]}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
