defmodule TweetProducer do
    def start_link(tweets, hashtags, n_clients) do
        initial_state = %{
            :tweets           => tweets, 
            :hashtags         => hashtags,
            :tweets_db_size   => length(tweets),
            :hashtags_db_size => length(hashtags),
            :n_clients        => n_clients
        }

        GenServer.start_link(__MODULE__, initial_state)
    end

    def init(state) do
        {:ok, state}
    end

    def handle_cast({:create_tweet, destination}, state) do
        tweet_index = Util.generate(0, state[:tweets_db_size]-1)
        hashtag_index = Util.generate(0, state[:hashtags_db_size]-1)
        mention_index = Util.generate(1, state[:n_clients])
      
        tweettokens = String.split(Enum.at(state[:tweets], tweet_index), " ")
        tweettokens = tweettokens ++ [Enum.at(state[:hashtags], hashtag_index)]
        tweettokens = tweettokens ++ ["@"<>Integer.to_string(mention_index)]
        
        tweet = Enum.join(tweettokens, " ")
        timestamp = :os.system_time(:micro_seconds)

        GenServer.cast(destination, {:tweet_created, tweet, timestamp})

        {:noreply, state}
    end
end