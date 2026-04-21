--[[
    AnimationPreview v2.0
    ─────────────────────────────────────────────────────────────────────────
    Features
      • Detects & previews every AnimationTrack on the local character
      • Per-part easing (Linear / Cubic / Elastic / Bounce / Constant × In/Out/InOut)
      • Full-fidelity copy: EasingStyle, EasingDirection, Weight, Loop, Priority
      • Drag-to-orbit viewport with character clone
      • Search / filter bar
      • Animation info panel (duration, priority, keyframe count, loop)
      • Playback progress bar
      • Minimize / close window buttons
      • Flash feedback on copy
    ─────────────────────────────────────────────────────────────────────────
]]

-- ════════════════════════════════════════════════════
-- SERVICES
-- ════════════════════════════════════════════════════
local Players                  = game:GetService("Players")
local RunService               = game:GetService("RunService")
local UserInputService         = game:GetService("UserInputService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local HttpService              = game:GetService("HttpService")
local TweenService             = game:GetService("TweenService")

-- ════════════════════════════════════════════════════
-- PLAYER / CHARACTER
-- ════════════════════════════════════════════════════
local PLAYER     = Players.LocalPlayer
local PLAYER_GUI = PLAYER.PlayerGui
local CHARACTER  = PLAYER.Character or PLAYER.CharacterAdded:Wait()
local HUMANOID   = CHARACTER:WaitForChild("Humanoid")
local ANIMATOR   = HUMANOID:WaitForChild("Animator")

-- ════════════════════════════════════════════════════
-- CAMERA CONSTANTS
-- ════════════════════════════════════════════════════
local ROTATION_SPEED = 0.4
local CAM_DISTANCE   = 15
local CAM_HEIGHT     = 1.2

-- ════════════════════════════════════════════════════
-- COLOR PALETTE  (all Color3 values centralised here)
-- ════════════════════════════════════════════════════
local C = {
	BG          = Color3.fromRGB(10,  10,  13 ),
	TITLEBAR    = Color3.fromRGB(7,   7,   9  ),
	PANEL       = Color3.fromRGB(15,  15,  19 ),
	SURFACE     = Color3.fromRGB(21,  21,  27 ),
	BUTTON      = Color3.fromRGB(24,  50,  52 ),
	BUTTON_HOV  = Color3.fromRGB(34,  66,  68 ),
	SELECTED    = Color3.fromRGB(34,  78,  80 ),
	ACCENT      = Color3.fromRGB(54,  176, 156),
	ACCENT_DIM  = Color3.fromRGB(34,  106,  96),
	TEXT        = Color3.fromRGB(215, 220, 228),
	TEXT_DIM    = Color3.fromRGB(105, 115, 130),
	TEXT_ACC    = Color3.fromRGB(74,  200, 178),
	SUCCESS     = Color3.fromRGB(78,  200, 118),
	WARN        = Color3.fromRGB(220, 170,  58),
	SEP         = Color3.fromRGB(28,  28,  36 ),
	VIEWPORT_BG = Color3.fromRGB(28,  30,  40 ),
}

-- ════════════════════════════════════════════════════
-- UTILITY: create a UICorner quickly
-- ════════════════════════════════════════════════════
local function corner(r, parent)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
	return c
end

-- ════════════════════════════════════════════════════
-- ROOT GUI
-- ════════════════════════════════════════════════════
local SCREEN_GUI = Instance.new("ScreenGui")
SCREEN_GUI.Name           = "AnimPreviewGUI"
SCREEN_GUI.IgnoreGuiInset = true
SCREEN_GUI.ResetOnSpawn   = false
SCREEN_GUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SCREEN_GUI.Parent         = PLAYER_GUI

-- Main window frame
local MAIN = Instance.new("Frame")
MAIN.Name             = "MainWindow"
MAIN.Size             = UDim2.new(0, 570, 0, 330)
MAIN.Position         = UDim2.new(0.5, -285, 0.5, -165)
MAIN.BackgroundColor3 = C.BG
MAIN.BorderSizePixel  = 0
MAIN.Parent           = SCREEN_GUI
corner(9, MAIN)

-- ── Title bar ──────────────────────────────────────
local TITLEBAR = Instance.new("Frame")
TITLEBAR.Name             = "TitleBar"
TITLEBAR.Size             = UDim2.new(1, 0, 0, 38)
TITLEBAR.BackgroundColor3 = C.TITLEBAR
TITLEBAR.BorderSizePixel  = 0
TITLEBAR.Parent           = MAIN
corner(9, TITLEBAR)

-- Patch: fill bottom half of title bar so rounded corners only show on top
local TB_PATCH = Instance.new("Frame")
TB_PATCH.Size             = UDim2.new(1, 0, 0.5, 0)
TB_PATCH.Position         = UDim2.new(0, 0, 0.5, 0)
TB_PATCH.BackgroundColor3 = C.TITLEBAR
TB_PATCH.BorderSizePixel  = 0
TB_PATCH.ZIndex           = TITLEBAR.ZIndex
TB_PATCH.Parent           = TITLEBAR

-- Thin accent separator line below title bar
local TB_SEP = Instance.new("Frame")
TB_SEP.Size             = UDim2.new(1, 0, 0, 1)
TB_SEP.Position         = UDim2.new(0, 0, 1, -1)
TB_SEP.BackgroundColor3 = C.ACCENT
TB_SEP.BackgroundTransparency = 0.45
TB_SEP.BorderSizePixel  = 0
TB_SEP.Parent           = TITLEBAR

-- Title icon (play triangle)
local TB_ICON = Instance.new("TextLabel")
TB_ICON.Size                  = UDim2.new(0, 22, 0, 22)
TB_ICON.Position              = UDim2.new(0, 11, 0.5, -11)
TB_ICON.Text                  = "▶"
TB_ICON.TextColor3            = C.ACCENT
TB_ICON.Font                  = Enum.Font.GothamBold
TB_ICON.TextScaled            = true
TB_ICON.BackgroundTransparency = 1
TB_ICON.Parent                = TITLEBAR

-- Title text
local TB_TITLE = Instance.new("TextLabel")
TB_TITLE.Size                 = UDim2.new(0, 200, 1, 0)
TB_TITLE.Position             = UDim2.new(0, 38, 0, 0)
TB_TITLE.Text                 = "Animation Preview"
TB_TITLE.TextColor3           = C.TEXT
TB_TITLE.Font                 = Enum.Font.GothamBold
TB_TITLE.TextScaled           = true
TB_TITLE.BackgroundTransparency = 1
TB_TITLE.TextXAlignment       = Enum.TextXAlignment.Left
TB_TITLE.Parent               = TITLEBAR

-- Version badge
local TB_VER = Instance.new("TextLabel")
TB_VER.Size                 = UDim2.new(0, 34, 0, 16)
TB_VER.Position             = UDim2.new(0, 243, 0.5, -8)
TB_VER.Text                 = "v2.0"
TB_VER.TextColor3           = C.TEXT_DIM
TB_VER.Font                 = Enum.Font.Gotham
TB_VER.TextScaled           = true
TB_VER.BackgroundTransparency = 1
TB_VER.Parent               = TITLEBAR

-- Window-control buttons factory
local function makeWinBtn(symbol, bgColor, offsetX)
	local btn = Instance.new("TextButton")
	btn.Size             = UDim2.new(0, 16, 0, 16)
	btn.Position         = UDim2.new(1, offsetX, 0.5, -8)
	btn.Text             = symbol
	btn.TextColor3       = Color3.fromRGB(200, 200, 200)
	btn.BackgroundColor3 = bgColor
	btn.Font             = Enum.Font.GothamBold
	btn.TextScaled       = true
	btn.BorderSizePixel  = 0
	btn.Parent           = TITLEBAR
	corner(10, btn)
	return btn
end

local BTN_CLOSE = makeWinBtn("×", Color3.fromRGB(175, 55, 55), -22)
local BTN_MIN   = makeWinBtn("−", Color3.fromRGB(55,  55, 55), -44)

-- Minimise / close logic
local minimised = false
local CONTENT_REFS = {} -- filled after content frames are created

BTN_CLOSE.MouseButton1Click:Connect(function()
	SCREEN_GUI:Destroy()
end)
BTN_MIN.MouseButton1Click:Connect(function()
	minimised = not minimised
	for _, ref in ipairs(CONTENT_REFS) do
		ref.Visible = not minimised
	end
	MAIN.Size = minimised and UDim2.new(0, 570, 0, 38) or UDim2.new(0, 570, 0, 330)
end)

-- ── Drag (title bar only) ───────────────────────────
do
	local dragging, dragStart, startPos
	TITLEBAR.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = i.Position
			startPos  = MAIN.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
			local d = i.Position - dragStart
			MAIN.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + d.X,
				startPos.Y.Scale, startPos.Y.Offset + d.Y
			)
		end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)
