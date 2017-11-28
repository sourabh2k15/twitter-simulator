defmodule RandTest do
    @n_clients 1000000

    def start do
        Enum.each(1..@n_clients, fn _ ->
            mention_index = Util.generate(1, @n_clients)
            IO.puts Integer.to_string(mention_index) 
        end)
    end
end