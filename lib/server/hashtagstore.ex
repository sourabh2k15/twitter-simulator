defmodule HashtagStore do
    def init(workers) do
        state = %{:workers => workers}
        {:ok, state}
    end
end