end

-- ════════════════════════════════════════════════════
-- CONTENT AREA  (everything below title bar)
-- ════════════════════════════════════════════════════
local CONTENT = Instance.new("Frame")
CONTENT.Name             = "Content"
CONTENT.Size             = UDim2.new(1, 0, 1, -38)
CONTENT.Position         = UDim2.new(0, 0, 0, 38)
CONTENT.BackgroundTransparency = 1
CONTENT.BorderSizePixel  = 0
CONTENT.Parent           = MAIN
table.insert(CONTENT_REFS, CONTENT)

-- ── LEFT PANEL (animation list) ────────────────────
local LEFT = Instance.new("Frame")
LEFT.Name             = "LeftPanel"
LEFT.Size             = UDim2.new(0.46, 0, 1, 0)
LEFT.BackgroundColor3 = C.PANEL
LEFT.BorderSizePixel  = 0
LEFT.Parent           = CONTENT

-- Search bar background
local SEARCH_BG = Instance.new("Frame")
SEARCH_BG.Size             = UDim2.new(1, 0, 0, 34)
SEARCH_BG.BackgroundColor3 = C.SURFACE
SEARCH_BG.BorderSizePixel  = 0
SEARCH_BG.Parent           = LEFT

-- Magnifier icon (text label substitute)
local SEARCH_ICON = Instance.new("TextLabel")
SEARCH_ICON.Size                  = UDim2.new(0, 18, 1, 0)
SEARCH_ICON.Position              = UDim2.new(0, 9, 0, 0)
SEARCH_ICON.Text                  = "⌕"
SEARCH_ICON.TextSize              = 16
SEARCH_ICON.TextColor3            = C.TEXT_DIM
SEARCH_ICON.Font                  = Enum.Font.Gotham
SEARCH_ICON.BackgroundTransparency = 1
SEARCH_ICON.Parent                = SEARCH_BG

