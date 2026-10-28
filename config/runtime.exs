import Config
import Dotenvy

source!([".env", System.get_env()])

config :agent, model_name: env!("OLLAMA_MODEL_NAME", :string)
