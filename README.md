# SleekNotify by Silvex
A beautiful and minimalist roblox notification libary to replace CoreGUI, Originally made to be used on Silvex Executor API. Anyone can now use this as theres no reason to gatekeep it.

## Getting Started
Firstly, Load the libary and declare it in your lua:
```lua
local Notify = loadstring(game:HttpGet("https://raw.githubusercontent.com/mintra-nodes/SleekNotify/refs/heads/main/core.lua"))()
```

## Sending a notification (Examples)
Now heres most of the ways to send notifications.
```lua
local Notify = loadstring(game:HttpGet("https://raw.githubusercontent.com/mintra-nodes/SleekNotify/refs/heads/main/core.lua"))()

-- Barebones sending, Description only.
Notify.info("Server joined successfully")
Notify.success("Item equipped")
Notify.warning("Lag detected")
Notify.error("Connection failed")

-- Sending with a Title
Notify.Info("Player Info", "Loaded 142 items")
Notify.Success("Saved", "Your config has been stored")
Notify.Warning("Heads up", "This feature is experimental")
Notify.Error("Auth Failed", "Invalid key, please check and retry")

-- Fully custom (not using a template)
Notify.send("Script injected", "default", 5)
```

## Full notification type functions
Need a full list? Here you go!
```lua
function Notify.info(text, duration)    Notify.send(text, "info",    duration) end
function Notify.success(text, duration) Notify.send(text, "success", duration) end
function Notify.warning(text, duration) Notify.send(text, "warning", duration) end
function Notify.error(text, duration)   Notify.send(text, "error",   duration) end

function Notify.Info(title, text, duration)    Notify.senditled(title, text, "info",    duration) end
function Notify.Success(title, text, duration) Notify.senditled(title, text, "success", duration) end
function Notify.Warning(title, text, duration) Notify.senditled(title, text, "warning", duration) end
function Notify.Error(title, text, duration)   Notify.senditled(title, text, "error",   duration) end
```

Thank you for using SleekNotify, this project will be updated every now and then when needed.
No credits are required when using this - Have fun!
