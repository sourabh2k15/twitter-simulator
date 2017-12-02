defmodule Processor do
    def init(_) do
        state = %{}
        {:ok, state}
    end

    def handle_cast({:initialize, workers, hashtag_stores, my_datastore}, state) do
        state = Map.put(state, :workers, workers)
        state = Map.put(state, :hashtag_stores, hashtag_stores)
        state = Map.put(state, :my_datastore, my_datastore)

        {:noreply, state}
    end

    def handle_cast({:tweet, user, tweet, timestamp, retweet, origin}, state) do
        tweet_data = process_tweet(user, tweet, timestamp)
       
        # store tweets into in-memory databases ( maps )
        if !retweet do
            GenServer.call(state[:my_datastore], {:store_tweet, tweet_data[:tweet_id], user, tweet})
        
            Enum.each(tweet_data[:hashtags], fn hashtag ->
                hashtag_store_idx = String.at(hashtag, 1)
       
                GenServer.cast(state[:hashtag_stores][hashtag_store_idx], {:link_tweet, hashtag, user, tweet, retweet, origin})         
            end)

            Enum.each(tweet_data[:mentions], fn mention -> 
                mention = String.slice(mention, 1, String.length(mention))
                mention = String.to_integer(mention)

                worker_index = Util.log2(mention)
                GenServer.cast(state[:workers][worker_index][:datastore], {:mentioned, mention, user, tweet, timestamp})    
            end)
        else
            #if retweet update count in original tweet record
            origin_index = Util.log2(origin)
            GenServer.cast(state[:workers][origin_index][:processor], {:retweet, tweet_data[:tweet_id]})
        end

        
        # Forward tweet / retweet to all followers
        
        followers = GenServer.call(state[:my_datastore], {:get_followers, user})
        chunks = Enum.chunk_every(followers, 1000)

        Enum.each(followers, fn follower -> 
            worker_index =  Util.log2(follower)
            GenServer.cast(state[:workers][worker_index][:processor], {:deliver_tweet, follower, user, tweet, timestamp, retweet, origin})
        end)

        {:noreply, state}    
    end

    def handle_cast({:retweet, tweetid}, state) do
        GenServer.cast(state[:my_datastore], {:store_retweet, tweetid})
        {:noreply, state}
    end
    

    def handle_cast({:deliver_tweet, user, source, tweet, timestamp, retweet, origin}, state) do
        {user_pid, isAlive} = GenServer.call(state[:my_datastore], {:get_user, user})
        
        if isAlive do 
            GenServer.cast(user_pid, {:subscribed_tweet, source, tweet, timestamp, retweet, origin})
        else 
             IO.puts "user not live, tweet has to be delivered when user logins again"
        end

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
    
        tweet_data = %{
            :tweet_id => timestamp, 
            :hashtags => hashtags, 
            :mentions => mentions, 
            :tweet => tweet
        }
    end
end