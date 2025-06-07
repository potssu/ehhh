--[=[
    Module: SimpleUI
    Author: potssu
    Version: 1.0

    This module creates a draggable GUI for a single input.
    It is designed to be required by a LocalScript for a single use.

    API:
    - SimpleUI.new(name, description) : Creates and displays the GUI.
    - SimpleUI:OnFire(callback) : Sets the function to be called when the "Fire!" button is clicked. The callback receives the number from the input box.
    - SimpleUI:Destroy() : Destroys the GUI.
--]=]

local SimpleUI = {}
SimpleUI.__index = SimpleUI

local cref = cloneref or function(o) return o end
local MarketplaceService = cref(game:GetService("MarketplaceService"))
local Players = cref(game:GetService("Players"))
local UserInputService = cref(game:GetService("UserInputService"))

local player = Players.LocalPlayer
local playerGui = gethui() or player:WaitForChild("PlayerGui")

-- A helper function to create and configure an instance
local function create(instanceType, properties)
    local obj = Instance.new(instanceType)
    for prop, value in pairs(properties) do
        obj[prop] = value
    end
    return obj
end

function SimpleUI.new(name, description)
    local self = setmetatable({}, SimpleUI)

    self.fireCallback = nil -- Callback for the fire button
    self.callbackRunning = nil
    
    -- Get Game Name in a protected call
    local success, result = pcall(function()
        return MarketplaceService:GetProductInfo(game.PlaceId)
    end)
        
    local gameName = success and result.Name or "Unknown Game"

    -- // 1. Create the GUI Elements
    -- ===================================

    -- Main ScreenGui Container
    self.screenGui = create("ScreenGui", {
        Name = "SimpleUI",
        Parent = playerGui,
        ResetOnSpawn = false
    })

    -- Main frame
    local mainFrame = create("Frame", {
        Name = "MainFrame",
        Parent = self.screenGui,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0.65, 0, 0.35, 0),
        BackgroundColor3 = Color3.fromRGB(28, 28, 28),
        BorderSizePixel = 0
    })

    create("UIAspectRatioConstraint", {
        Parent = mainFrame,
        AspectRatio = 1.6,
        DominantAxis = Enum.DominantAxis.Width
    })

    create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = mainFrame })

    -- Draggable pink title bar
    local titleBar = create("Frame", {
        Name = "TitleBar",
        Parent = mainFrame,
        Size = UDim2.new(1, 0, 0.16, 0),
        BackgroundColor3 = Color3.fromRGB(255, 182, 193),
        BorderSizePixel = 0
    })

    create("UIPadding", {
        Parent = titleBar,
        PaddingRight = UDim.new(0.15, 0)
    })

    -- Title text
    create("TextLabel", {
        Name = "TitleLabel",
        Parent = titleBar,
        Position = UDim2.new(0, -9, 0, 0),
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.SourceSansBold,
        Text = name,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextScaled = true,
        Active = false,
        ZIndex = 1
    })

    -- Close button
    local closeButton = create("TextButton", {
        Name = "CloseButton",
        Parent = titleBar,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 30, 0.5, 0),
        Size = UDim2.new(0.18, 0, 0.65, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.SourceSansBold,
        Text = "X",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextScaled = false,
        TextSize = 16,
        BorderSizePixel = 0,
        ZIndex = 2
    })

    -- Game Name Label
    create("TextLabel", {
        Name = "GameNameLabel",
        Parent = mainFrame,
        Position = UDim2.new(0.5, 0, 0.20, 0),
        AnchorPoint = Vector2.new(0.5, 0),
        Size = UDim2.new(0.9, 0, 0.11, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.SourceSansBold,
        Text = "Game: " .. gameName,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextScaled = true,
    })

    -- Info label
    create("TextLabel", {
        Name = "InfoLabel",
        Parent = mainFrame,
        Position = UDim2.new(0.5, 0, 0.35, 0),
        AnchorPoint = Vector2.new(0.5, 0),
        Size = UDim2.new(0.9, 0, 0.14, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.SourceSans,
        Text = description,
        TextColor3 = Color3.fromRGB(220, 220, 220),
        TextScaled = true,
        TextWrapped = true
    })

    -- Text input box
    local inputBox = create("TextBox", {
        Name = "InputBox",
        Parent = mainFrame,
        Position = UDim2.new(0.5, 0, 0.53, 0),
        AnchorPoint = Vector2.new(0.5, 0),
        Size = UDim2.new(0.85, 0, 0.17, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        PlaceholderText = "E.g: 2",
        Text = "",
        Font = Enum.Font.SourceSans,
        TextColor3 = Color3.fromRGB(0, 0, 0),
        ClearTextOnFocus = false,
        BorderSizePixel = 0,
        TextScaled = true
    })

    create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = inputBox })

    -- Fire button
    local fireButton = create("TextButton", {
        Name = "FireButton",
        Parent = mainFrame,
        Position = UDim2.new(0.5, 0, 0.77, 0),
        AnchorPoint = Vector2.new(0.5, 0),
        Size = UDim2.new(0.85, 0, 0.18, 0),
        BackgroundColor3 = Color3.fromRGB(255, 182, 193),
        Font = Enum.Font.SourceSansBold,
        Text = "Fire!",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        TextScaled = true
    })

    create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = fireButton })

    -- // 2. Add Functionality
    -- ===================================================================

    -- Draggable UI
    local dragging = false
    local dragStart = nil
    local startPos = nil

    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and dragging then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- Close Button
    closeButton.MouseButton1Click:Connect(function()
        self:Destroy()
    end)

    -- InputBox Filter
    inputBox:GetPropertyChangedSignal("Text"):Connect(function()
        local sanitizedText = string.gsub(inputBox.Text, "%D", "")
        if inputBox.Text ~= sanitizedText then
            inputBox.Text = sanitizedText
        end
    end)

    -- Fire Button Logic
    fireButton.MouseButton1Click:Connect(function()
        if not self.fireCallback or self.callbackRunning then return end
        
        local inputText = inputBox.Text
        if not inputText or inputText == "" then return end
        
        local number = tonumber(inputText)
        if number then
            -- Call the external function
            fireButton.AutoButtonColor = false
            fireButton.Active = false
            fireButton.Text = "Wait..."
            self.callbackRunning = true
                
            task.spawn(function()
                self.fireCallback(number)
                self.callbackRunning = false
            end)
                
            repeat task.wait() until not self.callbackRunning
                
            fireButton.AutoButtonColor = true
            fireButton.Active = true
            fireButton.Text = "Fire!"
        end
    end)
    
    return self
end

-- API method to set the callback for the fire button
function SimpleUI:OnFire(callback)
    if typeof(callback) == "function" then
        self.fireCallback = callback
    else
        error("Expects a function as an argument.")
    end
end

-- API method to destroy the GUI
function SimpleUI:Destroy()
    if self.screenGui then
        self.screenGui:Destroy()
        self.screenGui = nil -- Clear reference for garbage collection
    end
end

return SimpleUI
