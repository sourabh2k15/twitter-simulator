defmodule Client do
    @time_factor 1000
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
       tweet(state["server"], state["rank"])
       {:noreply, state}
    end

    def handle_cast({:subscribed_tweet, source, tweet, timestamp}, state) do
        IO.puts "received subscribed tweet from #{source}: #{inspect tweet} "

        # TODO randomly choose to retweet sometimes

        {:noreply, state}
    end

    def handle_cast({:tweet_created, tweet, timestamp}, state) do
        IO.puts "user #{state["rank"]} tweeted : #{tweet}"

        response = GenServer.call(state["server"], {:tweet, state["rank"], tweet, timestamp})
        #acktimestamp = :os.system_time(:micro_seconds) - timestamp
        tweet_scheduler(state["rank"])

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
                    acc ++ [Util.pickRandom(n_clients, rank)]         
                end)
            end)     
        end)

        followers = Enum.reduce(chunked_tasks, [], fn chunk_task, acc -> 
            acc ++ Task.await(chunk_task)
        end)

        IO.puts "creating #{num_followers} followers for client #{rank}"
        
        Kernel.send(state["server"], {:followers_update, state["rank"], followers}) 
    end

    def tweet(server, rank) do
        GenServer.cast({:global, :simulator}, {:create_tweet, rank, self()})
        #IO.inspect response
        
        #tweet_scheduler(rank)
    end

    def tweet_scheduler(timeout) do 
        Process.send_after(self(), {:tweet}, @time_factor*timeout)       
    end
end