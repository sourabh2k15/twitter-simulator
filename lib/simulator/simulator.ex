defmodule Simulator do
  @n_clients 10000
  @zipf_coeff 1.07

  use GenServer
  
  def start_link() do
      IO.puts "simulator starting"
      IO.puts "loading tweets and hashtags"

      {:ok, tweetcorpus} = File.read "data/tweets.txt"
      {:ok, hashtag_corpus} = File.read "data/hashtags.txt"

      tweets = String.split(tweetcorpus, "\n")
      hashtags = String.split(hashtag_corpus, "\n")

      #compute zipf constant C
      c = Enum.reduce(1..@n_clients, 0, fn i, acc ->
        acc + (1 / :math.pow(i, @zipf_coeff)) 
      end)

      c = 1 / c

      initial_state = %{
        :tweets          => tweets, 
        :hashtags        => hashtags, 
        :c               => c,
        :latency         => 0, 
        :samples         => 0 
      }
     
      GenServer.start_link(__MODULE__, initial_state, name: {:global, :simulator})  
  end

  def init(state) do
    IO.puts "creating client processes"    

    server = GenServer.whereis({:global, :server})
    send(server, {:num_clients, @n_clients})
    
    chunks = Enum.chunk_every(1..@n_clients, 100)
    
    chunked_tasks = Enum.map(chunks, fn chunk ->
      Task.async(fn ->
        
        Enum.map(chunk, fn rank -> 
          num_followers = @n_clients*(state[:c] / :math.pow(rank, @zipf_coeff)) |> round
          
          {:ok, clientid} = Client.start_link(%{
            "rank"          => rank, 
            "num_followers" => num_followers,
            "server"        => server,
            "n_clients"     => @n_clients,
            "hashtags"      => state[:hashtags],
            "tweets"        => state[:tweets],
            "hashtags_db_size" => length(state[:hashtags]),
            "tweets_db_size" =>  length(state[:tweets]), 
            "live"           => true 
          })
          
          clientid
        end)

      end) 
    end)

    clients = Enum.reduce(chunked_tasks, [], fn chunk_task, acc ->
      acc ++ Task.await(chunk_task)
    end)
    
    IO.puts "done creating clients"
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

  def handle_cast({:follower, follower, followed}, state) do
    GenServer.cast(Enum.at(state[:clients], follower-1), {:follow, followed})
    {:noreply, state}
  end


  def handle_cast({:latency, timediff}, state) do
    {_, state} = Map.get_and_update(state, :latency, fn x -> 
      {x, x + timediff}
    end)

    {_, state} = Map.get_and_update(state, :samples, fn x -> 
      {x, x + 1}
    end)

    {:noreply, state}
  end

  def handle_info({:end}, state) do
    IO.puts "end"

    IO.inspect state[:latency] / (state[:samples]*1000000)
    Process.exit(self(), :shutdown)
   
    {:noreply, state}
  end
  
end