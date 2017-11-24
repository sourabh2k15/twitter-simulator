defmodule Util do
    # Utility functions 
  
    # picks a random node from a given list
    def pickRandom(nodesList) do
        :random.seed(:erlang.system_time())
        Enum.random(nodesList) 
    end
    
    def generate(t_max) do
        :random.seed(:erlang.system_time())
        Enum.random(1..t_max)    
    end
end