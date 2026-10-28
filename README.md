# Agent

This is an Elixir project that demonstrates how to create a simple agent using a language model as its brain. I built this to get more familiar with the Elixir language and functional programming style.

In order to run this project, you will need to have Elixir installed on your machine. You can find installation instructions on the official Elixir website: <https://elixir-lang.org/install.html>

Then `clone` this repository and run the following commands in your terminal:

```bash
mix deps.get
mix agent
```

## Features

- Interactive CLI chat loop with persistent conversation history (for the duration of the session)
- Local LLM integration via Ollama
- Custom system prompt support (`--system` / `-s`)
- Tool calling with recursive execution:
  - `read_file`: Read the contents of a file
  - `execute_command`: Run shell commands on the machine
