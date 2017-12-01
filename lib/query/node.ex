defmodule QueryNode do
    @timeout 10000

    def start_link(state) do
        GenServer.start_link(__MODULE__, state) 
    end

    def init(state) do
        send(self(), {:generateQuery})
        {:ok, state}
    end

    def handle_cast({:result, query, result}, state) do
        IO.puts "query: #{query}, result: #{inspect result}"
        {:noreply, state}
    end

    def handle_info({:generateQuery}, state) do
        user = Util.rand(1, state[:n_clients])
        hashtag = Enum.at(state[:hashtags], Util.rand(0, length(state[:hashtags])))
        byMentioned = Enum.random([true, false])
        
        query = hashtag

        GenServer.cast({:global, :server}, {:query, query, self()})
        Process.send_after(self(), {:generateQuery}, Util.rand(1, @timeout))

        {:noreply, state}
    end
end