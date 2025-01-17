local M = {}
local cmp = require("cmp")
local u = require("html-css.utils.init")
local a = require("plenary.async")
local j = require("plenary.job")
local ts = vim.treesitter
local classes = {}
local unique_class = {}

local log = require("html-css.log");
log.outfile = '/tmp/nvim-html-css.log';

-- treesitter query for extracting css clasess
local qs = [[
	(class_selector
		(class_name)@class_name)
]]

---@async
M.read_local_files = a.wrap(function(file_extensions, cb)
	local files = {}

	-- WARNING need to check for performance in larger projects
	for _, extension in ipairs(file_extensions) do
		j:new({
			command = "fd",
			args = { "-a", "-e", "" .. extension .. "", "--exclude", "node_modules" },
			on_stdout = function(_, data)
				table.insert(files, data)
			end,
		}):sync()
	end

  log.debug('found', #files, 'files');

	if #files == 0 then
		return
	else
		for _, file in ipairs(files) do
      log.debug('parsing file', file);
			---@type string
			local file_name = u.get_file_name(file, "[^/]+$")

			local fd = io.open(file, "r")
			local data = fd:read("*a")
			fd:close()

			-- reading html files
			-- local _, fd = a.uv.fs_open(file, "r", 438)
			-- local _, stat = a.uv.fs_fstat(fd)
			-- local _, data = a.uv.fs_read(fd, stat.size, 0)
			-- a.uv.fs_close(fd)

			classes = {} -- clean up prev classes
			unique_class = {}

			local parser = ts.get_string_parser(data, "css")
			local tree = parser:parse()[1]
			local root = tree:root()
			local query = ts.query.parse("css", qs)

			for _, matches, _ in query:iter_matches(root, data, 0, 0, {}) do
				for _, node in pairs(matches) do
          local class_name = ts.get_node_text(node, data)
          table.insert(unique_class, class_name)
				end
			end

			local unique_list = u.unique_list(unique_class)
      log.debug('collected', #unique_list, 'classes');
			for _, class in ipairs(unique_list) do
				table.insert(classes, {
					label = class,
					kind = cmp.lsp.CompletionItemKind.Enum,
					menu = file_name,
				})
			end

			cb(classes)
		end
	end
end, 2)

return M
