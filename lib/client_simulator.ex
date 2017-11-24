defmodule ClientSimulator do
  @n_clients 1000
  use GenServer
  
  def start_link() do
      IO.puts "sim startlink"
      GenServer.start_link(__MODULE__, nil, name: {:global, :simulator})  
  end

  def init(_) do
    IO.puts "simulator starting"
    IO.puts "creating client processes"

    clients = Enum.reduce(1..@n_clients, [], fn rank,t_clients -> 
        num_followers = (@n_clients - 1) / rank |> round
        server = GenServer.whereis({:global, :server})

        {:ok, clientid} = Client.start_link(%{
          "rank" => rank, 
          "num_followers" => num_followers,
          "server" => server,
          "n_clients" => @n_clients,
          "follow_map" => %{}
        })

        t_clients ++ [clientid]
    end)
   
    {:ok, %{:clients => clients}}
  end

  def handle_cast({:start_tweeting}, state) do
    IO.puts "network will start tweeting now!"
    clients = state[:clients]

    Enum.each(1..@n_clients, fn rank -> 
        Kernel.send(Enum.at(clients, rank-1), {:tweet})
    end)

    {:noreply, state}
  end

end