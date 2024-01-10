-- embedded styles are all styles between <style></style> tags
-- inside .html files

local M = {
	links = {},
}
local j = require("plenary.job")
local u = require("html-css.utils.init")
local a = require("plenary.async")
local cmp = require("cmp")
local ts = vim.treesitter

local log = require("html-css.log");
log.outfile = '/tmp/nvim-html-css.log';

---@type item[]
local classes = {}
---@type string[]
local unique_class = {}

-- treesitter query for extracting css clasess
local qs = [[
	(class_selector
		(class_name)@class_name)
]]

-- TODO change name of the function to something better
M.read_html_files = a.wrap(function(cb)
	local files = j:new({
		command = "fd",
		args = { "-a", "-e", "html", "--exclude", "node_modules" },
	}):sync()

  log.debug('found', #files, 'files');

	if #files == 0 then
		return
	else
		for _, file in ipairs(files) do
      log.debug('parsing file', file);
			---@type string
			local file_name = u.get_file_name(file, "[^/]+$")

			-- reading html files
			local _, fd = a.uv.fs_open(file, "r", 438)
			local _, stat = a.uv.fs_fstat(fd)
			local _, data = a.uv.fs_read(fd, stat.size, 0)
			a.uv.fs_close(fd)

			-- clean tables to avoid duplications
			classes = {}
			unique_class = {}

			-- extrac classes from embedded styles using tree-sitter
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

			local unique_classes_list = u.unique_list(unique_class)
      log.debug('collected', #unique_classes_list, 'classes');
			for _, class in ipairs(unique_classes_list) do
				table.insert(classes, {
					label = class,
					kind = cmp.lsp.CompletionItemKind.Enum,
					menu = file_name,
				})
			end


			cb(classes)
		end
	end
end, 1)

return M
