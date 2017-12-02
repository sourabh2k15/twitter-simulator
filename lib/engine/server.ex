defmodule Server do
  @alphabet_size 26
  @run_time 10000

  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, nil, name: {:global, :server})
  end

  def init(_) do
    IO.puts "server started"     

    initial_state = %{
      :num_clients  => 0, 
      :counter      => 0, 
      :total_tweets => 0
    }

    {:ok, initial_state}
  end

  def handle_info({:num_clients, num_clients}, state) do
    IO.puts "creating processors, data stores and hashtag stores to scale"

    state = Map.put(state, :num_clients, num_clients)  
    
    num_workers =  Util.log2(num_clients)
    
    workers = Enum.reduce(0..num_workers, %{}, fn i, acc -> 
      {:ok, processor_id} = GenServer.start_link(Processor, :ok)
      {:ok, datastore_id} = GenServer.start_link(DataStore, :ok)
      
      Map.put(acc, i, [processor: processor_id, datastore: datastore_id])
    end)

    hashtag_stores = Enum.reduce(0..@alphabet_size-1, %{}, fn i, acc ->
      {:ok, hashtag_store} = GenServer.start_link(HashtagStore, workers) 
      Map.put(acc, <<97 + i >>, hashtag_store)
    end)

    Enum.each(0..num_workers, fn id ->
      GenServer.cast(workers[id][:processor], {:initialize, workers, hashtag_stores, workers[id][:datastore]}) 
    end)

    state = Map.put(state, :workers, workers)
    state = Map.put(state, :hashtag_stores, hashtag_stores)

    {:noreply, state}
  end

  def handle_info({:register, rank, pid}, state) do
    worker_index = Util.log2(rank)
    GenServer.cast(state[:workers][worker_index][:datastore], {:register, rank, pid})

    {:noreply, state}  
  end

  def handle_info({:followers_update, rank, followers}, state) do
    worker_index = Util.log2(rank)
    GenServer.cast(state[:workers][worker_index][:datastore], {:followers, rank, followers})
    
    {_, state} = Map.get_and_update(state, :counter, fn x -> {x, x + 1} end)
    
    if state[:counter] == state[:num_clients] do
      IO.puts "done creating follower relations, network will now start tweeting" 
      
      Process.send_after(self(), {:exit}, @run_time)
      GenServer.cast({:global, :simulator}, {:start_tweeting})
    end

    {:noreply, state}  
  end

  def handle_info({:exit}, state) do
    main = :global.whereis_name("main")
    simulator = GenServer.whereis({:global, :simulator})

    send(simulator, {:end})
    send(main, {:exit, "server", state[:total_tweets], @run_time})
    
    {:noreply, state}
  end

  def handle_cast({:tweet, rank, tweet, timestamp, retweet, origin}, state) do
    worker_index =  Util.log2(rank)
    GenServer.cast(state[:workers][worker_index][:processor], {:tweet, rank, tweet, timestamp, retweet, origin})

    {_, state} = Map.get_and_update(state, :total_tweets, fn x -> {x, x+1} end)
    {:noreply, state}
  end

  def handle_cast({:query, query, source}, state) do
    if String.at(query, 0) == "#" do
      GenServer.cast(state[:hashtag_stores][String.at(query, 1)], {:query, query, source})
    end

    {:noreply, state}
  end

  def handle_cast({:logout, rank}, state) do
    worker_index =  Util.log2(rank)
    GenServer.cast(state[:workers][worker_index][:datastore], {:logout, rank})

    {:noreply, state}
  end

end
