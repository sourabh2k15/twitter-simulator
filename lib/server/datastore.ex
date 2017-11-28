defmodule DataStore do
    def init(_) do
        state = %{
            :users          =>  %{},
            :followers      =>  %{},
            :tweets_by_user =>  %{},
            :tweets         =>  %{},
            :mentions       =>  %{}
        }

        {:ok, state}
    end

    def handle_cast({:register, rank, pid}, state) do
        state = Kernel.put_in(state, [:users, rank], pid)
       
        {:noreply, state}
    end

    def handle_cast({:followers, rank, followers}, state) do
        state = Kernel.put_in(state, [:followers, rank], followers)
        
        {:noreply, state}
    end

    def handle_call({:get_followers, rank}, _from, state) do
        followers = state[:followers][rank]
        {:reply, followers, state}
    end

    def handle_call({:get_user_pid, rank}, _from, state) do
        {:reply, state[:users][rank], state}
    end
end