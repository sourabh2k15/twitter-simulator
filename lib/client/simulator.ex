defmodule Simulator do
  @n_clients 10000
  @distibution_factor @n_clients / 100 |> round

  use GenServer
  
  def start_link() do
      IO.puts "simulator starting"
      IO.puts "loading tweets and hashtags"

      {:ok, tweetcorpus} = File.read "data/tweets.txt"
      {:ok, hashtag_corpus} = File.read "data/hashtags.txt"

      tweets = String.split(tweetcorpus, "\n")
      hashtags = String.split(hashtag_corpus, "\n")

      # creating more genservers to handle tweet creation process

      num_tweet_producers = if @distibution_factor > 0 do
         @n_clients / @distibution_factor |> round
      else 
         1
      end
      
      tweet_producers = Enum.reduce(0..num_tweet_producers, %{}, fn i, acc -> 
        {:ok, tweet_producer_id} = TweetProducer.start_link(tweets, hashtags, @n_clients)
        Map.put(acc, i, tweet_producer_id)
      end)

      initial_state = %{
        :tweet_producers => tweet_producers, 
        :hashtags        => hashtags 
      }
     
      GenServer.start_link(__MODULE__, initial_state, name: {:global, :simulator})  
  end

  def init(state) do
    IO.puts "creating client processes"    

    server = GenServer.whereis({:global, :server})
    send(server, {:num_clients, @n_clients})
    
    clients = Enum.reduce(1..@n_clients, [], fn rank, t_clients -> 
        num_followers = (@n_clients - 1) / rank |> round

        {:ok, clientid} = Client.start_link(%{
            "rank"          => rank, 
            "num_followers" => num_followers,
            "server"        => server,
            "n_clients"     => @n_clients
          })

        t_clients ++ [clientid]
    end)
    
    state = Map.put(state, :clients, clients)
    {:ok, state}
  end

  def handle_cast({:start_tweeting}, state) do
    IO.puts "network will start tweeting now!"
    clients = state[:clients]

    Enum.each(1..@n_clients, fn rank -> 
        Kernel.send(Enum.at(clients, rank-1), {:start_tweeting})
    end)

    {:noreply, state}
  end

  def handle_cast({:create_tweet, rank, pid}, state) do   
    producer_index = rank / @distibution_factor |> round
    GenServer.cast(state[:tweet_producers][producer_index], {:create_tweet, pid})
 
    {:noreply, state}
  end

  def handle_cast({:get_settings}, state) do
    settings = %{
      :n_clients => @n_clients,
      :hashtags  => state[:hashtags]  
    }

    GenServer.cast({:global, :queryNode}, {:receive_settings, settings})
    {:noreply, state}
  end

end