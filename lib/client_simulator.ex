defmodule ClientSimulator do
  @n_clients 10000
  use GenServer
  
  def start_link() do
      IO.puts "simulator starting"
      IO.puts "loading tweets"

      {:ok, tweetcorpus} = File.read "data/tweets.txt"
      {:ok, hashtag_corpus} = File.read "data/hashtags.txt"

      tweets = String.split(tweetcorpus, "\n")
      hashtags = String.split(hashtag_corpus, "\n")

      GenServer.start_link(__MODULE__, %{ :tweets => tweets, :hashtags => hashtags }, name: {:global, :simulator})  
  end

  def init(state) do
    IO.puts "creating client processes"
    server = GenServer.whereis({:global, :server})

    send(server, {:n_clients, @n_clients})
    
    clients = Enum.reduce(1..@n_clients, [], fn rank,t_clients -> 
        num_followers = (@n_clients - 1) / rank |> round

        {:ok, clientid} = Client.start_link(%{
          "rank" => rank, 
          "num_followers" => num_followers,
          "server" => server,
          "n_clients" => @n_clients
        })

        t_clients ++ [clientid]
    end)
    
    state = Map.put(state, :clients, clients)
    state = Map.put(state, :tweet_db_size, length(state[:tweets]))
    state = Map.put(state, :hashtag_db_size, length(state[:hashtags]))

    {:ok, state}
  end

  def handle_cast({:start_tweeting}, state) do
    IO.puts "network will start tweeting now!"
    clients = state[:clients]

    Enum.each(1..@n_clients, fn rank -> 
        Kernel.send(Enum.at(clients, rank-1), {:tweet})
    end)

    {:noreply, state}
  end

  def handle_cast({:create_tweet, client_id, timestamp}, state) do
    
    spawn(fn ->
      tweet_index = Util.generate(0, state[:tweet_db_size]-1)
      
      tweettokens = String.split(Enum.at(state[:tweets], tweet_index), " ")
      tweettokens = tweettokens ++ Enum.take_random(state[:hashtags], 5)
      tweettokens = tweettokens ++ Enum.take_random(1..@n_clients, 2)
  
      tweet = Enum.join(tweettokens, " ")
  
      GenServer.cast(Enum.at(state[:clients], client_id - 1), {:tweet_created, tweet, timestamp})       
    end)

    {:noreply, state}
  end

end