defmodule TweetProducer do
    def createTweet(tweets, hashtags, n_clients) do
        tweet_index = Util.rand(0, length(tweets)-1)
        is_hashtag_present = Enum.random([nil,nil,nil,nil,0])
        is_mention_present = Enum.random([nil,nil,nil,nil,0, 0, 0])
        
        tweettokens = String.split(Enum.at(tweets, tweet_index), " ")
        
        tweettokens = if is_hashtag_present do 
            hashtag_index = Util.rand(0, length(hashtags)-1)
            tweettokens ++ [Enum.at(hashtags, hashtag_index)]
        else 
            tweettokens
        end

        tweettokens = if is_mention_present do 
            mention_index = Util.rand(1, n_clients)
            tweettokens ++ ["@"<>Integer.to_string(mention_index)]
        else
            tweettokens
        end

        tweet = Enum.join(tweettokens, " ")
        timestamp = :os.system_time(:nano_seconds)

        {tweet, timestamp}
    end
end