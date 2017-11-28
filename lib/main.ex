defmodule Main do
    def main(args) do
        args |> parse_args
    end

    # starting server 
    def parse_args(["server"]) do
        _ = System.cmd("epmd", ['-daemon'])
        {:ok, _} = "server@127.0.0.1" |> String.to_atom |> Node.start
       
        {:ok, server} = Server.start_link()
            
        :global.register_name("main", self())
        wait()
    end

    #starting client simulator
    def parse_args(["client"]) do
        {:ok, _} = "client@127.0.0.1" |> String.to_atom |> Node.start
        isConnected = "server@127.0.0.1" |> String.to_atom |> Node.connect
        
        if isConnected do
            :global.sync()
            Simulator.start_link()
            
            :timer.sleep 10000000
        else 
            IO.puts "couldn't connect to server"
            send(self(), {:exit, "client simulator"})
        end
    end

    def parse_args(_) do
        IO.puts "please provide an argument 'server' / 'client' "
        #Experiment.start()
        RandTest.start()
    end

    def wait() do
        receive do
            {:exit, entity} ->
                IO.puts "#{entity} ended"
            {msg} -> 
                IO.puts "message received on main thread: #{msg}"    
        end
    end
end