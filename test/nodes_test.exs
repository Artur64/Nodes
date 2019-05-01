defmodule NodesTest do
  use ExUnit.Case

  test "Basic Interaction with nodes" do
    # Creating new node with id 1
    {:ok, {1, _pid}} = Nodes.new_node(1)
    # Checking the creation of the node with same id
    assert {:error, _} = Nodes.new_node(1)
    # Checking the state of node 1
    assert %Nodes{id: 1} = Nodes.get_state(1)
    # Creating new node with id -1
    {:ok, {-1, _}} = Nodes.new_node(-1)
    # We should wait a bit for the election
    Process.sleep(10)

    # Matching the state of node with id -1, the result of the election should be a node with higher id
    assert %Nodes{leader: {1, pid}} = Nodes.get_state(-1)
    {:ok, {100, _pid1}} = Nodes.new_node(100)
    # We should wait a bit for the election
    Process.sleep(10)

    # Matching the state of node with id 1, the result of the election should be a node with higher id (100)
    assert %Nodes{id: 1, leader: {100, pid1}} = Nodes.get_state(1)

    # Matching the state of node with id -1, the result of the election should be a node with higher id (100)
    assert %Nodes{id: -1, leader: {100, pid1}} = Nodes.get_state(-1)
    # Checking the possibilty of killing node 100
    assert true = Nodes.kill_node(100)

    # Assuming that node 100 is dead, we should wait for 4xT, so the current leader will be considered dead.
    Process.sleep(
      Application.get_env(:nodes, :default_timeout, 500) *
        Application.get_env(:nodes, :max_timeout_multiplier, 4) + 1
    )

    # Checking the termination of node 100
    assert {:error, _} = Nodes.get_state(100)
    # We should wait a bit for the election
    Process.sleep(10)

    # Matching the state of node with id 1, the result of the election should be a node with higher id (1)
    assert %Nodes{id: 1, leader: {1, _}} = Nodes.get_state(1)

    # Matching the state of node with id -1, the result of the election should be a node with higher id (1)
    assert %Nodes{id: -1, leader: {1, _}} = Nodes.get_state(-1)
  end
end
