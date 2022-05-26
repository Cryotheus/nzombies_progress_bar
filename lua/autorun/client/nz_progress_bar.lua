if engine.ActiveGamemode() ~= "nzombies" then return end

--locals
local bar_mat = Material("bar/bloodline_bar.png")
local bar_mat_bg = Material("bar/bloodline_bar_back.png")

local endless = false --TODO: fix this
local scr_h
local scr_w
local zombies_killed = 0
local zombies_killed_text = ""
local zombies_killed_text_font = ""
local zombies_max = 1

local pb_h
local pb_stencil_w = 0
local pb_w
local pb_x
local pb_text_x
local pb_text_y
local pb_y
local pb_y_current_percent = 0
local pb_y_current_percent_inc = engine.TickInterval()
local pb_y_percent = 0
local progress_current_percent = 0
local progress_current_percent_inc = engine.TickInterval()
local progress_percent = 0

--convars
local nz_progbar_enabled = CreateClientConVar("nz_progbar_enabled", "1", true, false, "Should the bar be renderd?", 0, 1)
local nz_progbar_scale = CreateClientConVar("nz_progbar_scale", "0.5", true, false, "Changes the size of the bar.", 0.05, 20)
local nz_progbar_text_enabled = CreateClientConVar("nz_progbar_text_enabled", "1", true, false, "Should the text on the progress bar be renderd?", 0, 1)
local nz_progbar_y_pos = CreateClientConVar("nz_progbar_y_pos", "5", true, false, "The y position of the progress bar from the top of the screen.", 0, 65536)
local nz_progbar_text_y_pos = CreateClientConVar("nz_progbar_text_y_pos", "5", true, false, "The y position offset for the text, it is parented to the progress bar.", -65536, 65536)

--cached
local cvars_bar_enabled = nz_progbar_enabled:GetBool()
local cvars_bar_text_enabled = nz_progbar_text_enabled:GetBool()
local cvars_bar_text_y_pos = nz_progbar_text_y_pos:GetFloat()
local cvars_bar_y = nz_progbar_y_pos:GetFloat()
local scale = nz_progbar_scale:GetFloat()

--caching functions locally so we don't have to keep looking them up in _G
local fl_draw_DrawText = draw.DrawText
local fl_render_ClearStencil = render.ClearStencil
local fl_render_SetStencilCompareFunction = render.SetStencilCompareFunction
local fl_render_SetStencilEnable = render.SetStencilEnable
local fl_render_SetStencilFailOperation = render.SetStencilFailOperation
local fl_render_SetStencilPassOperation = render.SetStencilPassOperation
local fl_render_SetStencilReferenceValue = render.SetStencilReferenceValue
local fl_render_SetStencilTestMask = render.SetStencilTestMask
local fl_render_SetStencilWriteMask = render.SetStencilWriteMask
local fl_render_SetStencilZFailOperation = render.SetStencilZFailOperation
local fl_surface_SetDrawColor = surface.SetDrawColor
local fl_surface_SetMaterial = surface.SetMaterial
local fl_surface_DrawRect = surface.DrawRect
local fl_surface_DrawTexturedRect = surface.DrawTexturedRect

--globals
NZProgressBarDynamicFontData = NZProgressBarDynamicFontData or {}

--local functions
local function calc_vars(given_scr_w, given_scr_h)
	scr_h =  given_scr_h or ScrH()
	scr_w = given_scr_w or ScrW()
	
	pb_w = scale * 930
	pb_h = scale * 66
	
	pb_x = scr_w * 0.5 - scale * 465
	pb_y = pb_y_current_percent * (pb_w + 20) - pb_w
	
	pb_text_x = scr_w * 0.5
	pb_text_y = pb_y + cvars_bar_text_y_pos * scale
end

local function calculate()
	--for the red part
	progress_current_percent = progress_current_percent < progress_percent and math.min(progress_current_percent + progress_current_percent_inc, progress_percent) or math.max(progress_current_percent - progress_current_percent_inc, progress_percent)
	pb_stencil_w = pb_x + progress_current_percent * pb_w
	
	--for the bar sliding up and down
	pb_y_current_percent = pb_y_current_percent < pb_y_percent and math.min(pb_y_current_percent + pb_y_current_percent_inc, pb_y_percent) or math.max(pb_y_current_percent - pb_y_current_percent_inc, pb_y_percent)
	pb_y = pb_y_current_percent * (pb_w * 0.5 + cvars_bar_y) - pb_w * 0.5
	pb_text_y = pb_y + cvars_bar_text_y_pos * scale
	
	if pb_y_current_percent == 0 then
		prog_bar_rendering = false
		
		hook.Remove("HUDPaint", "prog_bar_hudpaint_hook")
		hook.Remove("Tick", "prog_bar_tick_hook")
	end
