defmodule HashtagStore do
    def init(workers) do
        state = %{
            :workers => workers,
            :data => %{}
        }
        {:ok, state}
    end

    def handle_cast({:link_tweet, hashtag, user, tweet}, state) do
        record = %{
            :user => user,
            :tweet => tweet
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
end