--[[
    Bundle.lua - SkeetUI + Graphics + demo in ONE script (no ModuleScripts needed).
    Run it with:  loadstring(<this file's source>)()
    See Loader.lua for the one-liner.
]]

local __mods, __cache = {}, {}
local function __require(name)
	if __cache[name] == nil then
		__cache[name] = __mods[name]()
	end
	return __cache[name]
end

-------------------------------------------------------------------- SkeetUI
__mods.SkeetUI = function()
--!nocheck
--[[
    SkeetUI - a gamesense/skeet-styled UI library for Roblox (Luau)

    Setup (Roblox Studio):
      1. Insert a ModuleScript named "SkeetUI" (e.g. in StarterPlayerScripts) and paste this file in it.
      2. Require it from a LocalScript (see Example.client.lua).

    API overview:
      local Window = Library:CreateWindow({ Title = "...", Size = Vector2.new(620, 420), ToggleKey = Enum.KeyCode.RightShift })
      local Tab    = Window:AddTab("Main")
      local Group  = Tab:AddGroup("General", "Left")        -- "Left" | "Right"

      Group:AddToggle(flag, { Text, Default, Callback, Color = Color3 })      -- Color adds a color picker swatch
      Group:AddSlider(flag, { Text, Min, Max, Default, Increment, Suffix, Callback })
      Group:AddDropdown(flag, { Text, Values, Default, Multi, Callback })
      Group:AddKeybind(flag, { Text, Default = "E", Mode = "Toggle"|"Hold", Callback })
      Group:AddTextbox(flag, { Text, Default, Placeholder, Callback })
      Group:AddColorPicker(flag, { Text, Default, Callback })
      Group:AddButton(text, callback)
      Group:AddLabel(text)

      Library.Flags[flag]            -- current value of any option
      Library.Options[flag]          -- the option object  (:Set(v), :OnChanged(fn), .Value)
      Library:Notify(text, seconds)
      Library:SetWatermark(text)     -- Library:SetWatermark(nil) hides it
      Library:ExportConfig() / Library:ImportConfig(json)   -- JSON string in/out
      Library:Unload()
]]

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")

local Library = {
	Flags = {},
	Options = {},
	Font = Enum.Font.SourceSansSemibold,
	TextSize = 15,
	_conns = {},
}

local THEME = {
	Outer = Color3.fromRGB(10, 10, 10),
	Line = Color3.fromRGB(60, 60, 60),
	Border = Color3.fromRGB(40, 40, 40),
	Background = Color3.fromRGB(18, 18, 18),
	Sidebar = Color3.fromRGB(12, 12, 12),
	Group = Color3.fromRGB(48, 48, 48),
	Control = Color3.fromRGB(43, 43, 43),
	ControlHover = Color3.fromRGB(56, 56, 56),
	Text = Color3.fromRGB(190, 190, 190),
	TextDim = Color3.fromRGB(125, 125, 125),
	TextBright = Color3.fromRGB(235, 235, 235),
	Accent = Color3.fromRGB(149, 184, 6),
	AccentDark = Color3.fromRGB(105, 130, 4),
}

local GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(55, 177, 218)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(201, 84, 192)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(204, 227, 53)),
})

local LEFT = Enum.TextXAlignment.Left
local RIGHT = Enum.TextXAlignment.Right
local CENTER = Enum.TextXAlignment.Center

---------------------------------------------------------------- helpers
local function connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(Library._conns, c)
	return c
end

local function New(class, props, children)
	local inst = Instance.new(class)
	if inst:IsA("GuiObject") then
		inst.BorderSizePixel = 0
	end
	if class == "TextLabel" or class == "TextButton" or class == "TextBox" then
		inst.Font = Library.Font
		inst.TextSize = Library.TextSize
		inst.TextColor3 = THEME.Text
		inst.BackgroundTransparency = 1
		inst.TextXAlignment = LEFT
		if class == "TextButton" then
			inst.AutoButtonColor = false
			inst.Text = ""
		end
	end
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
		end
	end
	for _, ch in ipairs(children or {}) do
		ch.Parent = inst
	end
	inst.Parent = parent
	return inst
end

local function Pad(l, t, r, b)
	return New("UIPadding", {
		PaddingLeft = UDim.new(0, l or 0),
		PaddingTop = UDim.new(0, t or 0),
		PaddingRight = UDim.new(0, r or 0),
		PaddingBottom = UDim.new(0, b or 0),
	})
end

local function GradBar(parent, height)
	local f = New("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 0, height or 2),
		ZIndex = 5,
		Parent = parent,
	})
	New("UIGradient", { Color = GRADIENT, Parent = f })
	return f
end

-- vertical accent gradient fill
local function AccentFill(parent)
	local f = New("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	})
	New("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(THEME.Accent, THEME.AccentDark),
		Parent = f,
	})
	return f
end

-- 3-layer panel (black border, grey border, background)
local function Panel(parent, size)
	local outer = New("Frame", {
		BackgroundColor3 = THEME.Outer,
		Size = UDim2.fromOffset(size.X, size.Y),
		Parent = parent,
	})
	local mid = New("Frame", {
		BackgroundColor3 = THEME.Group,
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		Parent = outer,
	})
	local inner = New("Frame", {
		BackgroundColor3 = THEME.Background,
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		Parent = mid,
	})
	return outer, inner
end

local function isPress(i)
	return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end

local function isMove(i)
	return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch
end

-- calls onMove(position) while the pointer is held on `handle`
local function Dragger(handle, onMove)
	local active = false
	handle.InputBegan:Connect(function(i)
		if isPress(i) then
			active = true
			onMove(i.Position)
		end
	end)
	connect(UIS.InputChanged, function(i)
		if active and isMove(i) then
			onMove(i.Position)
		end
	end)
	connect(UIS.InputEnded, function(i)
		if isPress(i) then
			active = false
		end
	end)
end

local function MakeDraggable(handle, target)
	local dragging, startMouse, startPos = false, nil, nil
	handle.InputBegan:Connect(function(i)
		if isPress(i) then
			dragging, startMouse, startPos = true, i.Position, target.Position
		end
	end)
	connect(UIS.InputChanged, function(i)
		if dragging and isMove(i) then
			local d = i.Position - startMouse
			target.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + d.X,
				startPos.Y.Scale, startPos.Y.Offset + d.Y
			)
		end
	end)
	connect(UIS.InputEnded, function(i)
		if isPress(i) then
			dragging = false
		end
	end)
end

---------------------------------------------------------------- popups
local function ClosePopup()
	if Library._popup then
		Library._popup.Visible = false
		Library._popup = nil
	end
	if Library.Catcher then
		Library.Catcher.Visible = false
	end
end

local function OpenPopup(frame)
	ClosePopup()
	Library._popup = frame
	frame.Visible = true
	Library.Catcher.Visible = true
end

---------------------------------------------------------------- option base
local function Fire(obj)
	if obj.Flag then
		Library.Flags[obj.Flag] = obj.Value
	end
	if obj.Callback then
		task.spawn(obj.Callback, obj.Value)
	end
	for _, fn in ipairs(obj._changed) do
		task.spawn(fn, obj.Value)
	end
end

local function Base(flag, o, value, typ)
	local obj = { Flag = flag, Value = value, Callback = o.Callback, _changed = {}, Type = typ }
	function obj:OnChanged(fn)
		table.insert(self._changed, fn)
	end
	if flag then
		Library.Flags[flag] = value
		Library.Options[flag] = obj
	end
	return obj
end

