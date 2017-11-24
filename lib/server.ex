defmodule Server do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, nil, name: {:global, :server})
  end

  def init(_) do
    initial_state = %{:num_users => 0, :user_map => %{} ,:follower_map => %{}}

    IO.puts "server started"     
    {:ok, initial_state}
  end

  '''
    HANDLE USER TWEET
  
    @param clientid , rank of user
    @param tweet    , tweet string
    @param timestamp, of when it was generated on client 
  '''

  def handle_call({:tweet, clientid, tweet, timestamp}, _from, state) do
    IO.puts "client #{clientid} tweeted: #{tweet}"
    
    {:reply, {"tweet call acknowledge"}, state}
  end

  '''
    REGISTER USERS

    @param rank, rank of client
    @param pid,  process id of client process
  ''' 

  def handle_info({:register, rank, pid}, state) do
    IO.puts "client registering #{rank}, #{inspect pid}"
    state = Kernel.put_in(state, [:user_map, rank], pid)

    {:noreply, state}  
  end

  '''
    UPDATE FOLLOWERS

    @param rank, rank of client
    @param followers, list of ranks of clients following client with rank = @param rank 
  '''

  def handle_info({:followers_update, rank, followers}, state) do
    IO.puts "client #{rank}, sent follower list"
    state = Kernel.put_in(state, [:follower_map, rank], followers)

    if length(Map.keys(state[:follower_map])) == length(Map.keys(state[:user_map])) do 
      IO.puts "done creating followermap, users will now start tweeting"
      GenServer.cast({:global, :simulator}, {:start_tweeting}) 
    end
    
    {:noreply, state}  
  end

  '''
    PROCESS TWEETS 

    @param sender, rank of client who tweeted
    @param tweet , tweet string
  '''
  
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
