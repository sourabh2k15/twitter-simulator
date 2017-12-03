defmodule DataStore do
    def init(_) do
        state = %{
            :users          =>  %{},
            :followers      =>  %{},
            :tweets_by_user =>  %{},
            :tweets         =>  %{},
            :mentions       =>  %{},
            :live           =>  %{},
            :lastseen       =>  %{},
            :undelivered    =>  %{}
        }

        {:ok, state}
    end

    def handle_cast({:register, rank, pid}, state) do
        state = Kernel.put_in(state, [:users, rank], pid)
        state = Kernel.put_in(state, [:live, rank], true)
        state = Kernel.put_in(state, [:lastseen, rank], :os.system_time(:nano_seconds))
        
        {:noreply, state}
    end

    def handle_cast({:followers, rank, followers}, state) do
        state = Kernel.put_in(state, [:followers, rank], followers)
        
        {:noreply, state}
    end

    def handle_cast({:store_retweet, tweetid}, state) do

        {_, state} = if state[:tweets][tweetid] do
            Kernel.get_and_update_in(state, [:tweets, tweetid, :retweets], fn x -> 
                {x, x + 1}
            end)
        else
            {nil, state}
        end

        #IO.puts "#{state[:tweets][tweetid][:origin]}, #{tweetid}, #{state[:tweets][tweetid][:retweets]}"         

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

    def handle_cast({:logout, rank, lastseen}, state) do
        state = Kernel.put_in(state, [:live, rank], false)
        state = Kernel.put_in(state, [:lastseen, rank], lastseen)

        {:noreply, state}
    end

    def handle_cast({:undelivered, rank, tweetid, retweet, source}, state) do
        {_, state} = Kernel.get_and_update_in(state, [:undelivered, rank], fn x -> 
            if x == nil do 
                {nil, [%{:tweetid => tweetid, :source => source, :retweet => retweet}]}
            else
                {nil, x ++ [%{:tweetid => tweetid, :source => source, :retweet => retweet}]}
            end
        end)

        {:noreply, state}
    end

    def handle_cast({:logged_in, user, time}, state) do
        IO.puts "#{user} logged in, fetching undelivered"
        state = Kernel.put_in(state, [:lastseen, user], time)

        tweet_list = state[:undelivered][user]
       
        if tweet_list != nil do
            IO.puts "delivering undelivered"

            Enum.each(tweet_list, fn tweetrecord ->
                record = state[:tweets][tweetrecord[:tweetid]]
                source = tweetrecord["source"]
                retweet = tweetrecord["retweet"]

                tweet  = record[:tweet]
                origin = record[:origin]

                GenServer.cast(state[:users][user], {:subscribed_tweet, source, tweet, tweetrecord[:tweetid], retweet, origin})
            end)
        end

        state = Kernel.put_in(state, [:undelivered, user], nil)

        {:noreply, state}
    end

    def handle_cast({:query, user, query, source, byMention}, state) do
        if !byMention do
            tweet_list = state[:tweets_by_user][user]
            
            tweet_list = if tweet_list != nil do
                Enum.map(tweet_list, fn tweetid -> 
                    state[:tweets][tweetid]
                end)
            else
                tweet_list
            end
            
            GenServer.cast(source, {:query_result, query, tweet_list})
        else
            tweet_list = state[:mentions][user]

            tweet_list = if tweet_list != nil do
                Enum.map(tweet_list, fn tweetid -> 
                    state[:tweets][tweetid]
                end)
            else
                tweet_list
            end

            GenServer.cast(source, {:query_result, query, tweet_list})
        end
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

    def handle_call({:get_followers, rank}, _from, state) do
        followers = state[:followers][rank]
        {:reply, followers, state}
    end

    def handle_call({:get_user, rank}, _from, state) do
        {:reply, {state[:users][rank], state[:live][rank]}, state}
    end
end