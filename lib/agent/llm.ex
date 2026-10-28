defmodule Agent.LLM do
  @ollama_url "http://localhost:11434/api/chat"

  alias Agent.Tools

  def chat(messages, tools \\ Tools.definitions()) do
    payload = %{
      model: model_name(),
      stream: false,
      messages: messages,
      tools: tools
    }

    case Req.post(@ollama_url, json: payload) do
      {:ok, %Req.Response{status: 200, body: %{"message" => message}}} ->
        {:ok, message}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, exception} ->
        {:error, {:req_failed, Exception.message(exception)}}
    end
  end

  defp model_name(), do: Application.fetch_env!(:agent, :model_name)

  def send_request(prompt) do
    {:ok, "Response from LLM for prompt: #{prompt}"}
  end
end
