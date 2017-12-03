defmodule HashtagStore do
    def init(workers) do
        state = %{
            :workers => workers,
            :data => %{}
        }
        {:ok, state}
    end

    def handle_cast({:link_tweet, hashtag, user, tweet, retweet, origin}, state) do
        record = %{
            :user => user,
            :tweet => tweet,
            :retweet => retweet, 
            :origin => origin
        }

        {_, state} = Kernel.get_and_update_in(state, [:data, hashtag], fn x ->
            if x == nil do
                {x, [record]}
            else 
                {x, x ++ [record]}
            end 
        end)

        {:noreply, state}
    end

    def handle_cast({:query, query, source}, state) do
        result = state[:data][query]
        GenServer.cast(source, {:query_result, query, result})
        
        {:noreply, state}
    end
end