-- Text box for search input
local SEARCH_BOX = Instance.new("TextBox")
SEARCH_BOX.Size               = UDim2.new(1, -34, 1, 0)
SEARCH_BOX.Position           = UDim2.new(0, 32, 0, 0)
SEARCH_BOX.PlaceholderText    = "Filter animations…"
SEARCH_BOX.PlaceholderColor3  = C.TEXT_DIM
SEARCH_BOX.Text               = ""
SEARCH_BOX.TextColor3         = C.TEXT
SEARCH_BOX.Font               = Enum.Font.Gotham
SEARCH_BOX.TextSize           = 13
SEARCH_BOX.BackgroundTransparency = 1
SEARCH_BOX.ClearTextOnFocus   = false
SEARCH_BOX.TextXAlignment     = Enum.TextXAlignment.Left
SEARCH_BOX.Parent             = SEARCH_BG

-- Hairline separator below search bar
local SEP_LINE = Instance.new("Frame")
SEP_LINE.Size             = UDim2.new(1, 0, 0, 1)
SEP_LINE.Position         = UDim2.new(0, 0, 0, 34)
SEP_LINE.BackgroundColor3 = C.SEP
SEP_LINE.BorderSizePixel  = 0
SEP_LINE.Parent           = LEFT

-- Scrolling list of animation buttons
local SCROLL = Instance.new("ScrollingFrame")
SCROLL.Name                 = "AnimList"
SCROLL.Size                 = UDim2.new(1, 0, 1, -35)
SCROLL.Position             = UDim2.new(0, 0, 0, 35)
SCROLL.BackgroundTransparency = 1
SCROLL.BorderSizePixel      = 0
SCROLL.ScrollBarThickness   = 3
SCROLL.ScrollBarImageColor3 = C.ACCENT
SCROLL.CanvasSize           = UDim2.new(0, 0, 0, 0)
SCROLL.AutomaticCanvasSize  = Enum.AutomaticSize.Y
SCROLL.Parent               = LEFT

local LIST_LAYOUT = Instance.new("UIListLayout")
LIST_LAYOUT.Padding             = UDim.new(0, 3)
LIST_LAYOUT.HorizontalAlignment = Enum.HorizontalAlignment.Center
LIST_LAYOUT.SortOrder           = Enum.SortOrder.LayoutOrder
LIST_LAYOUT.Parent              = SCROLL

local LIST_PAD = Instance.new("UIPadding")
LIST_PAD.PaddingTop    = UDim.new(0, 5)
LIST_PAD.PaddingBottom = UDim.new(0, 5)
LIST_PAD.Parent        = SCROLL

-- Empty-state label shown when no animations are detected yet
local EMPTY_LABEL = Instance.new("TextLabel")
EMPTY_LABEL.Name              = "EmptyState"
EMPTY_LABEL.Size              = UDim2.new(1, -20, 0, 50)
EMPTY_LABEL.Position          = UDim2.new(0, 10, 0, 8)
EMPTY_LABEL.Text              = "No animations detected yet.\nMove your character to trigger them."
EMPTY_LABEL.TextColor3        = C.TEXT_DIM
EMPTY_LABEL.Font              = Enum.Font.Gotham
EMPTY_LABEL.TextSize          = 11
EMPTY_LABEL.TextWrapped       = true
EMPTY_LABEL.BackgroundTransparency = 1
EMPTY_LABEL.Parent            = SCROLL

-- ── RIGHT PANEL (viewport + info) ──────────────────
local RIGHT = Instance.new("Frame")
RIGHT.Name             = "RightPanel"
RIGHT.Size             = UDim2.new(0.54, 0, 1, 0)
RIGHT.Position         = UDim2.new(0.46, 0, 0, 0)
RIGHT.BackgroundColor3 = C.BG
RIGHT.BorderSizePixel  = 0
RIGHT.Parent           = CONTENT

-- ViewportFrame for the character clone
local VIEWPORT = Instance.new("ViewportFrame")
VIEWPORT.Size             = UDim2.new(1, 0, 1, -64)
VIEWPORT.BackgroundColor3 = C.VIEWPORT_BG
VIEWPORT.BorderSizePixel  = 0
VIEWPORT.LightDirection   = Vector3.new(-1, -2, -1)
VIEWPORT.Ambient          = Color3.fromRGB(155, 158, 165)
VIEWPORT.Parent           = RIGHT

-- Subtle orbit hint text overlay
local ORBIT_HINT = Instance.new("TextLabel")
ORBIT_HINT.Size                  = UDim2.new(1, 0, 0, 18)
ORBIT_HINT.Position              = UDim2.new(0, 0, 1, -20)
ORBIT_HINT.Text                  = "drag to orbit"
ORBIT_HINT.TextColor3            = Color3.fromRGB(140, 145, 158)
ORBIT_HINT.Font                  = Enum.Font.Gotham
ORBIT_HINT.TextSize              = 11
ORBIT_HINT.BackgroundTransparency = 1
ORBIT_HINT.ZIndex                = 5
ORBIT_HINT.Parent                = VIEWPORT

