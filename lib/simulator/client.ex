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
        Process.send_after(self(), {:tweet}, @time_factor*state["rank"])

        {:noreply, state}
    end

    def handle_info({:tweet}, state) do
        kill    = (Util.rand(0, 1000) == 1000)
        
        state = if kill do
            GenServer.cast(state["server"], {:logout, state["rank"], :os.system_time(:nano_seconds)})
            Map.put(state, "live", false)
        else
            state
        end
        
        if state["live"] do
            {tweet, timestamp} = TweetProducer.createTweet(state["tweets"], state["hashtags"], state["n_clients"])
            IO.puts "user #{state["rank"]} tweeted: #{tweet}"
            
            if tweet != nil do
                GenServer.cast(state["server"], {:tweet, state["rank"], tweet, timestamp, false, nil})
            end

            Process.send_after(self(), {:tweet}, @time_factor*state["rank"])
        else
            IO.puts "client #{state["rank"]} logged out"
            timeout = Util.rand(1000, 2000)
            :timer.sleep timeout

            GenServer.cast(state["server"], {:logged_in, state["rank"], :os.system_time(:nano_seconds)})
        end

        {:noreply, state}
    end

    def handle_cast({:subscribed_tweet, source, tweet, timestamp, retweet, origin}, state) do
        if retweet do 
            IO.puts "user #{state["rank"]} received subscribed retweet from user #{source}, origin: user #{origin}: #{inspect tweet} "
        else 
            IO.puts "user #{state["rank"]} received subscribed tweet from user #{source}: #{inspect tweet} "
        end

        timestamp_new = :os.system_time(:nano_seconds)
        GenServer.cast({:global, :simulator}, {:latency, timestamp_new - timestamp})

        retweet = ((Util.rand(1, 10*state["num_followers"]) > 6*state["num_followers"]))
        query   = (Util.rand(1, 10000) > 9940)

        if retweet do
            Process.sleep state["rank"]*@time_factor
            GenServer.cast(state["server"], {:tweet, state["rank"], tweet, timestamp, retweet, origin})        
        end

        if query do
            q = generateQuery(state["n_clients"], state["hashtags"])
            
            if q != "" do 
               GenServer.cast(state["server"], {:query, q, self()}) 
               IO.puts "user #{state["rank"]} querying server: #{q}"
            end
        end

        {:noreply, state}
    end

    def handle_cast({:query_result, query, result}, state) do
        IO.puts "query result, #{query}, #{inspect result}"

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
            Task.async(fn ->
                Enum.reduce(chunk, [], fn _, acc ->
                    follower = Util.pickRandom(n_clients, rank)
                    acc ++ [follower]         
                end)
            end)     
        end)

        followers = Enum.reduce(chunked_tasks, [], fn chunk_task, acc -> 
            acc ++ Task.await(chunk_task)
        end)

        Kernel.send(state["server"], {:followers_update, state["rank"], followers}) 
    end

    def generateQuery(n_clients, hashtags) do
        type = Enum.random([0,1,2])
        
        query = if type == 0 do
            Integer.to_string(Util.rand(1, 100))
        else 
            if type == 1 do
                "@"<>Integer.to_string(Util.rand(1, 100 |> round))
            else    
                Enum.at(hashtags, Util.rand(0, length(hashtags)))
            end
        end
    end
end