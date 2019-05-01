# Elixir Nodes

 Elixir Nodes task implementation
## Prerequisities
 [Erlang OTP 21](http://erlang.org/doc/installation_guide/INSTALL.html)+ and [Elixir 1.8.1](https://elixir-lang.org/install.html)+

## Configure it: 

The application is configurable, the possible configurations are: 

- `default_timeout` - Timeout in ms, default value is `500`.
- `max_timeout_multiplier` - Timeout multiplier, default value is `4`.
- `table_name` - The name of ETS table, default name is `:state`.

## Usage: 
 - `Nodes.new_node 1` - takes integers as IDs. Tries to create a new node. Returns `elixir{:ok, {node_id, node_pid}}` or `{:error,reason}`.
 - `Nodes.get_state 1` - takes given `ID` and if the given node exists, returns the `state` of the node, or `{:error, reason}`.
 - `Nodes.get_all_states` - takes no arguments. Returns `states` of all nodes in a `list`. If there are no nodes, returns an `empty list`.
 - `Nodes.kill_node 1` - tries to terminate the node by given `ID`. Returns either `true` if the node was killed, or `false` if not (possibly because it was killed by someone else or just did not exist).