-- Info panel (64 px strip below viewport)
local INFO = Instance.new("Frame")
INFO.Name             = "InfoPanel"
INFO.Size             = UDim2.new(1, 0, 0, 64)
INFO.Position         = UDim2.new(0, 0, 1, -64)
INFO.BackgroundColor3 = C.SURFACE
INFO.BorderSizePixel  = 0
INFO.Parent           = RIGHT

-- Hairline top border on info panel
local INFO_SEP = Instance.new("Frame")
INFO_SEP.Size             = UDim2.new(1, 0, 0, 1)
INFO_SEP.BackgroundColor3 = C.SEP
INFO_SEP.BorderSizePixel  = 0
INFO_SEP.Parent           = INFO

-- Helper: create a small info text label inside INFO panel
local function makeInfoLabel(x, y)
	local lbl = Instance.new("TextLabel")
	lbl.Size                 = UDim2.new(0.5, -4, 0, 18)
	lbl.Position             = UDim2.new(x, 4, 0, y)
	lbl.TextColor3           = C.TEXT_DIM
	lbl.Font                 = Enum.Font.Gotham
	lbl.TextSize             = 11
	lbl.BackgroundTransparency = 1
	lbl.TextXAlignment       = Enum.TextXAlignment.Left
	lbl.Parent               = INFO
	return lbl
end

local LBL_NAME     = makeInfoLabel(0,   4)   -- top-left  : animation name
local LBL_DURATION = makeInfoLabel(0,   22)  -- mid-left  : duration
local LBL_LOOP     = makeInfoLabel(0.5, 4)   -- top-right : loop flag
local LBL_PRIORITY = makeInfoLabel(0.5, 22)  -- mid-right : priority

-- Playback progress bar
local PROG_BG = Instance.new("Frame")
PROG_BG.Size             = UDim2.new(1, -10, 0, 4)
PROG_BG.Position         = UDim2.new(0, 5, 1, -12)
PROG_BG.BackgroundColor3 = C.BUTTON
PROG_BG.BorderSizePixel  = 0
PROG_BG.Parent           = INFO
corner(4, PROG_BG)

local PROG_FILL = Instance.new("Frame")
PROG_FILL.Size             = UDim2.new(0, 0, 1, 0)
PROG_FILL.BackgroundColor3 = C.ACCENT
PROG_FILL.BorderSizePixel  = 0
PROG_FILL.Parent           = PROG_BG
corner(4, PROG_FILL)

-- Copy-status label (flashes "Copied!" briefly)
local COPY_LABEL = Instance.new("TextLabel")
COPY_LABEL.Size                  = UDim2.new(0, 80, 0, 18)
COPY_LABEL.Position              = UDim2.new(1, -84, 0, 3)
COPY_LABEL.Text                  = "Copied!"
COPY_LABEL.TextColor3            = C.SUCCESS
COPY_LABEL.Font                  = Enum.Font.GothamBold
COPY_LABEL.TextSize              = 11
COPY_LABEL.BackgroundTransparency = 1
COPY_LABEL.TextXAlignment        = Enum.TextXAlignment.Right
COPY_LABEL.Visible               = false
COPY_LABEL.Parent                = INFO

-- Helper: reset info panel to idle state
local function resetInfo()
	LBL_NAME.Text     = "Name: —"
	LBL_DURATION.Text = "Duration: —"
	LBL_LOOP.Text     = "Loop: —"
	LBL_PRIORITY.Text = "Priority: —"
	LBL_LOOP.TextColor3 = C.TEXT_DIM
	PROG_FILL.Size    = UDim2.new(0, 0, 1, 0)
end
resetInfo()

-- Helper: populate info panel with animation metadata
local function setInfo(name, duration, looped, priority)
	LBL_NAME.Text       = "Name: " .. tostring(name)
	LBL_DURATION.Text   = ("Duration: %.2fs"):format(duration)
	LBL_LOOP.Text       = "Loop: " .. (looped and "Yes" or "No")
	LBL_PRIORITY.Text   = "Priority: " .. tostring(priority)
	LBL_LOOP.TextColor3 = looped and C.SUCCESS or C.TEXT_DIM
end

-- ════════════════════════════════════════════════════
-- CHARACTER CLONE INSIDE VIEWPORT
-- ════════════════════════════════════════════════════
local worldModel = Instance.new("WorldModel")
worldModel.Parent = VIEWPORT

CHARACTER.Archivable = true
local cloneChar = CHARACTER:Clone()

