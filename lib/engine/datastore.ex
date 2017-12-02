defmodule DataStore do
    def init(_) do
        state = %{
            :users          =>  %{},
            :followers      =>  %{},
            :tweets_by_user =>  %{},
            :tweets         =>  %{},
            :mentions       =>  %{},
            :live           =>  %{}
        }

        {:ok, state}
    end

    def handle_cast({:register, rank, pid}, state) do
        state = Kernel.put_in(state, [:users, rank], pid)
        state = Kernel.put_in(state, [:live, rank], true)

        {:noreply, state}
    end

    def handle_cast({:followers, rank, followers}, state) do
        state = Kernel.put_in(state, [:followers, rank], followers)
        
        {:noreply, state}
    end

    def handle_call({:store_tweet, tweetid, user, tweet}, _from, state) do
        record = %{
            :tweet => tweet,
            :origin => user, 
            :retweets => 0
        }
    
        {_, state} = Kernel.get_and_update_in(state, [:tweets_by_user, user], fn x -> 
            if x == nil do {x, [tweetid]} else {x, x ++ [tweetid]} end 
        end)
    
        state = Kernel.put_in(state, [:tweets, tweetid], record)

        
        {:reply, :ok, state}
    end

    def handle_cast({:store_retweet, tweetid}, state) do

        {_, state} = if state[:tweets][tweetid] do
            Kernel.get_and_update_in(state, [:tweets, tweetid, :retweets], fn x -> 
                {x, x + 1}
            end)
        else
            {nil, state}
        end

        IO.puts "#{state[:tweets][tweetid][:origin]}, #{state[:tweets][tweetid][:retweets]}"         

        {:noreply, state}
    end

    def handle_cast({:mentioned, mentioned, user, tweet, timestamp}, state) do
        record = %{
            :user => user, 
            :tweet => tweet,
            :timestamp => timestamp
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

    def handle_cast({:logout, rank}, state) do
        state = Kernel.put_in(state, [:live, rank], false)
        {:noreply, state}
    end

    def handle_call({:get_followers, rank}, _from, state) do
        followers = state[:followers][rank]
        {:reply, followers, state}
    end

    def handle_call({:get_user, rank}, _from, state) do
        {:reply, {state[:users][rank], state[:live][rank]}, state}
    end
end