defmodule DataStore do
    def init(_) do
        state = %{
            :users          =>  %{},
            :followers      =>  %{},
            :tweets_by_user =>  %{},
            :tweets         =>  %{},
            :mentions       =>  %{}
        }

        {:ok, state}
    end

    def handle_cast({:register, rank, pid}, state) do
        state = Kernel.put_in(state, [:users, rank], pid)
       
        {:noreply, state}
    end

    def handle_cast({:followers, rank, followers}, state) do
        state = Kernel.put_in(state, [:followers, rank], followers)
        
        {:noreply, state}
    end

    def handle_cast({:store_tweet, tweetid, user, tweet, timestamp, retweet, origin}, state) do
        record = %{
            :tweet => tweet,
            :retweet => retweet, 
            :origin => origin
        }

        {_, state} = Kernel.get_and_update_in(state, [:tweets_by_user, user], fn x -> 
            if x == nil do {x, [tweetid]} else {x, x ++ [tweetid]} end 
        end)

        state = Kernel.put_in(state, [:tweets, tweetid], record)

        {:noreply, state}
    end

    def handle_cast({:mentioned, mentioned, user, tweet, retweet, origin}, state) do
        record = %{
            :user => user, 
            :tweet => tweet,
            :retweet => retweet, 
            :origin => origin
        }

        {_, state} = Kernel.get_and_update_in(state, [:mentions, mentioned], fn x ->
            if x == nil do 
                {x, [record]}
            else 
                {x, x ++ [record]}
            end 
        end)

        {:noreply, state}
    end

    def handle_call({:get_followers, rank}, _from, state) do
        followers = state[:followers][rank]
        {:reply, followers, state}
    end

    def handle_call({:get_user_pid, rank}, _from, state) do
        {:reply, state[:users][rank], state}
    end
end