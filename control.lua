local DEBUG = true

scripts = {} -- custom scripts
local funcs = {} -- Functions bound to their respective game event

local function formatLuaObject(v, handler)
	if v.__self and type(v.__self) == "userdata" then
		if v.valid == true then
			if type(v.help) == "function" then
			
				-- Format LuaObjects nicely
				local help = v.help()
				local l = help:find("[\r\n]label %[RW?%]") and v.label or nil
				local n = help:find("[\r\n]name %[RW?%]") and v.name or nil
				local t = help:find("[\r\n]type %[RW?%]") and v.type or nil
				local id = l and "'"..l.."'" or ""
				if l and n then id = id.." : " end
				id = id..(n or "")
				if t ~= n then
					if n and t then id = id.." : " end
					id = id..(t or "")
				end
				
				return help:gsub("^Help for (%w+):.*$", "%1").."<"..id..">"
			else
				-- No help function exists?
				return serpent.line(v)
			end
		else
			return "?<INVALID>"
		end
	else
		return handler(v)
	end
end

local function formatTable(tbl)
	local new = {}
	
	for k,v in pairs(tbl) do
		if type(v) == "table" then
			new[k] = formatLuaObject(v, function(_v) return formatTable(_v) end)
		elseif type(v) == "function" then
			new[k] = tostring(k).."()"
		else
			new[k] = tostring(v)
		end
	end
	
	return new
end

function dlog(...) -- Print debug message
	local tick = 0
	if game then tick = game.tick end
	local msg = tick.." [BPT]"
	
	for key,val in pairs({...}) do
		if type(val) == "table" then
			msg = msg.." "..formatLuaObject(val, function(_v) return serpent.line(formatTable(_v)) end)
		elseif type(val) == "function" then
			msg = msg.." "..tostring(key).."()"
		else
			msg = msg.." "..tostring(val)
		end
	end
	
	log(msg)
	if DEBUG and game then game.print(msg) end
end

local function addScript(name) -- Add a custom script
	scripts[name] = require("scripts."..name)
	return scripts[name]
end

local function addGUIScript(name)
	local gui = addScript(name..".gui-templates") -- load templates
	scripts[name..".gui-templates"] = gui[1]
	gui[2](addScript(name..".controller")) -- load controller
	
	gui[1].class = name
	scripts["gui-tools"].registerTemplates(gui[1]) -- register gui event handlers (like button onClick events etc.)
	return gui[1]
end

local function registerFunc(name, id)
	funcs[id or name] = {}
	for _,script in pairs(scripts) do
		if script[name] then table.insert(funcs[id or name], script[name]) end
	end
end

local function handleEvent(event) -- Calls all script-functions with the same name as the game event that was just triggered
	for _,func in pairs(funcs[event.input_name or event.name]) do func(event) end
end

local function registerHandler(name, id) -- Register appropriate handler functions for game events if needed
	registerFunc(name, id ~= true and id or nil)
	if id ~= true and #funcs[id or name] > 0 then 
		if id then
			script.on_event(id, handleEvent)
		else
			script[name](function(data) handleEvent{ name = name, data = data } end)
		end
	end
end

-- Load all custom scripts
addScript("util")
addScript("setup")
addScript("components")
addScript("gui-tools")
addGUIScript("entity-notes")
addGUIScript("blueprint-notes")

-- Register every script-function with the same name as a game event to be called when it occurs
registerHandler("on_init")
registerHandler("on_load")
registerHandler("on_configuration_changed")
for name,event in pairs(defines.events) do registerHandler(name, event) end

-- Register custom input events
registerHandler("on_edit_blueprint", "edit-blueprint")

registerHandler("on_scripts_initialized", true)
handleEvent{ name = "on_scripts_initialized" }