I got bored, needed a network library for Valora Gateway. This is the result.
Usage:
SERVER:
```lua
local Network = require(game.ReplicatedStorage.Network)

-- Bind an event on the server
Network.BindEvents({
    ExampleEvent = function(player, message)
        print(player.Name, message)
    end
})

-- Bind a function on the server
Network.BindFunctions({
    GetCoins = function(player)
        return 100
    end
})
```

CLIENT:
```lua
local Network = require(game.ReplicatedStorage.Network)

-- Invoke the function from the client
local coins = Network.InvokeServer(5, "GetCoins")
print(coins)

-- Fire the event from the client
Network.FireServer("ExampleEvent", "Hello world!")
```

Args:
```lua
Network.InvokeServer(timeout, functionName)
Network.FireServer(event, args (can be however long you want))
Network.BindFunctions({
    event name = function(player, args)
        --do something
    end
})

Network.BindEvents({
    event name = function(player, args)
        --do something
    end
})
