local w = 6
local h = 4
local plate_bounds = {
	-w/16, -8/16, -h/16,
	 w/16, -7/16,  h/16,
};
local plate_box = {
	type = "fixed",
	fixed = plate_bounds,
};



local count = function(v) return (math.abs(v) == 1) and 1 or 0 end
local axis_major = function(dir)
	assert(count(dir.x) + count(dir.y) + count(dir.z) == 1)
	if dir.y == 1 then
		return 0
	elseif dir.y == -1 then
		return 5
	elseif dir.x == 1 then
		return 3
	elseif dir.x == -1 then
		return 4
	elseif dir.z == 1 then
		return 1
	elseif dir.z == -1 then
		return 2
	end
	error("unreachable??")
end
local saner_facedir_place = function(pos, placer, item, pointed)
	if pointed.type ~= "node" then return end
	if not placer then return end
	local dir = vector.subtract(pointed.above, pointed.under)
	local major = axis_major(dir)
	local sneak = false
	-- don't blow up on less than perfect fake players not supporting control reporting
	if placer.get_player_control then
		sneak = placer:get_player_control().sneak
	end

	-- when placing on the ground or floor,
	-- we have to work out the direction the player is facing.
	-- thankfully, facedir placement already handles the rotation about the axis for us.
	local n = minetest.get_node(pos)
	local minor = n.param2

	local not_floor = (major > 0)
	if not_floor then
		-- for some reason, Z/-Z minor values for downwards major facing
		-- are flipped from what would be intuitive.
		-- I really find the facedir encoding a bit bonkers...
		if major == 5 then
			if minor == 2 then
				minor = 0
			elseif minor == 0 then
				minor = 2
			end
		end
		n.param2 = (major * 4) + minor
		modified = true
	end
	if modified then
		minetest.swap_node(pos, n)
	end
end




local version = 4
-- important, ^^ bump this every time the spec is changed
local spec =
	"formspec_version[1]" ..
	"size[8,6,true]" ..
	"textarea[1,0;6,6;text;;${infotext}]" ..
	"field_close_on_enter[text;true]" ..
	"button_exit[3,5;2,1;submit;Proceed]"

local sign_setup = function(pos)
	local meta = minetest.get_meta(pos)
	meta:set_string("formspec", spec)
end

minetest.register_lbm({
	label = "Update lightweight_signs formspecs",
	name = "lightweight_signs:update_formspec_v" .. version,
	nodenames = {"group:_mod_lightweight_signs"},
	action = function(pos, node)
		sign_setup(pos)
	end
})



local smack_player = function(pos, sender, name)
	minetest.record_protection_violation(pos, name)
	-- XXX: per-client translation?
	minetest.chat_send_player(name, "# This sign is in a protected area, you can't write it.")
end
local maxlen = 1024
local lenerror = "# Input text was too long, needs to be <= " .. maxlen .. " bytes."
local save_text = function(pos, formname, fields, sender)
	-- fail shut and DO NOT allow a potential protection bypass if anything catches fire.
	if (not sender) then return end
	if (not sender.get_player_name) then return end

	-- allow read-only usage without smacking them for modifications
	if fields.quit == "true" and not fields.submit then return end

	local name = sender:get_player_name()
	if minetest.is_protected(pos, name) then
		smack_player(pos, sender, name)
		return
	end

	local text = assert(fields.text, "form submit improperly called.")
	if #text > maxlen then
		minetest.chat_send_player(name, lenerror)
		return
	end
	minetest.get_meta(pos):set_string("infotext", text)
end




local b = minetest.registered_nodes["default:wood"].tiles[1]
local f = "((" .. b .. ")^lightweight_signs_overlay_plate_border.png)"
minetest.register_node("lightweight_signs:test", {
	drawtype = "nodebox",
	node_box = plate_box,
	tiles = { f, b,b,b,b,b },
	paramtype = "light",
	paramtype2 = "facedir",
	sunlight_propagates = true,
	walkable = true,
	after_place_node = saner_facedir_place,
	on_construct = sign_setup,
	groups = { oddly_breakable_by_hand = 1, _mod_lightweight_signs = 1 },
	on_receive_fields = save_text,
});

