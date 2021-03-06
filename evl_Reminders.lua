local addonName, addon = ...

addon.config = {
	scale = 1,
	position = {"CENTER", UIParent, "CENTER", 0, 300},

	consumables = {
		enabled = true,
		foodThresholdTime = 10,
		flaskThresholdTime = 5
	},

	druid = {
		enabled = true
	},

	hunter = {
		enabled = true
	},

	inventory = {
		enabled = true,
		repairThreshold = 55
	},

	mage = {
		enabled = true,
	},

	monk = {
		enabled = true,
	},

	paladin = {
		enabled = true,
		blessings = {"Blessing of Might", "Blessing of Kings"},
		righteousFury = true
	},

	priest = {
		enabled = true,
		inners = {"Inner Fire", "Inner Will"}
	},

	rogue = {
		enabled = true,
		mainHandPoisons = {"Deadly Poison", "Wound Poison"},
		offHandPoisons = {"Crippling Poison", "Leeching Poison", "Paralytic Poison"},
		thresholdTime = 10,
	},

	shaman = {
		enabled = true,
		shields = {"Water Shield", "Lightning Shield"},
		mainHandEnchants = {"Windfury Weapon", "Flametongue Weapon"},
		offHandEnchants = {"Flametongue Weapon", "Windfury Weapon"},
		thresholdTime = 10
	},

	warlock = {
		enabled = true,
		thresholdTime = 10
	},
}

addon.playerClass = select(2, UnitClass("player"))

local config = addon.config
local frame = CreateFrame("Frame", nil, UIParent)
local reminders = {}

local onEnter = function(self)
	addon:PrepareReminderTooltip(self)

	if self.tooltip then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(self.tooltip)
	else
		local left = self:GetAttribute("item") or self:GetAttribute("item1")
		local button = right and "Left-click" or "Click"

		if left then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine(button .. " to use " .. left)
		else
			left = self:GetAttribute("spell") or self:GetAttribute("spell1")
			if left then
				GameTooltip:AddLine(" ")
				GameTooltip:AddLine(button .. " to cast " .. left)
			end
		end

		local right = self:GetAttribute("item2")
		if right then
			if not left then
				GameTooltip:AddLine(" ")
			end

			GameTooltip:AddLine("Right-click to use " .. right)
		else
			right = self:GetAttribute("spell2")
			if right then
				if not left then
					GameTooltip:AddLine(" ")
				end

				GameTooltip:AddLine("Right-click to cast " .. right)
			end
		end
	end

	GameTooltip:Show()
end

local onLeave = function(self)
	GameTooltip:Hide()
end

local suppressReminder = function(self, reminder, suppressTime)
	reminder.suppressed = true
	reminder.suppressTime = suppressTime and (GetTime() + suppressTime) or 0

	addon:UpdateReminder(reminder)
end

local menu
local menuFrame = CreateFrame("Frame", addonName .. "Menu", UIParent, "UIDropDownMenuTemplate")
local showReminderMenu = function(self)
	menu = {
		{text = self.title or self.name, isTitle = true},
		{text = "Suppress for 5 minutes", func = suppressReminder, arg1 = self, arg2 = 5 * 60},
		{text = "Suppress for 30 minutes", func = suppressReminder, arg1 = self, arg2 = 30 * 60},
		{text = "Disable for this session", func = suppressReminder, arg1 = self}
	}

	EasyMenu(menu, menuFrame, "cursor", nil, nil, "MENU")
end

function addon:PrepareReminderTooltip(reminder)
	GameTooltip:SetOwner(reminder, "ANCHOR_RIGHT")
	GameTooltip:SetWidth(250)
	GameTooltip:AddLine(reminder.title or reminder.name)
end