-- Strip scripts and UI elements from the clone (they're not needed in viewport)
for _, v in ipairs(cloneChar:GetDescendants()) do
	if v:IsA("Script") or v:IsA("LocalScript") or v:IsA("ModuleScript")
		or v:IsA("BillboardGui") or v:IsA("SurfaceGui") then
		v:Destroy()
	end
end
cloneChar.Parent = worldModel

local CLONE_ROOT = cloneChar:WaitForChild("HumanoidRootPart")

-- Camera for the viewport
local viewCam = Instance.new("Camera")
viewCam.FieldOfView = 30
viewCam.Parent = VIEWPORT
VIEWPORT.CurrentCamera = viewCam

local cameraAngleY = 0

local function updateCamera()
	local origin = CLONE_ROOT.Position + Vector3.new(0, CAM_HEIGHT, 0)
	local offset = Vector3.new(
		math.sin(cameraAngleY) * CAM_DISTANCE,
		0,
		math.cos(cameraAngleY) * CAM_DISTANCE
	)
	viewCam.CFrame = CFrame.new(origin + offset, origin)
end
updateCamera()

-- ── Orbit input (restricted to viewport bounds) ────
local isHovering = false
local isDragging = false
local lastMouse  = Vector2.zero

VIEWPORT.MouseEnter:Connect(function() isHovering = true  end)
VIEWPORT.MouseLeave:Connect(function() isHovering = false; isDragging = false end)

UserInputService.InputBegan:Connect(function(i)
	if not isHovering then return end
	if i.UserInputType == Enum.UserInputType.MouseButton1
		or i.UserInputType == Enum.UserInputType.Touch then
		isDragging = true
		lastMouse  = Vector2.new(i.Position.X, i.Position.Y)
	end
end)
UserInputService.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1
		or i.UserInputType == Enum.UserInputType.Touch then
		isDragging = false
	end
end)
UserInputService.InputChanged:Connect(function(i)
	if not isDragging then return end
	if i.UserInputType == Enum.UserInputType.MouseMovement
		or i.UserInputType == Enum.UserInputType.Touch then
		local pos   = Vector2.new(i.Position.X, i.Position.Y)
		local delta = pos - lastMouse
		lastMouse   = pos
		cameraAngleY -= math.rad(delta.X * ROTATION_SPEED)
		updateCamera()
	end
end)

-- ════════════════════════════════════════════════════
-- EASING FUNCTIONS
-- All functions accept t ∈ [0, 1] and return t ∈ [0, 1]
-- ════════════════════════════════════════════════════

local function easeLinear(t)       return t                                                         end
local function easeConstant(t)     return t < 1 and 0 or 1                                         end
local function easeCubicIn(t)      return t * t * t                                                 end
local function easeCubicOut(t)     local s = 1-t; return 1 - s*s*s                                 end
local function easeCubicInOut(t)   return t < 0.5 and 4*t*t*t or 1 - (-2*t+2)^3/2                 end

local function easeElasticOut(t)
	if t == 0 or t == 1 then return t end
	return (2 ^ (-10*t)) * math.sin((t*10 - 0.75) * (math.pi * 2 / 3)) + 1
end
local function easeElasticIn(t)
	if t == 0 or t == 1 then return t end
	return -(2 ^ (10*t - 10)) * math.sin((t*10 - 10.75) * (math.pi * 2 / 3))
end
local function easeElasticInOut(t)
	if t == 0 or t == 1 then return t end
	if t < 0.5 then return -(2^(20*t-10) * math.sin((20*t-11.125)*(math.pi*2/4.5))) / 2
	else return (2^(-20*t+10) * math.sin((20*t-11.125)*(math.pi*2/4.5))) / 2 + 1 end
end

local function easeBounceOut(t)
	local n1, d1 = 7.5625, 2.75
	if t < 1/d1       then return n1*t*t
	elseif t < 2/d1   then t = t - 1.5/d1;  return n1*t*t + 0.75
	elseif t < 2.5/d1 then t = t - 2.25/d1; return n1*t*t + 0.9375
	else                    t = t - 2.625/d1; return n1*t*t + 0.984375 end
end
local function easeBounceIn(t)    return 1 - easeBounceOut(1 - t)          end
local function easeBounceInOut(t)
	if t < 0.5 then return easeBounceIn(t*2) / 2
	else return easeBounceOut(t*2 - 1) / 2 + 0.5 end
end

-- Resolve Enum.PoseEasingStyle × Enum.PoseEasingDirection → function
local function resolveEasing(style, direction)
	local s = style.Name     -- "Linear" | "Constant" | "Cubic" | "Elastic" | "Bounce"
	local d = direction.Name -- "In" | "Out" | "InOut"

	if s == "Constant" then return easeConstant end
	if s == "Linear"   then return easeLinear   end

	if s == "Cubic" then
		if d == "In" then return easeCubicIn elseif d == "Out" then return easeCubicOut else return easeCubicInOut end
	elseif s == "Elastic" then
		if d == "In" then return easeElasticIn elseif d == "Out" then return easeElasticOut else return easeElasticInOut end
	elseif s == "Bounce" then
		if d == "In" then return easeBounceIn elseif d == "Out" then return easeBounceOut else return easeBounceInOut end
	end
	return easeLinear
end

-- ════════════════════════════════════════════════════
-- POSE MAP  (flattens Keyframe Pose tree into a table)
-- Each entry stores: CFrame, per-part easing function, Weight
-- ════════════════════════════════════════════════════
local function buildPoseMap(kf)
	local map = {}
	local function walk(inst)
		if inst:IsA("Pose") then
			map[inst.Name] = {
				cf     = inst.CFrame,
				easeFn = resolveEasing(inst.EasingStyle, inst.EasingDirection),
				-- store raw enums for serialisation
				esVal  = inst.EasingStyle.Value,
				edVal  = inst.EasingDirection.Value,
				weight = inst.Weight,
			}
			for _, child in ipairs(inst:GetChildren()) do walk(child) end
		end
	end
	for _, child in ipairs(kf:GetChildren()) do walk(child) end
	return map
end

