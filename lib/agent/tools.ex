defmodule Agent.Tools do
  def definitions do
    [
      %{
        type: "function",
        function: %{
          name: "read_file",
          description: "Read the contents of a file at the given path",
          parameters: %{
            type: "object",
            properties: %{
              path: %{type: "string", description: "The path of the file to read"}
            },
            required: ["path"]
          }
        }
      },
      %{
        type: "function",
        function: %{
          name: "execute_command",
          description: "Run a shell command on the machine",
          parameters: %{
            type: "object",
            properties: %{
              command: %{type: "string", description: "The shell command to execute"}
            },
            required: ["command"]
          }
        }
      }
    ]
  end

  def execute("read_file", %{"path" => path}) do
    case File.read(path) do
      {:ok, contents} -> contents
      {:error, reason} -> "Error reading file: #{inspect(reason)}"
    end
  end

  def execute("execute_command", %{"command" => command}) do
    {output, exit_code} = System.shell(command, stderr_to_stdout: true)

    """
    Exit code: #{exit_code}
    #{output}
    """
  end

  def execute(tool, args) when tool in ["read_file", "execute_command"] do
    "Error: Invalid arguments for #{tool}: #{inspect(args)}"
  end

  def execute(unknown_tool, _args), do: "Error: Unknown tool #{unknown_tool}"
end
