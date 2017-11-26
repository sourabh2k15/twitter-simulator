defmodule Experiment do
    @n_clients 100000

    def createFollowersSync(n_clients) do
        followers = Enum.reduce(1..n_clients, [], fn rank, acc ->
            acc ++ [Util.pickRandom(@n_clients, rank)]         
        end)
    end

    def createFollowersAsync(n_clients) do
        chunks = Enum.chunk_every(1..n_clients, 1000)
        
        chunked_tasks = Enum.map(chunks, fn chunk -> 
            task = Task.async(fn ->
                followers_chunk = Enum.reduce(chunk, [], fn x, acc ->
                    acc ++ [Util.pickRandom(@n_clients, x)]         
                end)
            end)     
        end)

        followers = Enum.reduce(chunked_tasks, [], fn chunk_task, acc -> 
            acc ++ Task.await(chunk_task)
        end)
    end

    def start do
        start_time = :os.system_time(:milli_seconds)
        
        followers = createFollowersAsync(@n_clients)
        end_time_1 = :os.system_time(:milli_seconds)

        IO.inspect followers
        IO.puts length(followers)

        IO.puts "took #{(end_time_1 - start_time)}"
    end
end