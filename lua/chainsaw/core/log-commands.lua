local insertStatements = require("chainsaw.core.insert-statements").insert

---@return boolean success
local function moveCursorToQuotes()
	local lnum = vim.api.nvim_win_get_cursor(0)[1]
	local curLine = vim.api.nvim_get_current_line()
	local _, _end = curLine:find([[".*"]])
	if not _end then
		_, _end = curLine:find([['.*']])
	end
	if not _end then return false end
	vim.api.nvim_win_set_cursor(0, { lnum, _end - 1 })
	return true
end

--------------------------------------------------------------------------------

-- not using metatable-__index, as the logtype-names are needed for suggestions
-- for the `:Chainsaw` command
local M = {
	variableLog = insertStatements,
	objectLog = insertStatements,
	typeLog = insertStatements,
	stacktraceLog = insertStatements,
	debugLog = insertStatements,
	clearLog = insertStatements,
	sound = insertStatements,
}

function M.assertLog()
	local success = insertStatements()
	if not success then return end
	moveCursorToQuotes() -- easier to edit assertion msg
end

function M.emojiLog()
	local conf = require("chainsaw.config.config").config.logTypes.emojiLog

	-- randomize emoji order
	local emojis = vim.deepcopy(conf.emojis)
	for i = #emojis, 2, -1 do
		local j = math.random(i)
		emojis[i], emojis[j] = emojis[j], emojis[i]
	end

	-- select the first emoji with the least number of occurrences, ensuring that
	-- we will get as many different emojis as possible
	local emojiToUse = { emoji = "", count = math.huge }
	local bufferText = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
	for _, emoji in ipairs(emojis) do
		local _, count = bufferText:gsub(emoji, "")
		if count < emojiToUse.count then emojiToUse = { emoji = emoji, count = count } end
	end
	insertStatements(nil, emojiToUse.emoji)
end

function M.messageLog()
	local success = insertStatements()
	if not success then return end

	-- goto insert mode at correct location to enter message
	success = moveCursorToQuotes()
	if success then vim.defer_fn(vim.cmd.startinsert, 1) end
end

function M.timeLog()
	if vim.b.timeLogStart == nil then vim.b.timeLogStart = true end
	if vim.b.timeLogIndex == nil then vim.b.timeLogIndex = 1 end

	local startOrStop = vim.b.timeLogStart and "timeLogStart" or "timeLogStop"
	local success = insertStatements(startOrStop, vim.b.timeLogIndex)
	if not success then return end

	if vim.b.timeLogStart then
		vim.b.timeLogStart = false
	else
		vim.b.timeLogIndex = vim.b.timeLogIndex + 1
		vim.b.timeLogStart = true
	end
end

--------------------------------------------------------------------------------

function M.removeLogs()
	local marker = require("chainsaw.config.config").config.marker
	local numOfLinesBefore = vim.api.nvim_buf_line_count(0)
	local mode = vim.fn.mode()
	local bufLines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

	-- normal mode: whole buffer
	-- visual mode: selected lines
	local startLnum, endLnum
	if mode == "n" then
		startLnum = 1
		endLnum = #bufLines
	elseif mode:find("[Vv]") then
		startLnum = vim.fn.getpos("v")[2]
		endLnum = vim.fn.getpos(".")[2]
		if startLnum > endLnum then
			startLnum, endLnum = endLnum, startLnum
		end
		vim.cmd.normal { mode, bang = true } -- leave visual mode
	end

	-- Remove lines
	-- (Deleting lines instead of overriding whole buffer to preserve marks, folds, etc.)
	for lnum = endLnum, startLnum, -1 do
		if bufLines[lnum]:find(marker, nil, true) then
			vim.api.nvim_buf_set_lines(0, lnum - 1, lnum, false, {})
		end
	end

	-- notify on number of lines removed
	local linesRemoved = numOfLinesBefore - vim.api.nvim_buf_line_count(0)
	local pluralS = linesRemoved == 1 and "" or "s"
	local msg = ("Removed %d line%s."):format(linesRemoved, pluralS)
	require("chainsaw.utils").info(msg)

	-- reset
	vim.b.timelogStart = nil
	vim.b.timeLogIndex = nil
end

function M.removeLogsVisual()
	local marker = require("chainsaw.config.config").config.marker
	local numOfLinesBefore = vim.api.nvim_buf_line_count(0)

	-- Get the start and end of current visual selection
	local selectedStart = vim.fn.getpos("v")
	local selectedEnd = vim.fn.getpos(".")
	if selectedStart[2] > selectedEnd[2] then
		selectedStart, selectedEnd = selectedEnd, selectedStart
	end

	-- Remove lines only for visual selection
	local bufLines = vim.api.nvim_buf_get_lines(0, selectedStart[2] - 1, selectedEnd[2], false)
	for i = #bufLines, 1, -1 do
		if bufLines[i]:find(marker, nil, true) then
			local actualLine = selectedStart[2] + i - 1
			vim.api.nvim_buf_set_lines(0, actualLine - 1, actualLine, false, {})
		end
	end

	-- notify on number of lines removed
	local linesRemoved = numOfLinesBefore - vim.api.nvim_buf_line_count(0)
	local msg = ("Removed %d lines."):format(linesRemoved)
	if linesRemoved == 1 then msg = msg:sub(1, -3) .. "." end -- 1 = singular
	require("chainsaw.utils").info(msg)

	-- Go back to normal mode
	vim.api.nvim_feedkeys("", "v", true)

	-- reset
	vim.b.timelogStart = nil
end

--------------------------------------------------------------------------------
return M
