--[[
    FirXD's Network Library
    Author: FirXD (@FirTheDeveloper)

    This module can be required from both the client and the server.

    This module is designed to simplify client/server communication by automatically
    creating and managing RemoteEvents and RemoteFunctions for you.

    TO SETUP:
        - Place this ModuleScript into ReplicatedStorage

    USAGE:
        -- Load the library
        local Network = require(game.ReplicatedStorage.Network)

        -- Bind an event on the server
        Network.BindEvents({
            ExampleEvent = function(player, message)
                print(player.Name, message)
            end
        })

        -- Fire the event from the client
        Network.FireServer("ExampleEvent", "Hello world!")

        -- Bind a function on the server
        Network.BindFunctions({
            GetCoins = function(player)
                return 100
            end
        })

        -- Invoke the function from the client
        local coins = Network.InvokeServer(5, "GetCoins")
        print(coins)

      Thanks for using my code!
]]


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()

local ROOT_NAME = "Communication"

local CommunicationRoot
local FunctionsFolder
local EventsFolder

if IS_SERVER then
	CommunicationRoot = ReplicatedStorage:FindFirstChild(ROOT_NAME)

	if not CommunicationRoot then
		CommunicationRoot = Instance.new("Folder")
		CommunicationRoot.Name = ROOT_NAME
		CommunicationRoot.Parent = ReplicatedStorage
	end

	FunctionsFolder = CommunicationRoot:FindFirstChild("Functions")

	if not FunctionsFolder then
		FunctionsFolder = Instance.new("Folder")
		FunctionsFolder.Name = "Functions"
		FunctionsFolder.Parent = CommunicationRoot
	end

	EventsFolder = CommunicationRoot:FindFirstChild("Events")

	if not EventsFolder then
		EventsFolder = Instance.new("Folder")
		EventsFolder.Name = "Events"
		EventsFolder.Parent = CommunicationRoot
	end
else
	CommunicationRoot = ReplicatedStorage:WaitForChild(ROOT_NAME)
	FunctionsFolder = CommunicationRoot:WaitForChild("Functions")
	EventsFolder = CommunicationRoot:WaitForChild("Events")
end

local function fastSpawn(fn, ...)
	task.spawn(fn, ...)
end

local function yieldThread()
	return coroutine.yield()
end

local function resumeThread(co, ...)
	coroutine.resume(co, ...)
end

local function safeInvokeCallback(handler, ...)
	local finished = false
	local resultPack
	local waitingThread

	local function finish(...)
		if finished then
			return
		end

		finished = true
		resultPack = table.pack(...)

		if waitingThread then
			resumeThread(waitingThread)
		end
	end

	fastSpawn(function(...)
		finish(true, handler.Callback(...))
	end, ...)

	if not finished then
		waitingThread = coroutine.running()
		yieldThread()
	end

	return unpack(resultPack or {})
end

local function safeInvoke(timeout, invokeFn, ...)
	local co = coroutine.running()
	local done = false
	local result

	fastSpawn(function(...)
		result = table.pack(pcall(invokeFn, ...))

		if not done then
			done = true
			resumeThread(co)
		end
	end, ...)

	if typeof(timeout) == "number" then
		task.delay(timeout, function()
			if not done then
				done = true
				resumeThread(co)
			end
		end)
	end

	yieldThread()

	if not result or result[1] ~= true then
		return false
	end

	return true, unpack(result, 2)
end

local function waitForChild(parent, name)
	local child = parent:FindFirstChild(name)

	if child then
		return child
	end

	local co = coroutine.running()
	local connection

	connection = parent.ChildAdded:Connect(function(obj)
		if obj.Name == name then
			connection:Disconnect()
			child = obj
			resumeThread(co)
		end
	end)

	yieldThread()

	return child
end

local eventCache = {}
local functionCache = {}

