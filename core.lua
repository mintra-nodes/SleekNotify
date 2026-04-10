local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Notify = {}
Notify.__index = Notify

local CFG = {
	Width    = 300,
	Height   = 60,
	Padding  = 16,
	Gap      = 8,
	Duration = 3.5,
	AnimTime = 0.4,
	Corner   = 10,
	MaxVisible = 6,

	Font     = Enum.Font.GothamMedium,
	FontBold = Enum.Font.GothamBold,
	FontSize = 13,

	Colors = {
		info    = Color3.fromHex("#3B82F6"),
		success = Color3.fromHex("#22C55E"),
		warning = Color3.fromHex("#F59E0B"),
		error   = Color3.fromHex("#EF4444"),
		default = Color3.fromHex("#A1A1AA"),
	},

	Icons = {
		info    = "rbxassetid://7733960981",  -- info circle
		success = "rbxassetid://7734053495",  -- check circle
		warning = "rbxassetid://7734064831",  -- alert triangle
		error   = "rbxassetid://7734076914",  -- x circle
		default = nil,
	},
}

local queue  = {}
local active = {}
local gui    = nil
local holder = nil

-- Executor-safe GUI parenting
local function getGui()
	if gui then return end

	local player  = Players.LocalPlayer
	local success, result = pcall(function()
		return player:FindFirstChildOfClass("PlayerGui")
	end)

	local parent
	if success and result then
		parent = result
	else
		-- Fallback: CoreGui (requires syn.protect_gui or gethui in some executors)
		local coreGui = game:GetService("CoreGui")
		if pcall(function() return coreGui.RobloxGui end) then
			parent = coreGui
		end
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "NotifyUI_" .. tostring(math.random(1000, 9999)) -- avoid name conflicts
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 9999

	-- Executor: protect gui if API exists
	if syn and syn.protect_gui then
		syn.protect_gui(gui)
		gui.Parent = game:GetService("CoreGui")
	elseif gethui then
		gui.Parent = gethui()
	elseif parent then
		gui.Parent = parent
	else
		gui.Parent = game:GetService("CoreGui")
	end

	holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(0, CFG.Width, 1, 0)
	holder.Position = UDim2.new(1, -(CFG.Width + CFG.Padding), 0, 0)
	holder.Parent = gui
end