-- Build a partName → Motor6D lookup table for the clone
local function buildMotorMap()
	local map = {}
	for _, m in ipairs(cloneChar:GetDescendants()) do
		if m:IsA("Motor6D") and m.Part1 then
			map[m.Part1.Name] = m
		end
	end
	return map
end

-- ════════════════════════════════════════════════════
-- PLAYBACK ENGINE
-- ════════════════════════════════════════════════════
local stopCurrentAnim = nil

local function stopPlayback()
	if stopCurrentAnim then
		stopCurrentAnim()
		stopCurrentAnim = nil
	end
	PROG_FILL.Size = UDim2.new(0, 0, 1, 0)
end

local function playOnClone(seq, looped, displayName)
	stopPlayback()

	-- Reset all Motor6D transforms to identity before playing
	for _, m in ipairs(cloneChar:GetDescendants()) do
		if m:IsA("Motor6D") then m.Transform = CFrame.identity end
	end

	local keyframes = seq:GetKeyframes()
	if not keyframes or #keyframes == 0 then
		warn("[AnimPreview] No keyframes in: " .. seq.Name) return
	end
	table.sort(keyframes, function(a, b) return a.Time < b.Time end)

	local duration = keyframes[#keyframes].Time
	if duration <= 0 then
		warn("[AnimPreview] Duration is 0 in: " .. seq.Name) return
	end

	-- Pre-build and cache pose maps to avoid per-frame allocations
	local poseMaps = {}
	for _, kf in ipairs(keyframes) do
		table.insert(poseMaps, { t = kf.Time, poses = buildPoseMap(kf) })
	end

	local motorMap  = buildMotorMap()
	local startTime = os.clock()
	local alive     = true

	-- Derive a readable priority name (e.g. "Action2" from Enum.AnimationPriority.Action2)
	local priorityStr = tostring(seq.Priority):match("%.(.+)$") or tostring(seq.Priority)
	setInfo(displayName or seq.Name, duration, looped, priorityStr)

	local conn = RunService.Heartbeat:Connect(function()
		if not alive then return end

		local elapsed = os.clock() - startTime

		-- Update progress fill (clamped to [0, 1])
		PROG_FILL.Size = UDim2.new(math.clamp(elapsed / duration, 0, 1), 0, 1, 0)

		-- Handle end of animation
		if elapsed >= duration then
			if looped then
				startTime = os.clock(); elapsed = 0
			else
				alive = false
				-- Snap to last keyframe
				for partName, motor in pairs(motorMap) do
					local last = poseMaps[#poseMaps].poses[partName]
					motor.Transform = last and last.cf or CFrame.identity
				end
				PROG_FILL.Size = UDim2.new(1, 0, 1, 0)
				return
			end
		end

		-- Find the surrounding keyframe pair for the current time
		local prevMap = poseMaps[1]
		local nextMap = poseMaps[1]
		for i = 1, #poseMaps do
			if poseMaps[i].t <= elapsed then
				prevMap = poseMaps[i]
				nextMap = poseMaps[i + 1] or poseMaps[i]
			else
				break
			end
		end

		local span = nextMap.t - prevMap.t

		-- Apply per-part interpolation using each part's own easing function
		for partName, motor in pairs(motorMap) do
			local pData = prevMap.poses[partName]
			local nData = nextMap.poses[partName]
			local cfA   = pData and pData.cf or CFrame.identity
			local cfB   = nData and nData.cf or cfA

			local alpha = 0
			if span > 0 then
				local rawAlpha = math.clamp((elapsed - prevMap.t) / span, 0, 1)
				-- Use the NEXT keyframe's easing for the incoming transition
				local easeFn = nData and nData.easeFn or easeLinear
				alpha = easeFn(rawAlpha)
			end

			motor.Transform = cfA:Lerp(cfB, alpha)
		end
	end)

	stopCurrentAnim = function()
		alive = false
		conn:Disconnect()
	end
end

-- ════════════════════════════════════════════════════
-- FULL-FIDELITY COPY
-- Serialises ALL animation properties including:
--   EasingStyle, EasingDirection, Weight (per Pose)
--   Loop, Priority (on KeyframeSequence)
-- and generates a self-contained reconstruction script.
-- ════════════════════════════════════════════════════
local function copyAnimationAsScript(seq, displayName)

	-- Recursively serialise the Pose tree under a given parent instance
	local function serializePoses(parent)
		local data = {}
		for _, pose in ipairs(parent:GetChildren()) do
			if pose:IsA("Pose") then
				data[pose.Name] = {
					cf  = { pose.CFrame:GetComponents() },  -- 12 floats
					es  = pose.EasingStyle.Value,            -- Enum → int
					ed  = pose.EasingDirection.Value,        -- Enum → int
					w   = pose.Weight,
					sub = serializePoses(pose),              -- nested poses (children)
				}
			end
		end
		return data
	end

	-- Build the full animation data table
	local animData = {
		loop     = seq.Loop,
		priority = seq.Priority.Value,  -- AnimationPriority enum → int
		frames   = {},
	}

	for _, kf in ipairs(seq:GetKeyframes()) do
		table.insert(animData.frames, {
			t     = kf.Time,
			poses = serializePoses(kf),
		})
	end

	-- Encode to JSON
	local jsonStr = HttpService:JSONEncode(animData)

	-- Self-contained reconstruction script (copy-paste this into Studio)
	local template = [[
-- ╔══════════════════════════════════════════════════╗
-- ║  Auto-generated by AnimationPreview v2.0         ║
-- ║  Animation : %s
-- ╚══════════════════════════════════════════════════╝
local HttpService = game:GetService("HttpService")
local data = HttpService:JSONDecode([==[%s]==])

-- Enum lookup tables
local EASING_STYLES   = {[0]="Linear",[1]="Constant",[2]="Elastic",[3]="Cubic",[4]="Bounce"}
local EASING_DIRS     = {[0]="In",[1]="Out",[2]="InOut"}
local ANIM_PRIORITIES = {[0]="Idle",[1]="Movement",[2]="Action",[3]="Action2",[4]="Action3",[5]="Action4"}

local seq       = Instance.new("KeyframeSequence")
seq.Name        = "Restored_%s"
seq.Loop        = data.loop
seq.Priority    = Enum.AnimationPriority[ ANIM_PRIORITIES[data.priority] or "Action" ]

-- Build Pose hierarchy under a given parent (Keyframe or another Pose)
local function buildPoses(poseData, parent)
    for name, info in pairs(poseData) do
        local p            = Instance.new("Pose")
        p.Name             = name
        p.CFrame           = CFrame.new(table.unpack(info.cf))
        p.EasingStyle      = Enum.PoseEasingStyle    [ EASING_STYLES[info.es] or "Linear" ]
        p.EasingDirection  = Enum.PoseEasingDirection[ EASING_DIRS[info.ed]   or "In"     ]
        p.Weight           = info.w or 1
        p.Parent           = parent
        if info.sub then buildPoses(info.sub, p) end
    end
end

-- Reconstruct keyframes
for _, kfData in ipairs(data.frames) do
    local kf   = Instance.new("Keyframe")
    kf.Time    = kfData.t
    kf.Parent  = seq
    buildPoses(kfData.poses, kf)
end

-- Parent to selection or Workspace
local target = (game:GetService("Selection"):Get()[1]) or game.Workspace
seq.Parent   = target
--print(string.format("[AnimPreview] Restored '%%s' → %%s  (%%d keyframes)", target:GetFullName(), #data.frames))
]]

	local generated = template:format(
		displayName or seq.Name,   -- header comment
		jsonStr,                   -- embedded JSON
		seq.Name,                  -- seq.Name assignment
		displayName or seq.Name    -- print statement placeholder (first %s in runtime format string)
	)
	--print(generated)
	setclipboard(generated)

	-- Flash "Copied!" label for 1.8 seconds
	task.spawn(function()
		COPY_LABEL.Visible = true
		task.wait(1.8)
		COPY_LABEL.Visible = false
	end)

	-- Flash the accent separator on the title bar as visual confirmation
	task.spawn(function()
		for _ = 1, 3 do
			TB_SEP.BackgroundColor3 = C.SUCCESS
			task.wait(0.12)
			TB_SEP.BackgroundColor3 = C.ACCENT
			task.wait(0.12)
		end
	end)
end

-- ════════════════════════════════════════════════════
-- BUTTON FACTORY
-- Creates a rich animation entry button in the scroll list
-- ════════════════════════════════════════════════════
local selectedButton = nil  -- track which button is currently selected

local function createButton(displayName, seq, looped)
	local btn = Instance.new("TextButton")
	btn.Size             = UDim2.new(0.95, 0, 0, 46)
	btn.Text             = ""
	btn.BackgroundColor3 = C.BUTTON
	btn.BorderSizePixel  = 0
	btn.AutoButtonColor  = false
	btn.Name             = displayName
	corner(7, btn)

	-- Left accent stripe (changes colour on selection/hover)
	local stripe = Instance.new("Frame")
	stripe.Size             = UDim2.new(0, 3, 1, -10)
	stripe.Position         = UDim2.new(0, 5, 0, 5)
	stripe.BackgroundColor3 = C.ACCENT_DIM
	stripe.BorderSizePixel  = 0
	corner(4, stripe)
	stripe.Parent = btn

	-- Play icon
	local icon = Instance.new("TextLabel")
	icon.Size                  = UDim2.new(0, 18, 1, 0)
	icon.Position              = UDim2.new(0, 14, 0, 0)
	icon.Text                  = "▷"
	icon.TextColor3            = C.ACCENT_DIM
	icon.Font                  = Enum.Font.GothamBold
	icon.TextScaled            = true
	icon.BackgroundTransparency = 1
	icon.Parent                = btn

	-- Animation display name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size                 = UDim2.new(1, -82, 0, 22)
	nameLabel.Position             = UDim2.new(0, 38, 0, 5)
	nameLabel.Text                 = displayName
	nameLabel.TextColor3           = C.TEXT
	nameLabel.Font                 = Enum.Font.GothamBold
	nameLabel.TextSize             = 12
	nameLabel.TextTruncate         = Enum.TextTruncate.AtEnd
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextXAlignment       = Enum.TextXAlignment.Left
	nameLabel.Parent               = btn

	-- Sub-text: duration / priority / keyframe count (filled async below)
	local subLabel = Instance.new("TextLabel")
	subLabel.Size                 = UDim2.new(1, -82, 0, 16)
	subLabel.Position             = UDim2.new(0, 38, 1, -20)
	subLabel.Text                 = "loading…"
	subLabel.TextColor3           = C.TEXT_DIM
	subLabel.Font                 = Enum.Font.Gotham
	subLabel.TextSize             = 10
	subLabel.BackgroundTransparency = 1
	subLabel.TextXAlignment       = Enum.TextXAlignment.Left
	subLabel.Parent               = btn

	-- LOOP / ONCE badge (top-right corner of button)
	local badge = Instance.new("TextLabel")
	badge.Size             = UDim2.new(0, 40, 0, 16)
	badge.Position         = UDim2.new(1, -46, 0, 6)
	badge.Text             = looped and "LOOP" or "ONCE"
	badge.TextColor3       = looped and C.SUCCESS or C.TEXT_DIM
	badge.Font             = Enum.Font.GothamBold
	badge.TextSize         = 9
	badge.BackgroundColor3 = looped and Color3.fromRGB(18, 46, 28) or C.SURFACE
	badge.BorderSizePixel  = 0
	corner(3, badge)
	badge.Parent = btn

	-- Populate sub-label once keyframe data is available
	task.defer(function()
		local kfs = seq:GetKeyframes()
		if kfs and #kfs > 0 then
			table.sort(kfs, function(a, b) return a.Time < b.Time end)
			local dur  = kfs[#kfs].Time
			local pri  = tostring(seq.Priority):match("%.(.+)$") or "?"
			subLabel.Text = ("%.2fs  •  %s  •  %d kf"):format(dur, pri, #kfs)
		else
			subLabel.Text = "no keyframes"
		end
	end)

	btn.Parent = SCROLL
	EMPTY_LABEL.Visible = false  -- hide empty-state message once we have at least one button

	-- ── Hover effects ───────────────────────────────
	btn.MouseEnter:Connect(function()
		if btn ~= selectedButton then
			TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = C.BUTTON_HOV }):Play()
		end
		stripe.BackgroundColor3 = C.ACCENT
	end)
	btn.MouseLeave:Connect(function()
		if btn ~= selectedButton then
			TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = C.BUTTON }):Play()
			stripe.BackgroundColor3 = C.ACCENT_DIM
		end
	end)

	-- ── Click: select + play + copy ─────────────────
	btn.MouseButton1Click:Connect(function()
		-- Deselect previous button
		if selectedButton and selectedButton ~= btn then
			TweenService:Create(selectedButton, TweenInfo.new(0.15), { BackgroundColor3 = C.BUTTON }):Play()
		end
		-- Select this button
		selectedButton = btn
		TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = C.SELECTED }):Play()
		stripe.BackgroundColor3 = C.ACCENT
		icon.Text       = "▶"
		icon.TextColor3 = C.ACCENT

		playOnClone(seq, looped, displayName)
		copyAnimationAsScript(seq, displayName)
	end)

	return btn
