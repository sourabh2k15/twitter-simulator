defmodule Util do
    # Utility functions 

    # picks a random node from a given list
    def pickRandom(max, current) do
        num = rand(1, max)
        
        if num != current do 
            num 
        else 
            pickRandom(max, current) 
        end
    end
    
    # generates random number in range 
    def rand(r_min, r_max) do
        rand_int = :rand.uniform()*(r_max - r_min + 1) |> :math.floor |> Kernel.+(r_min) |> round
    end
end