local function restack()
	local offset = CFG.Padding
	for i = #active, 1, -1 do
		local entry = active[i]
		if not entry.dismissed then
			TweenService:Create(
				entry.frame,
				TweenInfo.new(CFG.AnimTime, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
				{ Position = UDim2.new(0, 0, 1, -(offset + CFG.Height)) }
			):Play()
			offset = offset + CFG.Height + CFG.Gap
		end
	end
end

local function dismiss(entry)
	if entry.dismissed then return end
	entry.dismissed = true

	if entry.thread then
		task.cancel(entry.thread)
		entry.thread = nil
	end

	if entry.barTween then
		entry.barTween:Cancel()
		entry.barTween = nil
	end

	local slideOut = TweenService:Create(
		entry.frame,
		TweenInfo.new(CFG.AnimTime, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
		{
			Position = UDim2.new(0, CFG.Width + 30, entry.frame.Position.Y.Scale, entry.frame.Position.Y.Offset),
			BackgroundTransparency = 1,
		}
	)
	slideOut:Play()

	slideOut.Completed:Connect(function()
		pcall(function() entry.frame:Destroy() end)

		for i, v in ipairs(active) do
			if v == entry then
				table.remove(active, i)
				break
			end
		end

		restack()

		if #queue > 0 then
			local next = table.remove(queue, 1)
			task.spawn(next)
		end
	end)
end

local function makeCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or CFG.Corner)
	c.Parent = parent
	return c
end

local function build(text, title, kind, duration)
	local color = CFG.Colors[kind] or CFG.Colors.default
	local icon  = CFG.Icons[kind]
	local dur   = duration or CFG.Duration

	local hasTitle = title and title ~= ""
	local hasIcon  = icon ~= nil

	-- Outer frame
	local frame = Instance.new("Frame")
	frame.Name = "Notification"
	frame.Size = UDim2.new(0, CFG.Width, 0, CFG.Height)
	frame.Position = UDim2.new(0, CFG.Width + 30, 1, -(CFG.Padding + CFG.Height))
	frame.BackgroundColor3 = Color3.fromHex("#0E0E10")
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = false
	frame.Parent = holder
	makeCorner(frame)

	-- Inner card (sits on top of accent)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -3, 1, 0)
	card.Position = UDim2.new(0, 3, 0, 0)
	card.BackgroundColor3 = Color3.fromHex("#18181B")
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	card.Parent = frame
	makeCorner(card)

	-- Accent bar (left edge of outer frame, 3px)
	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(0, 3, 1, 0)
	accent.Position = UDim2.new(0, 0, 0, 0)
	accent.BackgroundColor3 = color
	accent.BorderSizePixel = 0
	accent.Parent = frame
	makeCorner(accent, CFG.Corner)

	-- Layout inside card
	local contentX = 12
	local contentW = -24

	-- Icon
	if hasIcon then
		local iconImg = Instance.new("ImageLabel")
		iconImg.Size = UDim2.new(0, 16, 0, 16)
		iconImg.Position = UDim2.new(0, contentX, 0.5, -8)
		iconImg.BackgroundTransparency = 1
		iconImg.Image = icon
		iconImg.ImageColor3 = color
		iconImg.Parent = card

		contentX = contentX + 24
		contentW = contentW - 24
	end

	-- Title + body stacked, or just body centered
	if hasTitle then
		local titleLabel = Instance.new("TextLabel")
		titleLabel.Size = UDim2.new(1, contentW - 20, 0, 18)
		titleLabel.Position = UDim2.new(0, contentX, 0, 10)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Text = title
		titleLabel.TextColor3 = Color3.fromHex("#FFFFFF")
		titleLabel.Font = CFG.FontBold
		titleLabel.TextSize = CFG.FontSize
		titleLabel.TextXAlignment = Enum.TextXAlignment.Left
		titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
		titleLabel.Parent = card

		local bodyLabel = Instance.new("TextLabel")
		bodyLabel.Size = UDim2.new(1, contentW - 20, 0, 16)
		bodyLabel.Position = UDim2.new(0, contentX, 0, 30)
		bodyLabel.BackgroundTransparency = 1
		bodyLabel.Text = text
		bodyLabel.TextColor3 = Color3.fromHex("#71717A")
		bodyLabel.Font = CFG.Font
		bodyLabel.TextSize = CFG.FontSize - 1
		bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
		bodyLabel.TextTruncate = Enum.TextTruncate.AtEnd
		bodyLabel.Parent = card
	else
		local bodyLabel = Instance.new("TextLabel")
		bodyLabel.Size = UDim2.new(1, contentW - 20, 1, 0)
		bodyLabel.Position = UDim2.new(0, contentX, 0, 0)
		bodyLabel.BackgroundTransparency = 1
		bodyLabel.Text = text
		bodyLabel.TextColor3 = Color3.fromHex("#D4D4D8")
		bodyLabel.Font = CFG.Font
		bodyLabel.TextSize = CFG.FontSize
		bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
		bodyLabel.TextYAlignment = Enum.TextYAlignment.Center
		bodyLabel.TextTruncate = Enum.TextTruncate.AtEnd
		bodyLabel.Parent = card
	end

	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 20, 0, 20)
	closeBtn.Position = UDim2.new(1, -24, 0.5, -10)
	closeBtn.BackgroundTransparency = 1
	closeBtn.Text = "×"
	closeBtn.TextColor3 = Color3.fromHex("#52525B")
	closeBtn.Font = CFG.FontBold
	closeBtn.TextSize = 18
	closeBtn.Parent = card

	closeBtn.MouseEnter:Connect(function()
		closeBtn.TextColor3 = Color3.fromHex("#A1A1AA")
	end)
	closeBtn.MouseLeave:Connect(function()
		closeBtn.TextColor3 = Color3.fromHex("#52525B")
	end)

	-- Progress bar
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 0, 2)
	bar.Position = UDim2.new(0, 0, 1, -2)
	bar.BackgroundColor3 = color
	bar.BackgroundTransparency = 0.6
	bar.BorderSizePixel = 0
	bar.Parent = card

	local entry = {
		frame      = frame,
		bar        = bar,
		dismissed  = false,
		thread     = nil,
		barTween   = nil,
		barProgress = 1, -- 0-1 remaining
		startTime  = os.clock(),
		dur        = dur,
	}

	local function startBarTween(remaining)
		if entry.barTween then entry.barTween:Cancel() end
		entry.barTween = TweenService:Create(
			bar,
			TweenInfo.new(remaining, Enum.EasingStyle.Linear),
			{ Size = UDim2.new(0, 0, 0, 2) }
		)
		entry.barTween:Play()
	end

	local function scheduleAutoDismiss(remaining)
		if entry.thread then task.cancel(entry.thread) end
		entry.thread = task.delay(remaining, function()
			dismiss(entry)
		end)
	end

	-- Hover pause/resume
	local hovered = false
	local remaining = dur

	card.MouseEnter:Connect(function()
		hovered = true
		remaining = dur * (bar.Size.X.Scale)
		if entry.barTween then entry.barTween:Pause() end
		if entry.thread then
			task.cancel(entry.thread)
			entry.thread = nil
		end
	end)

	card.MouseLeave:Connect(function()
		hovered = false
		if entry.dismissed then return end
		remaining = dur * (bar.Size.X.Scale)
		startBarTween(remaining)
		scheduleAutoDismiss(remaining)
	end)

	closeBtn.MouseButton1Click:Connect(function()
		dismiss(entry)
	end)

	-- Slide in
	table.insert(active, entry)
	restack()

	-- Start timers
	startBarTween(dur)
	scheduleAutoDismiss(dur)

	return entry
end

-- Public API

function Notify.send(text, kind, duration)
	getGui()
	kind = kind or "default"

	local function spawn()
		if #active >= CFG.MaxVisible then
			table.insert(queue, spawn)
			return
		end
		build(text, nil, kind, duration)
	end

	task.spawn(spawn)
end

function Notify.sendtitled(title, text, kind, duration)
	getGui()
	kind = kind or "default"

	local function spawn()
		if #active >= CFG.MaxVisible then
			table.insert(queue, spawn)
			return
		end
		build(text, title, kind, duration)
	end

	task.spawn(spawn)
end

function Notify.dismissAll()
	for _, entry in ipairs(active) do
		dismiss(entry)
	end
	queue = {}
end
