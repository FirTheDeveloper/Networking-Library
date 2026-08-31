I'm not updating this don't even ask me to do it

Usage:
https://open.spotify.com/socialsession/2mYIOQyxGG2m7PjYxLTKDL?si=acVNxtX5SHud-u44n2N9ww&utm_source=copy-link
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
