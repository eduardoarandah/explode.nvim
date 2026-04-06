--- @module 'explode'
--- A Neovim plugin that creates a particle physics explode of the current buffer.
--- Documentation links:
--- Neovim API: :help api
--- Libuv (uv) Timer: :help uv.new_timer() or https://github.com/luvit/luv/blob/master/docs.md
--- Floating Windows: :help nvim_open_win()

local M = {}
local api = vim.api
local uv = vim.uv

local timer = nil
local float_win = nil
local float_buf = nil

M.defaults = {
	horizontal_speed = 25.0,
	vertical_speed = 2.0,
	gravity = 0.1,
	bounce = 0.5,
	friction = 0.6,
}

--- Stop the animation and delete the floating window.
--- Handles nil checks for the timer to prevent "index a nil value" errors.
local function cleanup()
	if timer then
		-- is_closing() prevents errors if cleanup is called twice in the same loop
		if not timer:is_closing() then
			timer:stop()
			timer:close()
		end
		timer = nil
	end
	if float_win and api.nvim_win_is_valid(float_win) then
		api.nvim_win_close(float_win, true)
		float_win = nil
	end
end

--- Core physics engine and renderer.
--- @param opts table|nil Optional overrides for physics parameters.
function M.explode(opts)
	local cfg = vim.tbl_extend("force", M.defaults, opts or {})
	local h_speed = cfg.horizontal_speed
	local v_speed = cfg.vertical_speed
	local grav = cfg.gravity
	local bnc = cfg.bounce
	local fric = cfg.friction

	cleanup()

	-- 1. Gather Window context
	-- :help nvim_win_get_width
	local width = api.nvim_win_get_width(0)
	local height = api.nvim_win_get_height(0)
	local start_line = vim.fn.line("w0") - 1
	local end_line = vim.fn.line("w$")
	local lines = api.nvim_buf_get_lines(0, start_line, end_line, false)

	-- 2. Create an ephemeral buffer for the animation
	-- :help nvim_create_buf
	float_buf = api.nvim_create_buf(false, true)
	local win_opts = {
		relative = "win",
		width = width,
		height = height,
		col = 0,
		row = 0,
		style = "minimal",
		zindex = 150,
	}
	float_win = api.nvim_open_win(float_buf, true, win_opts)
	api.nvim_set_option_value("winhl", "Normal:Normal", { win = float_win })

	-- Close on 'q' or 'Esc'
	api.nvim_buf_set_keymap(
		float_buf,
		"n",
		"q",
		'<Cmd>lua require("explode").stop()<CR>',
		{ noremap = true, silent = true }
	)
	api.nvim_buf_set_keymap(
		float_buf,
		"n",
		"<Esc>",
		'<Cmd>lua require("explode").stop()<CR>',
		{ noremap = true, silent = true }
	)

	-- 3. Initialize Particle Data
	local particles = {}
	for row, line in ipairs(lines) do
		-- Split string by characters (UTF-8 safe)
		-- :help split()
		local chars = vim.fn.split(line, "\\zs")
		local col = 1
		for _, char in ipairs(chars) do
			if char:match("%S") then -- Only animate non-whitespace
				table.insert(particles, {
					x = col,
					y = row,
					vx = (math.random() * h_speed) + 1.0,
					vy = (math.random() * -v_speed) - 1.0, -- Negative Y is "Up" in terminal coords
					char = char,
				})
			end
			col = col + vim.fn.strdisplaywidth(char)
		end
	end

	-- 4. Start the Animation Timer
	timer = uv.new_timer()
	if timer then
		-- 0ms delay, ~33ms interval (~30 FPS)
		timer:start(
			0,
			33,
			vim.schedule_wrap(function()
				if not api.nvim_buf_is_valid(float_buf) then
					cleanup()
					return
				end

				local is_moving = false

				-- 4a. Physics Update Step
				for _, p in ipairs(particles) do
					if p.y <= height then
						is_moving = true
						p.vy = p.vy + grav -- Apply gravity
						p.x = p.x + p.vx -- Horizontal move
						p.y = p.y + p.vy -- Vertical move

						-- Floor Collision
						if p.y >= height then
							p.y = height
							p.vy = -p.vy * bnc -- Reverse vertical velocity (bounce)
							p.vx = p.vx * fric -- Slow down horizontally

							-- Sleep threshold to stop jittering
							if math.abs(p.vy) < 0.5 then
								p.vy = 0
							end
							if math.abs(p.vx) < 0.1 then
								p.vx = 0
							end
						end

						-- Wall Collision (Right)
						if p.x >= width then
							p.x = width
							p.vx = -p.vx * bnc
						end
					end
				end

				-- 4b. Rendering Step
				-- Create empty 2D grid for the screen
				local grid = {}
				for i = 1, height do
					grid[i] = {}
					for j = 1, width do
						grid[i][j] = " "
					end
				end

				-- Plot particles onto grid
				for _, p in ipairs(particles) do
					local px = math.floor(p.x + 0.5)
					local py = math.floor(p.y + 0.5)
					if py >= 1 and py <= height and px >= 1 and px <= width then
						grid[py][px] = p.char
					end
				end

				-- Convert grid to lines for the buffer
				local render_lines = {}
				for i = 1, height do
					table.insert(render_lines, table.concat(grid[i]))
				end

				-- Update floating buffer
				if api.nvim_buf_is_valid(float_buf) then
					api.nvim_buf_set_lines(float_buf, 0, -1, false, render_lines)
				end

				-- 5. Auto-stop if no particles are moving
				if not is_moving and timer then
					timer:stop()
					timer:close()
					timer = nil
				end
			end)
		)
	end
end

--- Stop external interface
function M.stop()
	cleanup()
end

return M