---------------------------------------------------------------- init
function Library:_Init()
	if self.Gui then
		return
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.Gui = New("ScreenGui", {
		Name = "SkeetUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 1000,
		Parent = playerGui,
	})
	self.Catcher = New("TextButton", {
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 90,
		Parent = self.Gui,
	})
	self.Catcher.MouseButton1Click:Connect(ClosePopup)
	self.Catcher.MouseButton2Click:Connect(ClosePopup)

	self.NotifyHolder = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(320, 400),
		ZIndex = 120,
		Parent = self.Gui,
	}, {
		New("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
end

---------------------------------------------------------------- notifications / watermark
function Library:Notify(text, duration)
	self:_Init()
	local w = TextService:GetTextSize(text, self.TextSize, self.Font, Vector2.new(1000, 100)).X + 22
	local outer, inner = Panel(self.NotifyHolder, Vector2.new(w, 26))
	outer.ZIndex = 120
	GradBar(inner, 2)
	New("TextLabel", {
		Text = text,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(9, 1),
		TextColor3 = THEME.TextBright,
		Parent = inner,
	})
	task.delay(duration or 3, function()
		if outer.Parent then
			outer:Destroy()
		end
	end)
end

function Library:SetWatermark(text)
	self:_Init()
	if not text then
		if self._wm then
			self._wm.Visible = false
		end
		return
	end
	self._wmText = text
	if not self._wm then
		local outer = New("Frame", {
			BackgroundColor3 = THEME.Outer,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 12),
			Size = UDim2.fromOffset(0, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			ZIndex = 110,
			Parent = self.Gui,
		}, { Pad(1, 1, 1, 1) })
		local inner = New("Frame", {
			BackgroundColor3 = THEME.Background,
			Size = UDim2.fromOffset(0, 22),
			AutomaticSize = Enum.AutomaticSize.X,
			Parent = outer,
		})
		GradBar(inner, 2)
		self._wmLabel = New("TextLabel", {
			Size = UDim2.fromOffset(0, 22),
			AutomaticSize = Enum.AutomaticSize.X,
			TextColor3 = THEME.TextBright,
			Parent = inner,
		}, { Pad(9, 2, 9, 0) })
		self._wm = outer

		local acc, frames, fps = 0, 0, 60
		connect(RunService.RenderStepped, function(dt)
			acc += dt
			frames += 1
			if acc >= 0.5 then
				fps = math.floor(frames / acc + 0.5)
				acc, frames = 0, 0
				self._wmLabel.Text = (self._wmText or "") .. " | " .. fps .. " fps"
			end
		end)
	end
	self._wm.Visible = true
	self._wmLabel.Text = text
end

---------------------------------------------------------------- config
function Library:ExportConfig()
	local data = {}
	for flag, opt in pairs(self.Options) do
		local v = opt.Value
		if typeof(v) == "Color3" then
			v = { __color = v:ToHex() }
		elseif typeof(v) == "EnumItem" then
			v = { __key = v.Name }
		elseif v == nil then
			continue
		end
		data[flag] = v
	end
	return HttpService:JSONEncode(data)
end

function Library:ImportConfig(json)
	local ok, data = pcall(HttpService.JSONDecode, HttpService, json)
	if not ok or type(data) ~= "table" then
		return false
	end
	for flag, v in pairs(data) do
		local opt = self.Options[flag]
		if opt and opt.Set then
			if type(v) == "table" and v.__color then
				v = Color3.fromHex(v.__color)
			elseif type(v) == "table" and v.__key then
				v = v.__key
			end
			pcall(opt.Set, opt, v)
		end
	end
	return true
end

function Library:Unload()
	for _, c in ipairs(self._conns) do
		c:Disconnect()
	end
	table.clear(self._conns)
	if self.Gui then
		self.Gui:Destroy()
	end
	self.Gui, self.Catcher, self._wm, self._popup = nil, nil, nil, nil
	table.clear(self.Flags)
	table.clear(self.Options)
end

---------------------------------------------------------------- color picker
local function AddColorPicker(parent, flag, o, rightOffset)
	o = o or {}
	local P = Base(flag, o, o.Default or Color3.new(1, 1, 1), "ColorPicker")
	local h, s, v = P.Value:ToHSV()

	local swOuter = New("Frame", {
		BackgroundColor3 = THEME.Outer,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -(rightOffset or 0), 0, 3),
		Size = UDim2.fromOffset(20, 10),
		Parent = parent,
	})
	local sw = New("TextButton", {
		BackgroundColor3 = P.Value,
		BackgroundTransparency = 0,
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		Parent = swOuter,
	})

	local pop, inner = Panel(Library.Gui, Vector2.new(164, 132))
	pop.Visible = false
	pop.ZIndex = 100

	local sv = New("Frame", {
		BackgroundColor3 = Color3.fromHSV(h, 1, 1),
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(144, 90),
		Parent = inner,
	})
	local white = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), Parent = sv })
	New("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = white })
	local black = New("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.fromScale(1, 1), Parent = sv })
	New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = black })
	local svMark = New("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(5, 5),
		ZIndex = 3,
		Parent = sv,
	}, { New("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1 }) })

	local hue = New("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(8, 106),
		Size = UDim2.fromOffset(144, 12),
		Parent = inner,
	})
	New("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
			ColorSequenceKeypoint.new(1 / 6, Color3.fromHSV(1 / 6, 1, 1)),
			ColorSequenceKeypoint.new(2 / 6, Color3.fromHSV(2 / 6, 1, 1)),
			ColorSequenceKeypoint.new(3 / 6, Color3.fromHSV(3 / 6, 1, 1)),
			ColorSequenceKeypoint.new(4 / 6, Color3.fromHSV(4 / 6, 1, 1)),
			ColorSequenceKeypoint.new(5 / 6, Color3.fromHSV(5 / 6, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
		}),
		Parent = hue,
	})
	local hueMark = New("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(3, 14),
		ZIndex = 3,
		Parent = hue,
	}, { New("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1 }) })

	local function update(fire)
		P.Value = Color3.fromHSV(h, s, v)
		sw.BackgroundColor3 = P.Value
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		svMark.Position = UDim2.fromScale(s, 1 - v)
		hueMark.Position = UDim2.fromScale(h, 0.5)
		if fire then
			Fire(P)
		end
	end
	update(false)

	Dragger(sv, function(pos)
		s = math.clamp((pos.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
		v = 1 - math.clamp((pos.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
		update(true)
	end)
	Dragger(hue, function(pos)
		h = math.clamp((pos.X - hue.AbsolutePosition.X) / hue.AbsoluteSize.X, 0, 0.999)
		update(true)
	end)

	function P:Set(c)
		if typeof(c) == "string" then
			c = Color3.fromHex(c)
		end
		h, s, v = c:ToHSV()
		update(true)
	end

	sw.MouseButton1Click:Connect(function()
		local ap = sw.AbsolutePosition
		pop.Position = UDim2.fromOffset(math.max(ap.X - 142, 4), ap.Y + 14)
		OpenPopup(pop)
	end)
	return P
end

---------------------------------------------------------------- window
function Library:CreateWindow(opts)
	opts = opts or {}
	self:_Init()

	local size = opts.Size or Vector2.new(620, 420)
	local Window = { Tabs = {}, ToggleKey = opts.ToggleKey or Enum.KeyCode.RightShift }

	local root = New("Frame", {
		Name = "Window",
		BackgroundColor3 = THEME.Outer,
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.new(0.5, -size.X / 2, 0.5, -size.Y / 2),
		ZIndex = 1,
		Parent = self.Gui,
	})
	local function layer(color, inset, z)
		return New("Frame", {
			BackgroundColor3 = color,
			Position = UDim2.fromOffset(inset, inset),
			Size = UDim2.new(1, -inset * 2, 1, -inset * 2),
			ZIndex = z,
			Parent = root,
		})
	end
	layer(THEME.Line, 1, 1)
	layer(THEME.Border, 2, 2)
	layer(THEME.Line, 5, 3)
	local body = layer(THEME.Background, 6, 4)
	body.ClipsDescendants = true

	local modal = New("TextButton", { Size = UDim2.new(), Modal = true, Parent = root })

	GradBar(body, 2)

	local dragZone = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), ZIndex = 3, Parent = body })
	MakeDraggable(dragZone, root)

	-- sidebar
	local sidebar = New("Frame", {
		BackgroundColor3 = THEME.Sidebar,
		Position = UDim2.fromOffset(0, 2),
		Size = UDim2.new(0, 68, 1, -2),
		Parent = body,
	}, { New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }) })
	New("Frame", {
		BackgroundColor3 = THEME.Border,
		Position = UDim2.new(0, 67, 0, 2),
		Size = UDim2.new(0, 1, 1, -2),
		ZIndex = 2,
		Parent = body,
	})

	local pages = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(68, 2),
		Size = UDim2.new(1, -68, 1, -2),
		Parent = body,
	})

	local titleLabel = New("TextLabel", {
		Text = opts.Title or "",
		TextColor3 = THEME.TextDim,
		TextXAlignment = RIGHT,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -4),
		Size = UDim2.fromOffset(200, 16),
		ZIndex = 2,
		Parent = pages,
	})

	function Window:SetTitle(t)
		titleLabel.Text = t
	end

	function Window:Toggle(v)
		if v == nil then
			v = not root.Visible
		end
		root.Visible = v
		modal.Modal = v
		ClosePopup()
	end

	connect(UIS.InputBegan, function(i, gp)
		if not gp and i.KeyCode == Window.ToggleKey then
			Window:Toggle()
		end
	end)

	function Window:AddTab(name)
		local Tab = { Name = name, _n = 0 }

		local btn = New("TextButton", {
			Text = name,
			TextXAlignment = CENTER,
			BackgroundColor3 = THEME.Background,
			Size = UDim2.new(1, 0, 0, 64),
			LayoutOrder = #Window.Tabs + 1,
			Parent = sidebar,
		})
		local ind = New("Frame", {
			BackgroundColor3 = THEME.Accent,
			Position = UDim2.fromOffset(0, 8),
			Size = UDim2.new(0, 2, 1, -16),
			Visible = false,
			Parent = btn,
		})
		New("Frame", {
			BackgroundColor3 = THEME.Border,
			Position = UDim2.new(0, 0, 1, -1),
			Size = UDim2.new(1, 0, 0, 1),
			Parent = btn,
		})

		local page = New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			Parent = pages,
		})

		local function column(pos, sz)
			return New("ScrollingFrame", {
				BackgroundTransparency = 1,
				Position = pos,
				Size = sz,
				ScrollBarThickness = 2,
				ScrollBarImageColor3 = THEME.Accent,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				Parent = page,
			}, {
				New("UIListLayout", { Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder }),
				Pad(0, 10, 6, 10),
			})
		end
		Tab.Left = column(UDim2.fromOffset(10, 16), UDim2.new(0.5, -16, 1, -16))
		Tab.Right = column(UDim2.new(0.5, 6, 0, 16), UDim2.new(0.5, -16, 1, -16))

		function Tab:_SetActive(a)
			page.Visible = a
			ind.Visible = a
			btn.BackgroundTransparency = a and 0 or 1
			btn.TextColor3 = a and THEME.TextBright or THEME.TextDim
		end
		function Tab:Select()
			for _, t in ipairs(Window.Tabs) do
				t:_SetActive(t == self)
			end
			ClosePopup()
		end
		btn.MouseButton1Click:Connect(function()
			Tab:Select()
		end)
		btn.MouseEnter:Connect(function()
			if not page.Visible then
				btn.TextColor3 = THEME.Text
			end
		end)
		btn.MouseLeave:Connect(function()
			if not page.Visible then
				btn.TextColor3 = THEME.TextDim
			end
		end)

		---------------------------------------------------------------- groups
		function Tab:AddGroup(title, side)
			local col = (side == "Right") and self.Right or self.Left
			self._n += 1

			local outer = New("Frame", {
				BackgroundColor3 = THEME.Outer,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = self._n,
				Parent = col,
			}, { Pad(1, 1, 1, 1) })
			local border = New("Frame", {
				BackgroundColor3 = THEME.Group,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Parent = outer,
			}, { Pad(1, 1, 1, 1) })
			local content = New("Frame", {
				BackgroundColor3 = THEME.Background,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Parent = border,
			}, {
				Pad(12, 16, 12, 10),
				New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
			})
			New("TextLabel", {
				Text = title,
				BackgroundColor3 = THEME.Background,
				BackgroundTransparency = 0,
				TextColor3 = THEME.TextBright,
				Position = UDim2.fromOffset(9, -9),
				Size = UDim2.fromOffset(0, 16),
				AutomaticSize = Enum.AutomaticSize.X,
				ZIndex = 3,
				Parent = outer,
			}, { Pad(4, 0, 4, 0) })

			local Group = {}
			local order = 0
			local function row(height)
				order += 1
				return New("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, height),
					LayoutOrder = order,
					Parent = content,
				})
			end

			function Group:AddLabel(text)
				local r = row(16)
				local l = New("TextLabel", {
					Text = text,
					TextColor3 = THEME.TextDim,
					Size = UDim2.fromScale(1, 1),
					Parent = r,
				})
				return { SetText = function(_, t) l.Text = t end }
			end

			-------------------------------------------------------- toggle
			function Group:AddToggle(flag, o)
				o = o or {}
				local T = Base(flag, o, o.Default == true, "Toggle")
				local r = row(16)
				local box = New("Frame", {
					BackgroundColor3 = THEME.Outer,
					Position = UDim2.fromOffset(0, 3),
					Size = UDim2.fromOffset(10, 10),
					Parent = r,
				})
				local fill = New("Frame", {
					BackgroundColor3 = Color3.new(1, 1, 1),
					Position = UDim2.fromOffset(1, 1),
					Size = UDim2.new(1, -2, 1, -2),
					Parent = box,
				})
				local grad = New("UIGradient", { Rotation = 90, Parent = fill })
				local lbl = New("TextLabel", {
					Text = o.Text or tostring(flag),
					Position = UDim2.fromOffset(16, 0),
					Size = UDim2.new(1, -16, 1, 0),
					Parent = r,
				})
				local btn = New("TextButton", {
					Size = UDim2.new(1, o.Color and -26 or 0, 1, 0),
					ZIndex = 2,
					Parent = r,
				})
				local function render()
					if T.Value then
						grad.Color = ColorSequence.new(THEME.Accent, THEME.AccentDark)
						lbl.TextColor3 = THEME.TextBright
					else
						grad.Color = ColorSequence.new(Color3.fromRGB(56, 56, 56), Color3.fromRGB(40, 40, 40))
						lbl.TextColor3 = THEME.Text
					end
				end
				render()
				function T:Set(val)
					self.Value = val and true or false
					render()
					Fire(self)
				end
				btn.MouseButton1Click:Connect(function()
					T:Set(not T.Value)
				end)
				if o.Color then
					T.ColorPicker = AddColorPicker(r, o.ColorFlag or (flag and (flag .. "_color")), { Default = o.Color, Callback = o.ColorCallback })
				end
				return T
			end

			-------------------------------------------------------- slider
			function Group:AddSlider(flag, o)
				o = o or {}
				local min, max = o.Min or 0, o.Max or 100
				local inc = o.Increment or 1
				local S = Base(flag, o, math.clamp(o.Default or min, min, max), "Slider")
				local r = row(30)
				New("TextLabel", { Text = o.Text or tostring(flag), Size = UDim2.new(1, 0, 0, 14), Parent = r })
				local valLbl = New("TextLabel", {
					TextXAlignment = RIGHT,
					TextColor3 = THEME.TextBright,
					Size = UDim2.new(1, 0, 0, 14),
					Parent = r,
				})
				local bar = New("Frame", {
					BackgroundColor3 = THEME.Outer,
					Position = UDim2.fromOffset(0, 17),
					Size = UDim2.new(1, 0, 0, 9),
					Parent = r,
				})
				local inner = New("Frame", {
					BackgroundColor3 = THEME.Control,
					Position = UDim2.fromOffset(1, 1),
					Size = UDim2.new(1, -2, 1, -2),
					Parent = bar,
				})
				local fillHolder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(0, 1), ClipsDescendants = true, Parent = inner })
				AccentFill(fillHolder)
				local function render()
					local t = (S.Value - min) / (max - min)
					fillHolder.Size = UDim2.fromScale(t, 1)
					valLbl.Text = tostring(math.floor(S.Value * 1000 + 0.5) / 1000) .. (o.Suffix or "")
				end
				render()
				function S:Set(val, force)
					val = math.clamp(math.floor(val / inc + 0.5) * inc, min, max)
					if val == self.Value and not force then
						return
					end
					self.Value = val
					render()
					Fire(self)
				end
				Dragger(bar, function(pos)
					local t = math.clamp((pos.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
					S:Set(min + (max - min) * t)
				end)
				return S
			end

			-------------------------------------------------------- dropdown
			function Group:AddDropdown(flag, o)
				o = o or {}
				local multi = o.Multi == true
				local values = o.Values or {}
				local init
				if multi then
					init = {}
					for _, n in ipairs(o.Default or {}) do
						init[n] = true
					end
				else
					init = o.Default
					if type(init) == "number" then
						init = values[init]
					end
					init = init or values[1]
				end
				local D = Base(flag, o, init, "Dropdown")
				D.Values = values

				local r = row(38)
				New("TextLabel", { Text = o.Text or tostring(flag), Size = UDim2.new(1, 0, 0, 14), Parent = r })
				local box = New("Frame", {
					BackgroundColor3 = THEME.Outer,
					Position = UDim2.fromOffset(0, 17),
					Size = UDim2.new(1, 0, 0, 20),
					Parent = r,
				})
				local btn = New("TextButton", {
					BackgroundColor3 = THEME.Control,
					BackgroundTransparency = 0,
					Position = UDim2.fromOffset(1, 1),
					Size = UDim2.new(1, -2, 1, -2),
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextColor3 = THEME.TextBright,
					Parent = box,
				}, { Pad(7, 0, 20, 0) })
				New("TextLabel", {
					Text = "v",
					TextSize = 11,
					TextXAlignment = CENTER,
					TextColor3 = THEME.TextDim,
					Position = UDim2.new(1, -16, 0, 0),
					Size = UDim2.new(0, 14, 1, 0),
					Parent = box,
				})
				btn.MouseEnter:Connect(function() btn.BackgroundColor3 = THEME.ControlHover end)
				btn.MouseLeave:Connect(function() btn.BackgroundColor3 = THEME.Control end)

				local pop, popIn = Panel(Library.Gui, Vector2.new(100, 24))
				pop.Visible = false
				pop.ZIndex = 100
				New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = popIn })
				local items = {}

				local function display()
					if multi then
						local t = {}
						for _, n in ipairs(D.Values) do
							if D.Value[n] then
								t[#t + 1] = n
							end
						end
						return #t > 0 and table.concat(t, ", ") or "None"
					end
					return tostring(D.Value or "None")
				end
				local function refresh()
					btn.Text = display()
					for name, b in pairs(items) do
						local sel = multi and D.Value[name] or D.Value == name
						b.TextColor3 = sel and THEME.Accent or THEME.Text
					end
				end
				local function rebuild()
					for _, b in pairs(items) do
						b:Destroy()
					end
					items = {}
					for i, name in ipairs(D.Values) do
						local b = New("TextButton", {
							Text = name,
							BackgroundColor3 = THEME.Control,
							Size = UDim2.new(1, 0, 0, 18),
							LayoutOrder = i,
							Parent = popIn,
						}, { Pad(7, 0, 0, 0) })
						b.MouseEnter:Connect(function() b.BackgroundTransparency = 0 end)
						b.MouseLeave:Connect(function() b.BackgroundTransparency = 1 end)
						b.MouseButton1Click:Connect(function()
							if multi then
								D.Value[name] = (not D.Value[name]) or nil
							else
								D.Value = name
								ClosePopup()
							end
							refresh()
							Fire(D)
						end)
						items[name] = b
					end
					refresh()
				end
				rebuild()

				function D:Set(val)
					if multi then
						local nv = {}
						if type(val) == "table" then
							for k, x in pairs(val) do
								if type(k) == "number" then nv[x] = true elseif x then nv[k] = true end
							end
						end
						self.Value = nv
					elseif table.find(self.Values, val) then
						self.Value = val
					end
					refresh()
					Fire(self)
				end
				function D:SetValues(vals)
					self.Values = vals
					if not multi and not table.find(vals, self.Value) then
						self.Value = vals[1]
					end
					rebuild()
				end

				btn.MouseButton1Click:Connect(function()
					pop.Size = UDim2.fromOffset(box.AbsoluteSize.X, #D.Values * 18 + 4)
					pop.Position = UDim2.fromOffset(box.AbsolutePosition.X, box.AbsolutePosition.Y + box.AbsoluteSize.Y - 1)
					OpenPopup(pop)
				end)
				return D
			end

			-------------------------------------------------------- keybind
			function Group:AddKeybind(flag, o)
				o = o or {}
				local default = o.Default
				if type(default) == "string" then
					default = Enum.KeyCode[default]
				end
				local K = Base(flag, o, default, "Keybind")
				K.Mode = o.Mode or "Toggle"
				K.State = K.Mode == "Always"
				if flag then
					Library.Flags[flag] = K.State
				end

				local r = row(16)
				New("TextLabel", { Text = o.Text or tostring(flag), Size = UDim2.fromScale(1, 1), Parent = r })
				local btn = New("TextButton", {
					TextXAlignment = RIGHT,
					TextColor3 = THEME.TextDim,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromOffset(70, 16),
					Parent = r,
				})
				local function render()
					btn.Text = K.Listening and "[...]" or ("[" .. (K.Value and K.Value.Name or "None") .. "]")
				end
				render()

				function K:Set(key)
					if type(key) == "string" then
						key = Enum.KeyCode[key]
					end
					self.Value = key
					render()
				end
				btn.MouseButton1Click:Connect(function()
					K.Listening = true
					render()
				end)

				local function setState(st)
					K.State = st
					if flag then
						Library.Flags[flag] = st
					end
					if K.Callback then
						task.spawn(K.Callback, st)
					end
					for _, fn in ipairs(K._changed) do
						task.spawn(fn, st)
					end
				end

				connect(UIS.InputBegan, function(i, gp)
					if K.Listening then
						if i.UserInputType == Enum.UserInputType.Keyboard then
							K.Listening = false
							K.Value = (i.KeyCode ~= Enum.KeyCode.Escape) and i.KeyCode or nil
							render()
						end
						return
					end
					if gp or not K.Value or i.KeyCode ~= K.Value or K.Mode == "Always" then
						return
					end
					if K.Mode == "Hold" then
						setState(true)
					else
						setState(not K.State)
					end
				end)
				connect(UIS.InputEnded, function(i)
					if K.Mode == "Hold" and K.Value and i.KeyCode == K.Value then
						setState(false)
					end
				end)
				return K
			end

			-------------------------------------------------------- textbox
			function Group:AddTextbox(flag, o)
				o = o or {}
				local X = Base(flag, o, o.Default or "", "Textbox")
				local r = row(38)
				New("TextLabel", { Text = o.Text or tostring(flag), Size = UDim2.new(1, 0, 0, 14), Parent = r })
				local box = New("Frame", {
					BackgroundColor3 = THEME.Outer,
					Position = UDim2.fromOffset(0, 17),
					Size = UDim2.new(1, 0, 0, 20),
					Parent = r,
				})
				local tb = New("TextBox", {
					BackgroundColor3 = THEME.Control,
					BackgroundTransparency = 0,
					Text = X.Value,
					PlaceholderText = o.Placeholder or "",
					PlaceholderColor3 = THEME.TextDim,
					TextColor3 = THEME.TextBright,
					ClearTextOnFocus = false,
					Position = UDim2.fromOffset(1, 1),
					Size = UDim2.new(1, -2, 1, -2),
					Parent = box,
				}, { Pad(7, 0, 7, 0) })
				function X:Set(t)
					self.Value = tostring(t)
					tb.Text = self.Value
					Fire(self)
				end
				tb.FocusLost:Connect(function()
					X.Value = tb.Text
					Fire(X)
				end)
				return X
			end

			-------------------------------------------------------- color picker (own row)
			function Group:AddColorPicker(flag, o)
				o = o or {}
				local r = row(16)
				New("TextLabel", { Text = o.Text or tostring(flag), Size = UDim2.fromScale(1, 1), Parent = r })
				return AddColorPicker(r, flag, o, 0)
			end

			-------------------------------------------------------- button
			function Group:AddButton(text, callback)
				local r = row(22)
				local box = New("Frame", { BackgroundColor3 = THEME.Outer, Size = UDim2.fromScale(1, 1), Parent = r })
				local b = New("TextButton", {
					Text = text,
					TextXAlignment = CENTER,
					TextColor3 = THEME.TextBright,
					BackgroundColor3 = THEME.Control,
					BackgroundTransparency = 0,
					Position = UDim2.fromOffset(1, 1),
					Size = UDim2.new(1, -2, 1, -2),
					Parent = box,
				})
				New("UIGradient", {
					Rotation = 90,
					Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)),
					Parent = b,
				})
				b.MouseEnter:Connect(function() b.BackgroundColor3 = THEME.ControlHover end)
				b.MouseLeave:Connect(function() b.BackgroundColor3 = THEME.Control end)
				b.MouseButton1Click:Connect(function()
					if callback then
						task.spawn(callback)
					end
				end)
				return b
			end

			return Group
		end

		table.insert(Window.Tabs, Tab)
		if #Window.Tabs == 1 then
			Tab:Select()
		end
		return Tab
	end

	return Window
