defmodule Nodes do
  defstruct [:id, :pid, leader: {:no_id, :no_leader}]
  @default_timeout Application.get_env(:nodes, :default_timeout, 500)
  @max_timeout_multiplier Application.get_env(:nodes, :max_timeout_multiplier, 4)
  @table_name Application.get_env(:nodes, :table_name, :state)

  @doc """
   A function, which creates a new node with given unique ID. Returns {:ok, {node_id,process_id}} or {:error, reason}
  """
  @spec new_node(integer()) :: {:ok, tuple()} | {:error, String.t()}
  def new_node(id) when is_integer(id) do
    new_state = %Nodes{id: id}

    if :ets.whereis(@table_name) == :undefined do
      :ets.new(@table_name, [:named_table, :public, :set])
    end

    with false <- :ets.member(@table_name, id),
         pid <- spawn(fn -> loop(new_state) end),
         true <- :ets.insert_new(@table_name, {id, %{new_state | pid: pid}}),
         {:start_election} <- send(pid, {:start_election}) do
      {:ok, {id, pid}}
    else
      true ->
        {:error, "The given ID: #{id} already exists!"}

      rest ->
        {:error, "Unknown error reason : #{inspect(rest)}"}
    end
  end

  @doc """
    A function that returns the state of a given node. Either returns node state or {:error, message}
  """
  @spec get_state(integer()) :: Nodes.t() | {:error, String.t()}
  def get_state(id) when is_integer(id) do
    case :ets.lookup(@table_name, id) do
      [{^id, node_state}] ->
        node_state

      err ->
        {:error,
         "#{__MODULE__}: ID: #{inspect(id)} is not found in the ETS table: #{inspect(err)}"}
    end
  end

  @doc """
    A function that simply terminates the given node by its id.
  """
  @spec kill_node(pid() | integer()) :: boolean()
  def kill_node(id) when is_integer(id) do
    %Nodes{} = node_state = get_state(id)
    kill_node(node_state.pid)
  end

  @doc """
    A function which simply terminates given process by its process id.
  """
  def kill_node(pid) when is_pid(pid) do
    Process.exit(pid, :kill)
  end

  defp loop(%Nodes{pid: nil} = state) do
    loop(%{state | pid: self()})
  end

  defp loop(%Nodes{leader: {id, leader}} = state) do
    receive do
      ### Internal node get_state, in case the ETS table is outdated\out of sync\terminated\not responding
      {:get_state, from} when is_pid(from) ->
        send(from, {state.pid, state})
        loop(state)

      ### BACK-END
      {:alive?, from} when is_pid(from) ->
        list_of_states = :ets.foldr(fn {_k, v}, acc -> [v | acc] end, [], @table_name)

        if biggest_id?(state.id, list_of_states) do
          Enum.each(list_of_states, fn node ->
            update_record(node.id, %{node | leader: {state.id, state.pid}})
            send(node.pid, {:iamtheking, {state.id, state.pid}})
          end)

          loop(%{state | leader: {state.id, state.pid}})
        else
          send(from, {:finethanks, state.pid})
          send(state.pid, {:start_election})
          loop(state)
        end

      {:finethanks, _from} ->
        receive do
          {:iamtheking, {id, from}} ->
            updated_state = %{state | leader: {id, from}}
            update_record(state.id, updated_state)
            loop(updated_state)
        after
          @default_timeout ->
            send(state.pid, {:start_election})
            loop(state)
        end

      {:iamtheking, {id, from}} when is_pid(from) ->
        updated_state = %{state | leader: {id, from}}
        update_record(state.id, updated_state)
        send(from, {:ping, state.pid})
        loop(updated_state)

      {:pong, ^leader} ->
        send(leader, {:ping, state.pid})
        loop(state)

      {:ping, from} when from != self() ->
        send(from, {:pong, state.pid})
        loop(state)

      {:start_election} ->
        list_of_states = :ets.foldr(fn {_k, v}, acc -> [v | acc] end, [], @table_name)

        if biggest_id?(state.id, list_of_states) do
          broadcast({:iamtheking, {state.id, state.pid}}, list_of_states)
          updated_state = %{state | leader: {state.id, state.pid}}
          update_record(state.id, updated_state)
          loop(updated_state)
        else
          recipients = Enum.filter(list_of_states, fn node -> node.id > state.id end)
          broadcast({:alive?, state.pid}, recipients)
        end

        loop(state)
    after
      @default_timeout *
          @max_timeout_multiplier ->
        send(state.pid, {:start_election})
        updated_state = %{state | leader: {:no_id, :no_leader}}
        update_record(state.id, updated_state)

        if !Process.alive?(leader) do
          delete_record(id)
        end

        loop(updated_state)
    end
  end

  defp delete_record(key) do
    :ets.delete(@table_name, key)
  end

  defp broadcast(msg, nodes) when is_list(nodes) and is_tuple(msg) do
    Enum.each(nodes, fn node -> send(node.pid, msg) end)
  end

  defp update_record(key, record) when is_integer(key) do
    :ets.insert(@table_name, {key, record})
  end

  defp biggest_id?(id, list_nodes) when is_integer(id) and is_list(list_nodes) do
    all_ids =
      for node <- list_nodes do
        node.id
      end

    Enum.max(all_ids) == id
  end
end