function addon:AddReminder(name, callback, attributes, icon, color, tooltip, activeWhileResting)
	local buttonName = "ReminderButton" .. frame:GetNumChildren()
	local reminder = CreateFrame("Button", buttonName, frame, "SecureActionButtonTemplate, ActionButtonTemplate")

	local texture = reminder:CreateTexture(nil, "BACKGROUND")
	texture:SetAllPoints(reminder)
	texture:SetTexCoord(.07, .93, .07, .93)

	_G[buttonName .. "Icon"]:SetTexture(texture)

	reminder.name = name
	reminder.icon = icon
	reminder.tooltip = tooltip

	reminder.callback = callback
	reminder.active = nil
	reminder.activeWhileResting = type(activeWhileResting) == 'number' and activeWhileResting or (activeWhileResting and 1 or 0)
	reminder.suppressed = false
	reminder.suppressTime = 0

	reminder:RegisterForClicks("AnyUp")
	reminder:SetScript("OnEnter", onEnter)
	reminder:SetScript("OnLeave", onLeave)
	reminder:SetAttribute("alt-type*", "showMenu")

	reminder.showMenu = showReminderMenu
	reminder.setColor = function(...) texture:SetVertexColor(...) end
	reminder.setIcon = function(icon)
		if type(icon) == "string" then
			icon = ((icon and icon:find("\\")) and "" or "Interface\\Icons\\") .. (icon or "Temp")
		end
		texture:SetTexture(icon)
	end

	if attributes then
		for key, value in pairs(attributes) do
			reminder:SetAttribute(key, value)
		end
	end

	if color then
		reminder.setColor(unpack(color))
	end

	table.insert(reminders, reminder)

	return reminder
end

function addon:UpdateReminderState(reminder, ...)
	if reminder.suppressed and reminder.suppressTime > 0 and reminder.suppressTime < GetTime() then
		reminder.suppressed = false
	end

	local previousState = reminder.active
	local resting = IsResting()

	reminder.active = not reminder.suppressed and ((resting and reminder.activeWhileResting > 0) or (not resting and reminder.activeWhileResting < 2)) and reminder.callback(reminder, ...)

	return previousState, reminder.active
end

function addon:UpdateReminder(reminder, ...)
	local previousState, newState = self:UpdateReminderState(reminder, ...)

	if newState ~= previousState then
		self:UpdateLayout()
	end
end

function addon:UpdateAllReminders()
	for _, reminder in pairs(reminders) do
		self:UpdateReminderState(reminder)
	end

	self:UpdateLayout()
end

function addon:UpdateReminderIcon(reminder)
	local icon = reminder.icon

	if not icon then
		local spell = reminder:GetAttribute("spell") or reminder:GetAttribute("spell1")

		if spell then
			icon = select(3, GetSpellInfo(spell))
		else
			icon = GetItemIcon(reminder:GetAttribute("item") or reminder:GetAttribute("item1"))
		end
	end

	if icon then
		reminder.setIcon(icon)
	end
end

function addon:UpdateLayout()
	local inCombat = InCombatLockdown()
	local previousReminder

	for _, reminder in pairs(reminders)  do
		if reminder.active then
			if not inCombat then
				if previousReminder then
					reminder:SetPoint("TOPLEFT", previousReminder, "TOPRIGHT", 5, 0)
				else
					reminder:SetPoint("TOPLEFT", frame)
				end

				self:UpdateReminderIcon(reminder)

				reminder:Show()
			end

			reminder:SetAlpha(1)

			previousReminder = reminder
		else
			if not inCombat then
				reminder:Hide()
			end

			reminder:SetAlpha(0)
		end
	end
end

local lastUpdate = 0
frame:SetScript("OnUpdate", function(self, elapsed)
	lastUpdate = lastUpdate + elapsed

	if lastUpdate > 0.5 then
		lastUpdate = 0

		addon:UpdateAllReminders()
	end
end)

frame:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_ENTERING_WORLD" then
		self:UnregisterEvent(event)

		frame:SetWidth(36)
		frame:SetHeight(36)
		frame:SetScale(config.scale)
		frame:SetPoint(unpack(config.position))
	end

	if event == "PLAYER_REGEN_ENABLED" then
		addon:UpdateLayout()
	else
		addon:UpdateAllReminders()
	end
end)

frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
