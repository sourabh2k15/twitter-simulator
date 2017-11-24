defmodule Client do
    def start_link(initial_state) do
        GenServer.start_link(__MODULE__, initial_state)
    end

    def init(initial_state) do
        register(initial_state) 
       
        spawn(fn -> createFollowers(initial_state) end)
        #tweet_scheduler(initial_state["rank"])

        {:ok, initial_state}
    end

    def handle_info({:tweet}, state) do
        IO.puts "user with rank #{inspect state["rank"]} tweeting"
        
        tweet(state["server"], state["rank"])
        tweet_scheduler(state["rank"])

        {:noreply, state}
    end

    # client api 
    def register(state) do
        Kernel.send(state["server"], {:register, state["rank"], self()})        
    end

    def createFollowers(state) do
        IO.puts "creating followers"
        
        n_clients = state["n_clients"]
        num_followers = state["num_followers"]
        rank = state["rank"]

        IO.inspect "#{rank}, #{num_followers}, #{n_clients}"

        followers = Enum.reduce(1..num_followers, [], fn _, acc -> 
            acc ++ [(Enum.to_list(1..n_clients) -- [rank] |> Util.pickRandom)]        
        end)    

        Kernel.send(state["server"], {:followers_update, state["rank"], followers}) 
    end

    def tweet(server, rank) do
        timestamp = :os.system_time(:seconds)
        tweet = "hoshlqhilw @user_1 #travel_lust"
        
        response = GenServer.call(server, {:tweet, rank, tweet, timestamp})    
        IO.inspect response
    end

    def tweet_scheduler(timeout) do 
        Process.send_after(self(), {:tweet}, timeout)       
    end
end