end

-- ════════════════════════════════════════════════════
-- SEARCH FILTER
-- ════════════════════════════════════════════════════
local allEntries = {}  -- { displayName: string, btn: TextButton }

local function applyFilter(query)
	local q = query:lower()
	for _, entry in ipairs(allEntries) do
		entry.btn.Visible = (q == "" or entry.displayName:lower():find(q, 1, true) ~= nil)
	end
end

SEARCH_BOX:GetPropertyChangedSignal("Text"):Connect(function()
	applyFilter(SEARCH_BOX.Text)
end)

-- ════════════════════════════════════════════════════
-- ANIMATION DETECTION & REGISTRATION
-- ════════════════════════════════════════════════════
local registered = {}  -- uniqueKey → true, prevents duplicate buttons

local function registerTrack(track)
	local anim = track.Animation
	if not anim then return end

	local animId   = anim.AnimationId
	local animName = anim.Name

	-- Ignore blank or null asset IDs
	if animId == "" or animId == "rbxassetid://0" then return end

	local key = animName .. "_" .. animId
	if registered[key] then return end
	registered[key] = true  -- mark early to prevent concurrent duplicates

	task.spawn(function()
		-- Fetch the KeyframeSequence from the CDN
		local ok, seq = pcall(
			KeyframeSequenceProvider.GetKeyframeSequenceAsync,
			KeyframeSequenceProvider,
			animId
		)

		if not ok or not seq then
			warn("[AnimPreview] Fetch failed: " .. animName .. " (" .. animId .. ")")
			registered[key] = nil  -- allow retry on next play
			return
		end

		-- Store in ReplicatedStorage so it survives playback calls
		seq.Name   = "AnimPreview_" .. animName
		seq.Parent = game:GetService("ReplicatedStorage")

		local shortId     = animId:match("%d+$") or "0"
		local displayName = animName .. " [" .. shortId .. "]"
		local looped      = track.Looped

		local btn = createButton(displayName, seq, looped)
		table.insert(allEntries, { displayName = displayName, btn = btn })

		-- Apply any active search filter to the newly added button
		local q = SEARCH_BOX.Text:lower()
		if q ~= "" and not displayName:lower():find(q, 1, true) then
			btn.Visible = false
		end
	end)
end

-- Scan tracks that were already playing when this script injected
task.spawn(function()
	task.wait(0.1)
	for _, track in ipairs(ANIMATOR:GetPlayingAnimationTracks()) do
		registerTrack(track)
	end
end)

-- Continuously catch new tracks going forward
ANIMATOR.AnimationPlayed:Connect(registerTrack)
