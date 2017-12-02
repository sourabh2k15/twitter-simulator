defmodule Main do
    @server_name "server"
    @ip "127.0.0.1"
    
    def main(args) do
        args |> parse_args
    end

    def parse_args(["server"]) do
        _ = System.cmd("epmd", ['-daemon'])
        {:ok, _} = @server_name<>"@"<>@ip |> String.to_atom |> Node.start
       
        {:ok, server} = Server.start_link()
            
        :global.register_name("main", self())
        wait()
    end

    def parse_args(["simulator"]) do
        connect("client", Simulator)
    end

    def parse_args(_) do
        IO.puts "please provide an argument 'server' / 'client' "
    end

    def connect(entity, module) do
        node_name = entity<>"@"<>@ip
        server_name = @server_name<>"@"<>@ip

        {:ok, _} = node_name |> String.to_atom |> Node.start
        isConnected = server_name |> String.to_atom |> Node.connect

        if isConnected do 
            :global.sync()
            module.start_link()

            wait()
        else 
            IO.puts "couldn't connect to server"
            send(self(), {:exit, "client simulator"})
        end
    end

    def wait() do
        receive do
            {:exit, "server", tweets, time} ->
                GenServer.stop({:global, :server}, :normal)

                IO.puts "\n\n\n\n server ended tweets: #{tweets}, time: #{time}"
            {msg} -> 
                IO.puts "message received on main thread: #{msg}"    
        end
    end
end