defmodule Server do
  use GenServer

  def start_link(initial_state) do
    GenServer.start_link(__MODULE__, initial_state, name: {:global, :server})
  end

  def init(state) do
    IO.inspect state
    IO.puts "server started"
     
    {:ok, state}
  end

  def handle_call({:tweet, clientid, tweet}, _from, state) do
    IO.puts "client #{clientid} tweeted: #{tweet}"
    
    {:reply, {"tweet call acknowledge"}, state}
  end

  def handle_info({:register, rank, pid}, state) do
    IO.puts "client registering #{rank}, #{inspect pid}"
    state = Kernel.put_in(state, [:user_map, rank], pid)

    {:noreply, state}  
  end

  def handle_info({:followers_update, rank, followers}, state) do
    IO.puts "client #{rank}, sent follower list"
    state = Kernel.put_in(state, [:follower_map, rank], followers)

    if length(Map.keys(state[:follower_map])) == length(Map.keys(state[:user_map])) do 
      IO.puts "done creating followermap, users will now start tweeting"
      GenServer.cast({:global, :simulator}, {:start_tweeting}) 
    end
    
    {:noreply, state}  
  end

  def processTweet(sender, tweet) do
    IO.puts "#{inspect sender} tweeted #{tweet}"
    tokens = String.split(tweet)
    
    mentions = Enum.filter(tokens, fn token ->
      String.at(token, 0) == "@"  
    end)

    hashtags = Enum.filter(tokens, fn token ->
      String.at(token, 0) == "#"    
    end)

    tweet_metadata = %{:hashtags => hashtags, :mentions => mentions, :tweet => tweet}
  end

end
