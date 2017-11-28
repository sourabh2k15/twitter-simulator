defmodule Processor do
    def init(_) do
        state = %{}
        {:ok, state}
    end

    def handle_cast({:initialize, workers, hashtag_stores, my_datastore, df}, state) do
        state = Map.put(state, :workers, workers)
        state = Map.put(state, :hashtag_stores, hashtag_stores)
        state = Map.put(state, :my_datastore, my_datastore)
        state = Map.put(state, :df, df)

        {:noreply, state}
    end

    def handle_cast({:tweet, user, tweet, timestamp}, state) do
        IO.puts "client #{user} tweeted: #{tweet} with timestamp #{timestamp}"
        worker_index =  user / state[:df] |> round 
    
        followers = GenServer.call(state[:workers][worker_index][:datastore], {:get_followers, user})

        Enum.each(followers, fn follower -> 
            worker_index =  follower / state[:df] |> round
            GenServer.cast(state[:workers][worker_index][:processor], {:deliver_tweet, follower, user, tweet, timestamp})
        end)

        tweet_data = process_tweet(user, tweet, timestamp)
        
        ## Updating in-memory databases 

        ## update own db to store tweet
        GenServer.cast(state[:my_datastore], {:store_tweet, tweet_data[:tweet_id], user, tweet, timestamp})
        
        ## update hashtag db to link this tweet
        Enum.each(tweet_data[:hashtags], fn hashtag ->
            hashtag = String.slice(hashtag, 1, String.length(hashtag))
            hashtag_store_idx = String.at(hashtag, 0)
       
            GenServer.cast(state[:hashtag_stores][hashtag_store_idx], {:link_tweet, hashtag, user, tweet})         
        end)

        Enum.each(tweet_data[:mentions], fn mention -> 
            mention = String.slice(mention, 1, String.length(mention))
            mention = String.to_integer(mention)

            worker_index = mention / state[:df] |> round
            GenServer.cast(state[:workers][worker_index][:datastore], {:mentioned, mention, user, tweet})    
        end)

        {:noreply, state}    
    end

    # TODO : handle sleeping nodes
    def handle_cast({:deliver_tweet, user, origin, tweet, timestamp}, state) do
        user_pid = GenServer.call(state[:my_datastore], {:get_user_pid, user})
        
        GenServer.cast(user_pid, {:subscribed_tweet, origin, tweet, timestamp})
        {:noreply, state}
    end

    def process_tweet(user, tweet, timestamp) do
        tokens = String.split(tweet)
    
        mentions = Enum.filter(tokens, fn token ->
            String.at(token, 0) == "@"  
        end)

        hashtags = Enum.filter(tokens, fn token ->
            String.at(token, 0) == "#"    
        end)

        tweet_id = Integer.to_string(user) <> "*" <> Integer.to_string(timestamp)
    
        tweet_data = %{
            :tweet_id => tweet_id, 
            :hashtags => hashtags, 
            :mentions => mentions, 
            :tweet => tweet
        }
    end
end