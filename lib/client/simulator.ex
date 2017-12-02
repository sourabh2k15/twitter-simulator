defmodule Simulator do
  @n_clients 10000
  @distibution_factor @n_clients / 100 |> round
  @zipf_coeff 1.04

  use GenServer
  
  def start_link() do
      IO.puts "simulator starting"
      IO.puts "loading tweets and hashtags"

      {:ok, tweetcorpus} = File.read "data/tweets.txt"
      {:ok, hashtag_corpus} = File.read "data/hashtags.txt"

      tweets = String.split(tweetcorpus, "\n")
      hashtags = String.split(hashtag_corpus, "\n")

      # creating more genservers to handle tweet creation process

      num_tweet_producers = @n_clients / @distibution_factor |> round
      
      tweet_producers = Enum.reduce(0..num_tweet_producers, %{}, fn i, acc -> 
        {:ok, tweet_producer_id} = TweetProducer.start_link(tweets, hashtags, @n_clients)
        Map.put(acc, i, tweet_producer_id)
      end)

      #compute zipf constant C
      c = Enum.reduce(1..@n_clients, 0, fn i, acc ->
        acc + (1 / :math.pow(i, @zipf_coeff)) 
      end)

      c = 1 / c

      initial_state = %{
        :tweet_producers => tweet_producers, 
        :hashtags        => hashtags, 
        :c               => c 
      }
     
      GenServer.start_link(__MODULE__, initial_state, name: {:global, :simulator})  
  end

  def init(state) do
    IO.puts "creating client processes"    

    server = GenServer.whereis({:global, :server})
    send(server, {:num_clients, @n_clients})
    
    chunks = Enum.chunk_every(1..@n_clients, 1000)
    
    chunked_tasks = Enum.map(chunks, fn chunk ->
      Task.async(fn ->
        
        Enum.map(chunk, fn rank -> 
          num_followers = @n_clients*(state[:c] / :math.pow(rank, @zipf_coeff)) |> round
          
          {:ok, clientid} = Client.start_link(%{
            "rank"          => rank, 
            "num_followers" => num_followers,
            "server"        => server,
            "n_clients"     => @n_clients
          })
          
          clientid
        end)

      end) 
    end)

    clients = Enum.reduce(chunked_tasks, [], fn chunk_task, acc ->
      acc ++ Task.await(chunk_task)
    end)
    
    IO.inspect length(clients)
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

  def handle_cast({:follower, follower, followed}, state) do
    GenServer.cast(Enum.at(state[:clients], follower-1), {:follow, followed})
    {:noreply, state}
  end

end