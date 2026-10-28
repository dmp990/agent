defmodule Agent.CLI do
  @system_prompt """
  You are a helpful assitant that can execute tools. You explain concepts in simple terms and are honest about what you know and don't know. You are also a good programmer and can write code in multiple programming languages.
  """

  alias Agent.Tools

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

  defp debug(message, file_name \\ "debug.txt", append \\ false) do
    modes = if append, do: [:append], else: []
    content = inspect(message, pretty: true, limit: :infinity) <> "\n"
    File.write!(file_name, content, modes)
    message
  end

  defp send_to_llm(messages) do
    model_name = Application.get_env(:agent, :model_name)

    {:ok, response} =
      Req.post("http://localhost:11434/api/chat",
        json: %{
          model: model_name,
          stream: false,
          messages: messages,
          tools: Tools.definitions()
        }
      )

    tools = get_in(response.body, ["message", "tool_calls"]) || []

    if Enum.any?(tools) do
      messages_with_call = messages ++ [response.body["message"]]

      # Call tools
      new_messages =
        Enum.reduce(tools, messages_with_call, fn tool_call, acc ->
          tool_id = tool_call["id"]
          name = tool_call["function"]["name"]
          args = tool_call["function"]["arguments"]

          IO.puts("Executing tool: #{name}")
          result = Tools.execute(name, args)

          acc ++ [%{role: "tool", tool_call_id: tool_id, content: to_string(result)}]
        end)

      # Recurse!
      send_to_llm(new_messages)
    else
      message_content = response.body["message"]["content"]
      IO.puts(message_content)
      message_content
    end
  end
end
