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
        
        {:noreply, state}    
    end

    def handle_cast({:deliver_tweet, user, origin, tweet, timestamp}, state) do
        user_pid = GenServer.call(state[:my_datastore], {:get_user_pid, user})
        
        GenServer.cast(user_pid, {:subscribed_tweet, origin, tweet, timestamp})
        {:noreply, state}
    end

    '''
    PROCESS TWEETS 

    @param sender, rank of client who tweeted
    @param tweet , tweet string
  '''

  def processTweet(tweet) do
    tokens = String.split(tweet)
    
    mentions = Enum.filter(tokens, fn token ->
      String.at(token, 0) == "@"  
    end)

    hashtags = Enum.filter(tokens, fn token ->
      String.at(token, 0) == "#"    
    end)

    tweet_metadata = %{:hashtags => hashtags, :mentions => mentions, :tweet => tweet}
  end
end