end

return Library

end

-------------------------------------------------------------------- Graphics
__mods.Graphics = function()
--!nocheck
--[[
    Graphics.lua - client-side graphics settings for SkeetUI
    FPS booster, texture remover, shader presets, skyboxes.

    Everything here only changes what the LOCAL player sees (Lighting / workspace on the client)
    and every change is tracked, so turning a feature off restores the original values.

    Setup: ModuleScript named "Graphics" next to the SkeetUI ModuleScript (see Example.client.lua).

    Usage:
        local Graphics = require(script.Parent:WaitForChild("Graphics"))
        Graphics:BuildTabs(Library, Window)          -- adds the FPS / Textures / Shaders / Sky tabs

    Or use the engine directly:
        Graphics:SetFeature("Booster", "shadows", true)
        Graphics.Shaders:Apply("High Quality")
        Graphics.Sky:Apply("Sunset")
        Graphics:AddSkybox("My Sky", { Faces = { Bk = "rbxassetid://0", Dn = "...", Ft = "...", Lf = "...", Rt = "...", Up = "..." } })
        Graphics:Destroy()                           -- revert everything
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local Graphics = {}
local PREFIX = "SkeetUI_"

---------------------------------------------------------------- change tracking
local function weak()
	return setmetatable({}, { __mode = "k" })
end

local function newTracker()
	return { props = weak(), parents = weak(), conns = {} }
end

-- set a property but remember the original so restore() can undo it
local function track(tr, inst, prop, value)
	local ok, cur = pcall(function()
		return inst[prop]
	end)
	if not ok then
		return
	end
	local rec = tr.props[inst]
	if not rec then
		rec = {}
		tr.props[inst] = rec
	end
	if rec[prop] == nil then
		rec[prop] = { cur }
	end
	pcall(function()
		inst[prop] = value
	end)
end

-- remove an instance from the game but remember where it was
local function detach(tr, inst)
	local p = inst.Parent
	if p then
		tr.parents[inst] = p
		inst.Parent = nil
	end
end

local function restore(tr)
	for _, c in ipairs(tr.conns) do
		c:Disconnect()
	end
	tr.conns = {}
	for inst, parent in pairs(tr.parents) do
		if parent == game or parent:IsDescendantOf(game) then
			pcall(function()
				inst.Parent = parent
			end)
		end
	end
	for inst, rec in pairs(tr.props) do
		for prop, wrapped in pairs(rec) do
			pcall(function()
				inst[prop] = wrapped[1]
			end)
		end
	end
	tr.props, tr.parents = weak(), weak()
end

local function isOurs(d)
	return string.sub(d.Name, 1, #PREFIX) == PREFIX
end

local function isPart(d)
	return d:IsA("BasePart") and not d:IsA("Terrain")
end

---------------------------------------------------------------- feature factory
-- def.Global(tr)   : runs once when enabled
-- def.Inst(tr, d)  : runs for every existing + newly added workspace descendant
local function Feature(def)
	local F = { Enabled = false, tr = newTracker(), token = 0 }

	function F:Enable()
		if self.Enabled then
			return
		end
		self.Enabled = true
		self.token += 1
		local token = self.token

		if def.Global then
			pcall(def.Global, self.tr)
		end
		if def.Inst then
			table.insert(self.tr.conns, workspace.DescendantAdded:Connect(function(d)
				pcall(def.Inst, self.tr, d)
			end))
			task.spawn(function()
				local list = workspace:GetDescendants()
				for i, d in ipairs(list) do
					if self.token ~= token or not self.Enabled then
						return
					end
					pcall(def.Inst, self.tr, d)
					if i % 300 == 0 then
						task.wait()
					end
				end
			end)
		end
	end

	function F:Disable()
		if not self.Enabled then
			return
		end
		self.Enabled = false
		self.token += 1
		restore(self.tr)
	end

	return F
end

---------------------------------------------------------------- FPS booster features
local PARTICLE_CLASSES = { "ParticleEmitter", "Trail", "Beam", "Fire", "Smoke", "Sparkles" }

local BoosterDefs = {
	shadows = {
		Global = function(tr)
			track(tr, Lighting, "GlobalShadows", false)
		end,
		Inst = function(tr, d)
			if isPart(d) then
				track(tr, d, "CastShadow", false)
			elseif d:IsA("Light") then
				track(tr, d, "Shadows", false)
			end
		end,
	},
	particles = {
		Inst = function(tr, d)
			for _, class in ipairs(PARTICLE_CLASSES) do
				if d:IsA(class) then
					track(tr, d, "Enabled", false)
					return
				end
			end
		end,
	},
	postfx = {
		Global = function(tr)
			local function handle(d)
				if d:IsA("PostEffect") and not isOurs(d) then
					track(tr, d, "Enabled", false)
				end
			end
			for _, d in ipairs(Lighting:GetChildren()) do
				handle(d)
			end
			table.insert(tr.conns, Lighting.ChildAdded:Connect(handle))
		end,
		Inst = function(tr, d)
			if d:IsA("PostEffect") and not isOurs(d) then
				track(tr, d, "Enabled", false)
			end
		end,
	},
	water = {
		Global = function(tr)
			local t = workspace.Terrain
			track(tr, t, "WaterWaveSize", 0)
			track(tr, t, "WaterWaveSpeed", 0)
			track(tr, t, "WaterReflectance", 0)
		end,
	},
	meshes = {
		Inst = function(tr, d)
			if d:IsA("MeshPart") then
				track(tr, d, "RenderFidelity", Enum.RenderFidelity.Performance)
			end
		end,
	},
	decor = {
		Global = function(tr)
			track(tr, workspace.Terrain, "Decoration", false)
		end,
	},
	quality = {
		Global = function(tr)
			local ok, rendering = pcall(function()
				return settings().Rendering
			end)
			if ok then
				track(tr, rendering, "QualityLevel", Enum.QualityLevel.Level01)
			end
		end,
	},
}

---------------------------------------------------------------- texture removal features
local TextureDefs = {
	decals = {
		Inst = function(tr, d)
			if d:IsA("Decal") then -- also covers Texture
				track(tr, d, "Transparency", 1)
			end
		end,
	},
	surface = {
		Inst = function(tr, d)
			if d:IsA("SurfaceAppearance") then
				detach(tr, d)
			end
		end,
	},
	meshtex = {
		Inst = function(tr, d)
			if d:IsA("MeshPart") then
				track(tr, d, "TextureID", "")
			elseif d:IsA("SpecialMesh") then
				track(tr, d, "TextureId", "")
			end
		end,
	},
	clothing = {
		Inst = function(tr, d)
			if d:IsA("Shirt") then
				track(tr, d, "ShirtTemplate", "")
			elseif d:IsA("Pants") then
				track(tr, d, "PantsTemplate", "")
			elseif d:IsA("ShirtGraphic") then
				track(tr, d, "Graphic", "")
			end
		end,
	},
	flat = {
		Inst = function(tr, d)
			if isPart(d) then
				track(tr, d, "Material", Enum.Material.SmoothPlastic)
			end
		end,
	},
}

Graphics.Features = { Booster = {}, Textures = {} }
for k, def in pairs(BoosterDefs) do
	Graphics.Features.Booster[k] = Feature(def)
end
for k, def in pairs(TextureDefs) do
	Graphics.Features.Textures[k] = Feature(def)
end

function Graphics:SetFeature(kind, key, on)
	local f = self.Features[kind] and self.Features[kind][key]
	if not f then
		return
	end
	if on then
		f:Enable()
	else
		f:Disable()
	end
end

---------------------------------------------------------------- shaders
local function C(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local Shaders = {
	Strength = 1,
	Current = "Off",
	tr = newTracker(),
	Order = {
		"Off", "Low Quality", "Medium Quality", "High Quality", "Ultra Quality",
		"Realistic", "Vibrant", "Cinematic", "Noir (B&W)", "Warm Sunset",
		"Cold Blue", "Dreamy", "Retro", "Night Vision",
	},
	Presets = {
		["Low Quality"] = {
			CC = { Contrast = 0.08, Saturation = 0.1 },
			Light = { ExposureCompensation = 0.1 },
		},
		["Medium Quality"] = {
			Bloom = { Intensity = 0.3, Size = 20, Threshold = 1.6 },
			CC = { Contrast = 0.1, Saturation = 0.15 },
			Rays = { Intensity = 0.08, Spread = 0.6 },
		},
		["High Quality"] = {
			Bloom = { Intensity = 0.4, Size = 30, Threshold = 1.4 },
			CC = { Contrast = 0.12, Saturation = 0.2, Brightness = 0.02, Tint = C(255, 250, 245) },
			Rays = { Intensity = 0.12, Spread = 0.7 },
			Atmo = { Density = 0.28, Offset = 0.2, Color = C(199, 205, 215), Decay = C(106, 112, 125), Glare = 0.2, Haze = 1 },
			Light = { ExposureCompensation = 0.15, ShadowSoftness = 0.2 },
		},
		["Ultra Quality"] = {
			Bloom = { Intensity = 0.55, Size = 36, Threshold = 1.2 },
			CC = { Contrast = 0.18, Saturation = 0.25, Brightness = 0.03, Tint = C(255, 248, 240) },
			Rays = { Intensity = 0.18, Spread = 0.8 },
			DOF = { FarIntensity = 0.15, NearIntensity = 0, FocusDistance = 60, InFocusRadius = 40 },
			Atmo = { Density = 0.32, Offset = 0.25, Color = C(190, 200, 215), Decay = C(100, 110, 125), Glare = 0.4, Haze = 1.4 },
			Light = { ExposureCompensation = 0.25, ShadowSoftness = 0.1 },
		},
		["Realistic"] = {
			Bloom = { Intensity = 0.2, Size = 22, Threshold = 1.8 },
			CC = { Contrast = 0.1, Saturation = -0.05, Tint = C(255, 252, 248) },
			Rays = { Intensity = 0.06, Spread = 0.5 },
			Atmo = { Density = 0.35, Offset = 0, Color = C(200, 205, 210), Decay = C(110, 115, 120), Glare = 0.1, Haze = 1.5 },
			Light = { ExposureCompensation = 0.1, EnvironmentDiffuseScale = 1, EnvironmentSpecularScale = 1 },
		},
		["Vibrant"] = {
			Bloom = { Intensity = 0.35, Size = 26, Threshold = 1.5 },
			CC = { Contrast = 0.15, Saturation = 0.5, Brightness = 0.03 },
			Rays = { Intensity = 0.1, Spread = 0.6 },
		},
		["Cinematic"] = {
			Bloom = { Intensity = 0.4, Size = 30, Threshold = 1.3 },
			CC = { Contrast = 0.25, Saturation = -0.05, Brightness = -0.02, Tint = C(255, 238, 220) },
			DOF = { FarIntensity = 0.25, NearIntensity = 0, FocusDistance = 45, InFocusRadius = 25 },
			Atmo = { Density = 0.3, Offset = 0.3, Color = C(180, 195, 215), Decay = C(90, 100, 120), Glare = 0.3, Haze = 1.2 },
			Light = { ExposureCompensation = -0.1 },
		},
		["Noir (B&W)"] = {
			Bloom = { Intensity = 0.2, Size = 20, Threshold = 1.6 },
			CC = { Contrast = 0.3, Saturation = -1 },
		},
		["Warm Sunset"] = {
			Bloom = { Intensity = 0.4, Size = 30, Threshold = 1.3 },
			CC = { Contrast = 0.1, Saturation = 0.2, Tint = C(255, 210, 170) },
			Rays = { Intensity = 0.2, Spread = 0.9 },
			Light = { ColorShift_Top = C(255, 170, 100) },
		},
		["Cold Blue"] = {
			Bloom = { Intensity = 0.25, Size = 24, Threshold = 1.5 },
			CC = { Contrast = 0.1, Saturation = -0.05, Tint = C(200, 220, 255) },
			Atmo = { Density = 0.3, Offset = 0, Color = C(180, 200, 230), Decay = C(110, 125, 150), Glare = 0.1, Haze = 1.2 },
		},
		["Dreamy"] = {
			Bloom = { Intensity = 0.8, Size = 44, Threshold = 0.9 },
			CC = { Contrast = -0.05, Saturation = 0.15, Brightness = 0.05, Tint = C(255, 240, 250) },
			DOF = { FarIntensity = 0.3, NearIntensity = 0.1, FocusDistance = 30, InFocusRadius = 20 },
			Atmo = { Density = 0.35, Offset = 0.3, Color = C(230, 205, 225), Decay = C(190, 160, 190), Glare = 0.3, Haze = 1.5 },
		},
		["Retro"] = {
			CC = { Contrast = 0.2, Saturation = -0.25, Tint = C(255, 235, 200) },
			Blur = { Size = 1.5 },
		},
		["Night Vision"] = {
			Bloom = { Intensity = 0.5, Size = 24, Threshold = 1.1 },
			CC = { Contrast = 0.3, Saturation = -0.5, Brightness = 0.1, Tint = C(120, 255, 120) },
		},
	},
}

local function make(class, name, props)
	local inst = Instance.new(class)
	inst.Name = PREFIX .. name
	for k, v in pairs(props) do
		pcall(function()
			inst[k] = v
		end)
	end
	inst.Parent = Lighting
	return inst
end

local function clearOurs(parent)
	for _, d in ipairs(parent:GetChildren()) do
		if isOurs(d) and not d:IsA("Sky") then
			d:Destroy()
		end
	end
end

function Shaders:Apply(name)
	restore(self.tr)
	clearOurs(Lighting)
	self.Current = name or "Off"
	local p = self.Presets[self.Current]
	if not p then
		return
	end
	local s = self.Strength
	local white, black = Color3.new(1, 1, 1), Color3.new(0, 0, 0)

	if p.Bloom then
		make("BloomEffect", "Bloom", {
			Intensity = (p.Bloom.Intensity or 0) * s,
			Size = p.Bloom.Size or 24,
			Threshold = p.Bloom.Threshold or 2,
		})
	end
	if p.CC then
		make("ColorCorrectionEffect", "ColorCorrection", {
			Brightness = (p.CC.Brightness or 0) * s,
			Contrast = (p.CC.Contrast or 0) * s,
			Saturation = (p.CC.Saturation or 0) * s,
			TintColor = white:Lerp(p.CC.Tint or white, s),
		})
	end
	if p.Rays then
		make("SunRaysEffect", "SunRays", {
			Intensity = (p.Rays.Intensity or 0) * s,
			Spread = p.Rays.Spread or 0.5,
		})
	end
	if p.DOF then
		make("DepthOfFieldEffect", "DepthOfField", {
			FarIntensity = (p.DOF.FarIntensity or 0) * s,
			NearIntensity = (p.DOF.NearIntensity or 0) * s,
			FocusDistance = p.DOF.FocusDistance or 50,
			InFocusRadius = p.DOF.InFocusRadius or 30,
		})
	end
	if p.Blur then
		make("BlurEffect", "Blur", { Size = (p.Blur.Size or 0) * s })
	end
	if p.Atmo then
		-- only one Atmosphere can be active, so park the game's own while ours is on
		for _, d in ipairs(Lighting:GetChildren()) do
			if d:IsA("Atmosphere") and not isOurs(d) then
				detach(self.tr, d)
			end
		end
		make("Atmosphere", "Atmosphere", {
			Density = (p.Atmo.Density or 0) * s,
			Offset = p.Atmo.Offset or 0,
			Color = p.Atmo.Color or white,
			Decay = p.Atmo.Decay or black,
			Glare = (p.Atmo.Glare or 0) * s,
			Haze = (p.Atmo.Haze or 0) * s,
		})
	end
	for k, v in pairs(p.Light or {}) do
		if k == "ExposureCompensation" then
			v = v * s
		elseif k == "ColorShift_Top" or k == "ColorShift_Bottom" then
			v = black:Lerp(v, s)
		end
		track(self.tr, Lighting, k, v)
	end
end

function Shaders:Add(name, def)
	if not self.Presets[name] then
		table.insert(self.Order, name)
	end
	self.Presets[name] = def
	if self._dropdown then
		local values = {}
		for i, n in ipairs(self.Order) do
			values[i] = (n == "Off") and "Off (none)" or n
		end
		self._dropdown:SetValues(values)
	end
end

Graphics.Shaders = Shaders

---------------------------------------------------------------- skyboxes
local DEFAULT_FACES = {
	Bk = "rbxasset://textures/sky/sky512_bk.tex",
	Dn = "rbxasset://textures/sky/sky512_dn.tex",
	Ft = "rbxasset://textures/sky/sky512_ft.tex",
	Lf = "rbxasset://textures/sky/sky512_lf.tex",
	Rt = "rbxasset://textures/sky/sky512_rt.tex",
	Up = "rbxasset://textures/sky/sky512_up.tex",
}
local BLANK_FACES = { Bk = "", Dn = "", Ft = "", Lf = "", Rt = "", Up = "" }
local FACE_KEYS = { "Bk", "Dn", "Ft", "Lf", "Rt", "Up" }

local Sky = {
	Current = "Off",
	tr = newTracker(),
	Order = {
		"Off (game default)", "Roblox Default", "Clear Noon", "Golden Hour", "Sunset", "Dawn",
		"Night", "Starry Night", "Blood Moon", "Space", "Gloomy", "Vaporwave",
	},
	Presets = {
		["Roblox Default"] = { Faces = DEFAULT_FACES, StarCount = 3000, Light = { ClockTime = 14 } },
		["Clear Noon"] = { Faces = DEFAULT_FACES, StarCount = 0, Light = { ClockTime = 12 } },
		["Golden Hour"] = {
			Faces = DEFAULT_FACES, StarCount = 0,
			Light = { ClockTime = 17.3, ColorShift_Top = C(255, 160, 80), OutdoorAmbient = C(150, 120, 100) },
		},
		["Sunset"] = {
			Faces = DEFAULT_FACES, StarCount = 500,
			Light = { ClockTime = 18.2, ColorShift_Top = C(255, 120, 70), OutdoorAmbient = C(120, 90, 100) },
		},
		["Dawn"] = {
			Faces = DEFAULT_FACES, StarCount = 800,
			Light = { ClockTime = 5.8, ColorShift_Top = C(255, 190, 140), OutdoorAmbient = C(110, 100, 120) },
		},
		["Night"] = {
			Faces = DEFAULT_FACES, StarCount = 5000,
			Light = { ClockTime = 0, OutdoorAmbient = C(50, 55, 90), Ambient = C(25, 25, 45) },
		},
		["Starry Night"] = {
			Faces = BLANK_FACES, StarCount = 9000, Moon = 20,
			Light = { ClockTime = 0, OutdoorAmbient = C(45, 50, 85), Ambient = C(20, 22, 40) },
		},
		["Blood Moon"] = {
			Faces = BLANK_FACES, StarCount = 3000, Moon = 24,
			Light = { ClockTime = 0, ColorShift_Top = C(255, 60, 40), OutdoorAmbient = C(90, 30, 30), Ambient = C(40, 12, 12) },
		},
		["Space"] = {
			Faces = BLANK_FACES, StarCount = 12000, Bodies = false,
			Light = { ClockTime = 0, OutdoorAmbient = C(40, 40, 70), Ambient = C(25, 25, 50) },
		},
		["Gloomy"] = {
			Faces = DEFAULT_FACES, StarCount = 0, Bodies = false,
			Light = { ClockTime = 11, Brightness = 1, Ambient = C(90, 95, 105), OutdoorAmbient = C(110, 115, 125) },
		},
		["Vaporwave"] = {
			Faces = DEFAULT_FACES, StarCount = 1500,
			Light = {
				ClockTime = 18, ColorShift_Top = C(255, 100, 200), ColorShift_Bottom = C(80, 200, 255),
				Ambient = C(120, 60, 140), OutdoorAmbient = C(140, 80, 170),
			},
		},
	},
}

function Sky:_clear()
	for _, d in ipairs(Lighting:GetChildren()) do
		if isOurs(d) and d:IsA("Sky") then
			d:Destroy()
		end
	end
end

function Sky:Apply(name)
	restore(self.tr)
	self:_clear()
	self.Current = name or "Off"
	local p = self.Presets[self.Current]
	if not p then
		return
	end
	for _, d in ipairs(Lighting:GetChildren()) do
		if d:IsA("Sky") and not isOurs(d) then
			detach(self.tr, d)
		end
	end
	local sky = Instance.new("Sky")
	sky.Name = PREFIX .. "Sky"
	local f = p.Faces or DEFAULT_FACES
	sky.SkyboxBk, sky.SkyboxDn, sky.SkyboxFt = f.Bk, f.Dn, f.Ft
	sky.SkyboxLf, sky.SkyboxRt, sky.SkyboxUp = f.Lf, f.Rt, f.Up
	sky.StarCount = p.StarCount or 3000
	sky.CelestialBodiesShown = p.Bodies ~= false
	sky.SunAngularSize = p.Sun or 21
	sky.MoonAngularSize = p.Moon or 11
	sky.Parent = Lighting
	for k, v in pairs(p.Light or {}) do
		track(self.tr, Lighting, k, v)
	end
end

function Sky:SetTime(t)
	track(self.tr, Lighting, "ClockTime", t)
end

-- "bk,dn,ft,lf,rt,up"  (asset IDs or full rbxassetid:// strings). One ID = same image on all faces.
function Sky:ApplyCustom(str)
	local ids = {}
	for token in string.gmatch(str or "", "[^,%s]+") do
		ids[#ids + 1] = tonumber(token) and ("rbxassetid://" .. token) or token
	end
	if #ids == 0 then
		return false
	end
	local faces = {}
	for i, key in ipairs(FACE_KEYS) do
		faces[key] = ids[i] or ids[1]
	end
	self.Presets["Custom"] = { Faces = faces, StarCount = 0, Bodies = false, Light = { ClockTime = 14 } }
	self:Apply("Custom")
	return true
end

Graphics.Sky = Sky

function Graphics:AddSkybox(name, def)
	if not Sky.Presets[name] then
		table.insert(Sky.Order, name)
	end
	Sky.Presets[name] = def
	if Sky._dropdown then
		Sky._dropdown:SetValues(Sky.Order)
	end
end

---------------------------------------------------------------- teardown
function Graphics:Destroy()
	for _, group in pairs(self.Features) do
		for _, f in pairs(group) do
			f:Disable()
		end
	end
	Shaders:Apply("Off")
	Sky:Apply("Off (game default)")
	if self._statsConn then
		self._statsConn:Disconnect()
		self._statsConn = nil
	end
end

---------------------------------------------------------------- UI
function Graphics:BuildTabs(Library, Window)
	local self_ = self
	local O = Library.Options

	local boosterToggles = {
		{ "shadows", "Disable shadows" },
		{ "particles", "Disable particles & trails" },
		{ "postfx", "Disable game post-processing" },
		{ "water", "Flatten water" },
		{ "meshes", "Low mesh detail" },
		{ "decor", "Hide terrain decoration" },
		{ "quality", "Lowest graphics quality" },
	}
	local textureToggles = {
		{ "decals", "Decals & textures" },
		{ "surface", "PBR surface appearance" },
		{ "meshtex", "Mesh textures" },
		{ "clothing", "Clothing textures" },
	}

	local allFlags = {}
	for _, t in ipairs(boosterToggles) do table.insert(allFlags, "fps_" .. t[1]) end
	for _, t in ipairs(textureToggles) do table.insert(allFlags, "tex_" .. t[1]) end
	table.insert(allFlags, "tex_flat")

	local function setFlags(map)
		for _, flag in ipairs(allFlags) do
			if O[flag] then
				O[flag]:Set(map[flag] == true)
			end
		end
	end

	local presets = {
		["Off"] = {},
		["Light"] = { fps_shadows = true, fps_particles = true },
		["Balanced"] = {
			fps_shadows = true, fps_particles = true, fps_water = true,
			fps_decor = true, fps_meshes = true, tex_flat = true,
		},
		["Extreme"] = {
			fps_shadows = true, fps_particles = true, fps_postfx = true, fps_water = true,
			fps_meshes = true, fps_decor = true, fps_quality = true,
			tex_decals = true, tex_surface = true, tex_meshtex = true, tex_clothing = true, tex_flat = true,
		},
	}

	---------------------------------------------------------------- FPS tab
	local fps = Window:AddTab("FPS")
	local g = fps:AddGroup("FPS Booster", "Left")
	g:AddDropdown("fps_preset", {
		Text = "Preset",
		Values = { "Off", "Light", "Balanced", "Extreme" },
		Default = 1,
		Callback = function(v)
			setFlags(presets[v])
			Library:Notify("FPS booster: " .. v, 2)
		end,
	})
	for _, t in ipairs(boosterToggles) do
		g:AddToggle("fps_" .. t[1], {
			Text = t[2],
			Callback = function(v)
				self_:SetFeature("Booster", t[1], v)
			end,
		})
	end

	local stats = fps:AddGroup("Live stats", "Right")
	local fpsLabel = stats:AddLabel("FPS: ...")
	local frameLabel = stats:AddLabel("Frame time: ...")
	local memLabel = stats:AddLabel("Memory: ...")
	local acc, frames = 0, 0
	self._statsConn = RunService.RenderStepped:Connect(function(dt)
		acc += dt
		frames += 1
		if acc >= 0.5 then
			local f = frames / acc
			fpsLabel:SetText(string.format("FPS: %d", math.floor(f + 0.5)))
			frameLabel:SetText(string.format("Frame time: %.1f ms", 1000 / f))
			local ok, mem = pcall(function()
				return Stats:GetTotalMemoryUsageMb()
			end)
			memLabel:SetText(ok and string.format("Memory: %d MB", mem) or "Memory: n/a")
			acc, frames = 0, 0
		end
	end)

	local actions = fps:AddGroup("Quick actions", "Right")
	actions:AddButton("Revert everything", function()
		setFlags({})
		O["fps_preset"]:Set("Off")
		O["shader_preset"]:Set("Off (none)")
		O["sky_preset"]:Set("Off (game default)")
		Library:Notify("All graphics changes reverted", 3)
	end)

	---------------------------------------------------------------- Textures tab
	local tex = Window:AddTab("Textures")
	local tg = tex:AddGroup("Remove textures", "Left")
	for _, t in ipairs(textureToggles) do
		tg:AddToggle("tex_" .. t[1], {
			Text = t[2],
			Callback = function(v)
				self_:SetFeature("Textures", t[1], v)
			end,
		})
	end
	local mg = tex:AddGroup("Materials", "Left")
	mg:AddToggle("tex_flat", {
		Text = "Flat materials (SmoothPlastic)",
		Callback = function(v)
			self_:SetFeature("Textures", "flat", v)
		end,
	})
	local qg = tex:AddGroup("Quick", "Right")
	qg:AddButton("Remove all textures", function()
		for _, t in ipairs(textureToggles) do O["tex_" .. t[1]]:Set(true) end
		O["tex_flat"]:Set(true)
	end)
	qg:AddButton("Restore all textures", function()
		for _, t in ipairs(textureToggles) do O["tex_" .. t[1]]:Set(false) end
		O["tex_flat"]:Set(false)
	end)
	qg:AddLabel("Only affects your own client.")

	---------------------------------------------------------------- Shaders tab
	local sh = Window:AddTab("Shaders")
	local sg = sh:AddGroup("Shaders", "Left")
	local shaderValues = {}
	for i, n in ipairs(Shaders.Order) do
		shaderValues[i] = (n == "Off") and "Off (none)" or n
	end
	local function fromLabel(v)
		return (v == "Off (none)") and "Off" or v
	end
	Shaders._dropdown = sg:AddDropdown("shader_preset", {
		Text = "Preset",
		Values = shaderValues,
		Default = 1,
		Callback = function(v)
			Shaders:Apply(fromLabel(v))
		end,
	})
	sg:AddSlider("shader_strength", {
		Text = "Strength",
		Min = 0, Max = 100, Default = 100, Suffix = "%", Increment = 5,
		Callback = function(v)
			Shaders.Strength = v / 100
			if Shaders.Current ~= "Off" then
				Shaders:Apply(Shaders.Current)
			end
		end,
	})
	local tiers = sh:AddGroup("Quality tiers", "Right")
	tiers:AddLabel("Low: color grading only")
	tiers:AddLabel("Medium: + bloom, sun rays")
	tiers:AddLabel("High: + atmosphere")
	tiers:AddLabel("Ultra: + depth of field")
	tiers:AddLabel("Others are style looks.")

	---------------------------------------------------------------- Sky tab
	local sk = Window:AddTab("Sky")
	local kg = sk:AddGroup("Skybox", "Left")
	Sky._dropdown = kg:AddDropdown("sky_preset", {
		Text = "Skybox",
		Values = Sky.Order,
		Default = 1,
		Callback = function(v)
			Sky:Apply(v)
			local p = Sky.Presets[v]
			if p and p.Light and p.Light.ClockTime and O["sky_time"] then
				O["sky_time"]:Set(p.Light.ClockTime)
			end
		end,
	})
	kg:AddSlider("sky_time", {
		Text = "Time of day",
		Min = 0, Max = 24, Default = 14, Increment = 0.1,
		Callback = function(v)
			Sky:SetTime(v)
		end,
	})
	local cg = sk:AddGroup("Custom skybox", "Right")
	cg:AddTextbox("sky_custom", {
		Text = "Asset IDs (bk,dn,ft,lf,rt,up)",
		Placeholder = "123,456,... or one ID",
	})
	cg:AddButton("Apply custom skybox", function()
		if Sky:ApplyCustom(Library.Flags["sky_custom"]) then
			Library:Notify("Custom skybox applied", 2)
		else
			Library:Notify("Enter at least one asset ID", 2)
		end
	end)
	cg:AddButton("Reset sky", function()
		O["sky_preset"]:Set("Off (game default)")
	end)
end

return Graphics

end

-------------------------------------------------------------------- Main
-- LocalScript (StarterPlayerScripts).
-- Put ModuleScripts named "SkeetUI" and "Graphics" next to it.
local Library = __require("SkeetUI")
local Graphics = __require("Graphics")

local Window = Library:CreateWindow({
	Title = "skeet-ui | graphics",
	Size = Vector2.new(620, 420),
	ToggleKey = Enum.KeyCode.RightShift,
})

-- adds the FPS / Textures / Shaders / Sky tabs
Graphics:BuildTabs(Library, Window)

-- optional: register your own skybox (fill in your own image asset IDs)
-- Graphics:AddSkybox("My Sky", {
-- 	Faces = { Bk = "rbxassetid://0", Dn = "rbxassetid://0", Ft = "rbxassetid://0",
-- 	          Lf = "rbxassetid://0", Rt = "rbxassetid://0", Up = "rbxassetid://0" },
-- 	StarCount = 0,
-- 	Light = { ClockTime = 14 },
-- })

-- optional: register your own shader look
-- Graphics.Shaders:Add("My Look", {
-- 	Bloom = { Intensity = 0.4, Size = 28, Threshold = 1.4 },
-- 	CC = { Contrast = 0.15, Saturation = 0.3 },
-- })

local Settings = Window:AddTab("Settings")
local Menu = Settings:AddGroup("Menu", "Left")
Menu:AddToggle("watermark", {
	Text = "Watermark", Default = true,
	Callback = function(on)
		Library:SetWatermark(on and "skeet-ui" or nil)
	end,
})
Menu:AddButton("Unload", function()
	Graphics:Destroy() -- reverts every graphics change
	Library:Unload()
end)

Library:SetWatermark("skeet-ui")
Library:Notify("Loaded - press RightShift to toggle the menu", 4)

