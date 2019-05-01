# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config
config :nodes, default_timeout: 500, max_timeout_multiplier: 4, table_name: :state
