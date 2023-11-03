---@alias Error
---| { filename: string, filename_range: IntByInt, row: integer?, row_range: IntByInt?, col: integer?, col_range: IntByInt? }

local M = {}

---TODO: document
---(REGEXP FILE [LINE COLUMN TYPE HYPERLINK HIGHLIGHT...])
---@type table<string, { [1]: string, [2]: integer, [3]: integer|IntByInt|nil, [4]: integer|IntByInt|nil, [5]: nil|0|1|2 }>
M.error_regexp_table = {
	-- TODO: use the actual alist from Emacs
	gnu = {
		"^\\%([[:alpha:]][-[:alnum:].]\\+: \\?\\|[ 	]\\%(in \\| from\\)\\)\\?\\(\\%([0-9]*[^0-9\\n]\\)\\%([^\\n :]\\| [^-/\\n]\\|:[^ \\n]\\)\\{-}\\)\\%(: \\?\\)\\([0-9]\\+\\)\\%(-\\([0-9]\\+\\)\\%(\\.\\([0-9]\\+\\)\\)\\?\\|[.:]\\([0-9]\\+\\)\\%(-\\%(\\([0-9]\\+\\)\\.\\)\\([0-9]\\+\\)\\)\\?\\)\\?:\\%( *\\(\\%(FutureWarning\\|RuntimeWarning\\|W\\%(arning\\)\\|warning\\)\\)\\| *\\([Ii]nfo\\%(\\>\\|formationa\\?l\\?\\)\\|I:\\|\\[ skipping .\\+ ]\\|instantiated from\\|required from\\|[Nn]ote\\)\\| *\\%([Ee]rror\\)\\|\\%([0-9]\\?\\)\\%([^0-9\\n]\\|$\\)\\|[0-9][0-9][0-9]\\)",
		1,
		{ 2, 4 },
		{ 3, 5 },
		-- TODO: implement this
		nil,
	},
}

---TODO: this probably needs to return a string
---TODO: this should be more flexible
---Given a `:h matchlist()` result and a capture-group matcher, return the relevant capture group.
---
---@param result (IntByInt|nil)[]
---@param group integer|IntByInt|nil
---@return IntByInt|nil
local function parse_matcher_group(result, group)
	if not group then
		return nil
	elseif type(group) == "number" then
		return result[group] ~= nil and result[group] or nil
	elseif type(group) == "table" then
		local first = group[1]
		local second = group[2]

		if result[first] and result[first] ~= "" then
			return result[first]
		elseif result[second] and result[second] ~= "" then
			return result[second]
		else
			return nil
		end
	end
end

---@param input string
---@param pattern string
---@return ({ [1]: integer, [2]: integer }|nil)[]
local function matchlistpos(input, pattern)
	local list = vim.fn.matchlist(input, pattern) --[[@as string[] ]]

	---@type (IntByInt|nil)[]
	local result = {}

	local latest_index = vim.fn.match(input, pattern)
	for i, capture in ipairs(list) do
		if i ~= 1 then
			if capture == "" then
				result[i - 1] = nil
			else
				local start, end_ = string.find(input, capture, latest_index, true)
				assert(start and end_)
				latest_index = end_ + 1
				result[i - 1] = { start, end_ }
			end
		end
	end

	return result
end

---Parses error syntax from a given line.
---@param line string the line to parse
---@return Error|nil
function M.parse(line)
	local matcher = M.error_regexp_table["gnu"]

	local regex = matcher[1]
	local result = matchlistpos(line, regex)
	if not result then
		return nil
	end

	local filename_range = result[matcher[2]]
	if not filename_range then
		return nil
	end

	local row_range = parse_matcher_group(result, matcher[3])
	local col_range = parse_matcher_group(result, matcher[4])

	---@type Error
	return {
		filename = string.sub(line, filename_range[1], filename_range[2]),
		filename_range = filename_range,
		row = row_range and tonumber(string.sub(line, row_range[1], row_range[2])) or nil,
		row_range = row_range,
		col = col_range and tonumber(string.sub(line, col_range[1], col_range[2])) or nil,
		col_range = col_range,
	}
end

return M
