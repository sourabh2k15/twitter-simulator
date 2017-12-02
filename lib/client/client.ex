defmodule Client do
    @time_factor 1
    @chunk_factor 1000

    def start_link(initial_state) do
        GenServer.start_link(__MODULE__, initial_state)
    end 

    def init(initial_state) do
        register(initial_state) 
        spawn(fn -> createFollowers(initial_state) end)
        
        {:ok, initial_state}
    end

    def handle_info({:start_tweeting}, state) do
        tweet_scheduler(state["rank"])
 
        {:noreply, state}
    end

    def handle_info({:tweet}, state) do
        GenServer.cast({:global, :simulator}, {:create_tweet, state["rank"], self()})
        {:noreply, state}
    end

    def handle_cast({:tweet_created, tweet, timestamp}, state) do
        IO.puts "user #{state["rank"]} tweeted : #{tweet}"
        try do
            GenServer.cast(state["server"], {:tweet, state["rank"], tweet, timestamp, false, nil})
            #acktimestamp = :os.system_time(:micro_seconds) - timestamp
            tweet_scheduler(state["rank"])
        rescue 
            e -> 
                IO.puts "error"
                IO.inspect e
        end

        {:noreply, state}
    end

    def handle_cast({:subscribed_tweet, source, tweet, timestamp, retweet, origin}, state) do
        if retweet do 
            IO.puts "received subscribed retweet from #{source}, origin: #{origin}: #{inspect tweet} "
        else 
            IO.puts "received subscribed tweet from #{source}: #{inspect tweet} "
        end

        timestamp_new = :os.system_time(:micro_seconds)

        retweet = Enum.random([nil,nil,nil,nil,0])
        
        if retweet do
            Process.sleep state["rank"]*@time_factor
            GenServer.cast(state["server"], {:tweet, state["rank"], tweet, timestamp_new, retweet, source})        
        end
        {:noreply, state}
    end

    def handle_cast({:follow, followed}, state) do
        {_, state} = Map.get_and_update(state, "followed", fn x -> 
            if x == nil do
                {x, [followed]}
            else 
                {x, x ++ [followed]}
            end
        end)

        {:noreply, state}
    end
    def handle_cast({:exit}, state) do
        GenServer.stop(self())
        {:noreply, state}
    end

    # client api 
    def register(state) do
        Kernel.send(state["server"], {:register, state["rank"], self()})        
    end

    def createFollowers(state) do
        n_clients = state["n_clients"]
        num_followers = state["num_followers"]
        rank = state["rank"]

        chunks = Enum.chunk_every(1..num_followers, @chunk_factor)

        chunked_tasks = Enum.map(chunks, fn chunk -> 
            task = Task.async(fn ->
                followers_chunk = Enum.reduce(chunk, [], fn _, acc ->
                    follower = Util.pickRandom(n_clients, rank)
                    GenServer.cast({:global, :simulator}, {:follower, follower, state["rank"]})
                    
                    acc ++ [follower]         
                end)
            end)     
        end)

        followers = Enum.reduce(chunked_tasks, [], fn chunk_task, acc -> 
            acc ++ Task.await(chunk_task)
        end)

        IO.puts "creating #{num_followers} followers for client #{rank}"
        
        Kernel.send(state["server"], {:followers_update, state["rank"], followers}) 
    end

    def tweet_scheduler(timeout) do 
        Process.send_after(self(), {:tweet}, @time_factor*timeout)       
    end
end