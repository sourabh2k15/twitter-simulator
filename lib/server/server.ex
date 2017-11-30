defmodule Server do
  @distibution_factor 1000
  @alphabet_size 26

  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, nil, name: {:global, :server})
  end

  def init(_) do
    IO.puts "server started"     

    initial_state = %{
      :num_clients => 0, 
      :counter => 0
    }

    {:ok, initial_state}
  end

  '''
    GET NUM_CLIENTS AND INITIALIZE TWEET PROCESSORS, TWEET STORES AND HASHTAG STORES 
  '''
  def handle_info({:num_clients, num_clients}, state) do
    IO.puts "creating processors, data stores and hashtag stores to scale"

    state = Map.put(state, :num_clients, num_clients)  
    
    num_workers =  num_clients / @distibution_factor |> round
    
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
      GenServer.cast(workers[id][:processor], {:initialize, workers, hashtag_stores, workers[id][:datastore], @distibution_factor}) 
    end)

    state = Map.put(state, :workers, workers)
    state = Map.put(state, :hashtag_stores, hashtag_stores)

    {:noreply, state}
  end

  '''
    REGISTER USERS

    @param rank, rank of client
    @param pid,  process id of client process
  ''' 

  def handle_info({:register, rank, pid}, state) do
    worker_index = rank / @distibution_factor |> round 
    GenServer.cast(state[:workers][worker_index][:datastore], {:register, rank, pid})

    {:noreply, state}  
  end
  
  '''
    UPDATE FOLLOWERS

    @param rank, rank of client
    @param followers, list of ranks of clients following client with rank = @param rank 
  '''

  def handle_info({:followers_update, rank, followers}, state) do
    worker_index = rank / @distibution_factor |> round 
    GenServer.cast(state[:workers][worker_index][:datastore], {:followers, rank, followers})
    
    {_, state} = Map.get_and_update(state, :counter, fn x -> {x, x + 1} end)

    if state[:counter] == state[:num_clients] do
      IO.puts "done creating follower relations, network will now start tweeting" 
      GenServer.cast({:global, :simulator}, {:start_tweeting})
    end

    {:noreply, state}  
  end


  '''
    HANDLE USER TWEET
  
    @param clientid , rank of user
    @param tweet    , tweet string
    @param timestamp, of when it was generated on client 
  '''

  def handle_call({:tweet, rank, tweet, timestamp, retweet, origin}, _from, state) do
    worker_index =  rank / @distibution_factor |> round 
    GenServer.cast(state[:workers][worker_index][:processor], {:tweet, rank, tweet, timestamp, retweet, origin})

    {:reply, {"tweet call acknowledge"}, state}
  end

end
