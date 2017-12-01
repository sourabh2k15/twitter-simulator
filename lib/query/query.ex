defmodule Query do
    def start_link do 
        IO.puts "query node started"
        
        GenServer.start_link(__MODULE__, :ok, name: {:global, :queryNode})
    end

    def init(:ok) do
        IO.puts "initiated"
        GenServer.cast({:global, :simulator}, {:get_settings})
        
        {:ok, %{}}
    end

    def handle_cast({:receive_settings, settings}, state) do
        state = Map.put(state, :n_clients, settings[:n_clients])
        state = Map.put(state, :hashtags, settings[:hashtags])

        Enum.each(1..state[:n_clients], fn _ -> 
            QueryNode.start_link(state)
        end)

        {:noreply, state}
    end
end