end

local function disable_bar() pb_y_percent = 0 end

local function draw_bar()
	fl_surface_SetDrawColor(255, 255, 255, 255)
	fl_surface_SetMaterial(bar_mat_bg)
	fl_surface_DrawTexturedRect(pb_x, pb_y, pb_w, pb_h)
	
	fl_render_ClearStencil()
	fl_render_SetStencilEnable(true)
	fl_render_SetStencilCompareFunction(STENCIL_NEVER)
	fl_render_SetStencilPassOperation(STENCIL_KEEP)
	fl_render_SetStencilFailOperation(STENCIL_REPLACE)
	fl_render_SetStencilZFailOperation(STENCIL_KEEP)
	fl_render_SetStencilWriteMask(0xFF)
	fl_render_SetStencilTestMask(0xFF)
	fl_render_SetStencilReferenceValue(1)
	
	fl_surface_DrawRect(0, 0, pb_stencil_w, scr_h)
	
	fl_render_SetStencilCompareFunction(STENCIL_EQUAL)
	
	fl_surface_SetMaterial(bar_mat)
	fl_surface_DrawTexturedRect(pb_x, pb_y, pb_w, pb_h)
	
	fl_render_SetStencilEnable(false)
	
	if cvars_bar_text_enabled ~= 0 then fl_draw_DrawText(zombies_killed_text, zombies_killed_text_font, pb_text_x, pb_text_y, color_white, TEXT_ALIGN_CENTER) end
end

local function enable_bar()
	if cvars_bar_enabled ~= 0 then
		if not prog_bar_rendering then
			hook.Add("HUDPaint", "prog_bar_hudpaint_hook", draw_bar)
			hook.Add("Tick", "prog_bar_tick_hook", calculate)
		end
		
		pb_y_percent = 1
		prog_bar_rendering = true, true
	end
end

local function register_font(size, weight)
	if CryotheumDynamicFontData[size] then
		if CryotheumDynamicFontData[size][weight] then return
		else
			CryotheumDynamicFontData[size][weight] = true
			
			create_font(size, weight)
		end
	else
		CryotheumDynamicFontData[size] = {[weight] = true}
		
		create_font(size, weight)
	end
end

local function set_font(size, weight)
	zombies_killed_text_font = "pbgenfont" .. size .. "." .. weight
	
	register_font(size, weight)
end

--post function setup
calc_vars()
set_font(22, 300)

--cvars
cvars.AddChangeCallback("nz_progbar_enabled", function(name, old_value, new_value) cvars_bar_enabled = nz_progbar_enabled:GetBool() end)
cvars.AddChangeCallback("nz_progbar_text_enabled", function(name, old_value, new_value) cvars_bar_text_enabled = nz_progbar_text_enabled:GetBool() end)
cvars.AddChangeCallback("nz_progbar_y_pos", function(name, old_value, new_value) cvars_bar_y = nz_progbar_y_pos:GetFloat() end)

cvars.AddChangeCallback("nz_progbar_scale", function(name, old_value, new_value)
	scale = nz_progbar_scale:GetFloat()
	
	calc_vars()
	set_font(44 * scale, 300)
end)

cvars.AddChangeCallback("nz_progbar_text_y_pos", function(name, old_value, new_value)
	cvars_bar_text_y_pos = nz_progbar_text_y_pos:GetFloat()
	
	calc_vars()
end)

--hooks
hook.Add("InitPostEntity", "NZProgressBar", function()
	net.Start("nz_progress_bar")
	net.SendToServer()
end)

hook.Add("OnScreenSizeChanged", "prog_bar_screen_res_changed_hook", function() calc_vars(ScrH(), ScrW()) end)
hook.Add("OnRoundCreative", "prog_bar_onroundend_hook", disable_bar)
hook.Add("OnRoundEnd", "prog_bar_onroundend_hook", disable_bar)

hook.Add("OnRoundPreparation", "prog_bar_onroundprep_hook", function(round)
	endless = (round or 0) < 0 --todo: fix this
	
	disable_bar()
end)

hook.Add("OnRoundStart", "prog_bar_onroundstart_hook", function()
	progress_current_percent = 0
	progress_percent = 0
	
	enable_bar()
end)

--net
net.Receive("nz_progress_bar", function()
	if net.ReadBool() then
		zombies_max = net.ReadUInt(16)
		zombies_killed_text = "zombies killed  0 / " .. zombies_max
		
		return
	end
	
	zombies_killed = net.ReadUInt(16)
	zombies_killed_text = "zombies killed  " .. zombies_killed .. " / " .. (endless and "∞" or zombies_max)
	progress_percent = endless and math.random() or zombies_killed / zombies_max
end)