local function getEventHandler(name)
	local existing = eventCache[name]

	if existing then
		return existing
	end

	local config = {
		Name = name,
		Callbacks = {}
	}

	eventCache[name] = config

	if IS_SERVER then
		local remote = EventsFolder:FindFirstChild(name)

		if not remote then
			remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = EventsFolder
		end

		config.Remote = remote
	else
		fastSpawn(function()
			config.Queue = {}

			local remote = waitForChild(EventsFolder, name)
			config.Remote = remote

			remote.OnClientEvent:Connect(function(...)
				for _, callback in ipairs(config.Callbacks) do
					callback(...)
				end
			end)

			for _, queued in ipairs(config.Queue) do
				queued()
			end

			config.Queue = nil
		end)
	end

	return config
end

local function getFunctionHandler(name)
	local existing = functionCache[name]

	if existing then
		return existing
	end

	local config = {
		Name = name
	}

	functionCache[name] = config

	if IS_SERVER then
		local remote = FunctionsFolder:FindFirstChild(name)

		if not remote then
			remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = FunctionsFolder
		end

		config.Remote = remote
	else
		fastSpawn(function()
			config.Queue = {}

			local remote = waitForChild(FunctionsFolder, name)
			config.Remote = remote

			remote.OnClientInvoke = function(...)
				return safeInvokeCallback(config, ...)
			end

			for _, queued in ipairs(config.Queue) do
				queued()
			end

			config.Queue = nil
		end)
	end

	return config
end

local function addToQueue(remote, fn, warnSlow)
	if remote.Remote then
		return fn()
	end

	remote.Queue[#remote.Queue + 1] = fn

	if warnSlow then
		task.delay(5, function()
			if not remote.Remote then
				warn(debug.traceback(("Infinite yield possible on %s"):format(remote.Name)))
			end
		end)
	end
end

local Network = {}

function Network.GetEvent(name)
	return getEventHandler(name)
end

function Network.GetFunction(name)
	return getFunctionHandler(name)
end

--// EVENTS

function Network.FireServer(name, ...)
	assert(not IS_SERVER, "FireServer can only be called on the client")

	local remote = getEventHandler(name)

	if remote.Remote then
		remote.Remote:FireServer(...)
	else
		local args = table.pack(...)

		addToQueue(remote, function()
			remote.Remote:FireServer(unpack(args))
		end, true)
	end
end

function Network.FireClient(player, name, ...)
	assert(IS_SERVER, "FireClient can only be called on the server")

	local remote = getEventHandler(name)
	remote.Remote:FireClient(player, ...)
end

function Network.FireAllClients(name, ...)
	assert(IS_SERVER, "FireAllClients can only be called on the server")

	local remote = getEventHandler(name)
	remote.Remote:FireAllClients(...)
end

--// FUNCTIONS

function Network.InvokeServer(timeout, name, ...)
	assert(not IS_SERVER, "InvokeServer can only be called on the client")

	local remote = getFunctionHandler(name)

	if not remote.Remote then
		local co = coroutine.running()

		addToQueue(remote, function()
			resumeThread(co)
		end, true)

		yieldThread()
	end

	local result = table.pack(
		safeInvoke(timeout, function(...)
			return remote.Remote:InvokeServer(...)
		end, ...)
	)

	local ok = result[1]

	assert(ok, "InvokeServer error")

	return table.unpack(result, 2)
end

function Network.InvokeClient(timeout, player, name, ...)
	assert(IS_SERVER, "InvokeClient can only be called on the server")

	local remote = getFunctionHandler(name)

	local result = table.pack(
		safeInvoke(timeout, function(playerArg, ...)
			return remote.Remote:InvokeClient(playerArg, ...)
		end, player, ...)
	)

	local ok = result[1]

	assert(ok, "InvokeClient error")

	return table.unpack(result, 2)
end

--// BINDING

function Network.BindEvents(map)
	for name, handler in pairs(map) do
		local remote = getEventHandler(name)

		table.insert(remote.Callbacks, handler)

		if IS_SERVER then
			remote.Remote.OnServerEvent:Connect(function(player, ...)
				handler(player, ...)
			end)
		end
	end
end

function Network.BindFunctions(map)
	for name, handler in pairs(map) do
		local remote = getFunctionHandler(name)

		remote.Callback = handler

		if IS_SERVER then
			remote.Remote.OnServerInvoke = function(...)
				return safeInvokeCallback(remote, ...)
			end
		end
	end
end

return Network
