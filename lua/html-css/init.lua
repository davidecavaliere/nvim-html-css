local Source = {}
local config = require("cmp.config")
local a = require("plenary.async")
local Job = require("plenary.job")
local l = require("html-css.local")
local e = require("html-css.embedded")

local ts = vim.treesitter

local log = require("html-css.log");
log.outfile = '/tmp/nvim-html-css.log';

local scan = require("plenary.scandir")
local rootDir = scan.scan_dir(".", {
	hidden = true,
	add_dirs = true,
	depth = 1,
	respect_gitignore = true,
	search_pattern = function(entry)
		local subEntry = entry:sub(3) -- remove ./
		-- %f[%a]git%f[^%a] -- old regex for matching .git
		return subEntry:match(".git$") or subEntry:match("package.json") -- if project contains .git folder or package.json its gonna work
	end,
})

function Source:setup()
  log.debug('Registering html-css cmp source');
	require("cmp").register_source(self.source_name, Source)
end

function Source:new()
  log.debug('Newing html-css source');
	self.source_name = "html-css"
	self.items = {}

	-- reading user config
	self.user_config = config.get_source_config(self.source_name) or {}
	self.option = self.user_config.option or {}
	self.file_extensions = self.option.file_extensions or {}
	self.style_sheets = self.option.style_sheets or {}
	self.enable_on = self.option.enable_on or {}

	-- Get the current working directory
	local current_directory = vim.fn.getcwd()

  log.debug(current_directory);
	-- Check if the current directory contains a .git folder
	local git_folder_exists = vim.fn.isdirectory(current_directory .. "/.git")

	-- if git_folder_exists == 1 then
	if vim.tbl_count(rootDir) ~= 0 then

		-- handle embedded styles
		a.run(function()
			e.read_html_files(function(classes)
				for _, class in ipairs(classes) do
					table.insert(self.items, class)
				end
			end)
		end)

		-- read all local files on start
		a.run(function()
			l.read_local_files(self.file_extensions, function(classes)
				for _, class in ipairs(classes) do
					table.insert(self.items, class)
				end
			end)
		end)
	end

	return self
end

function Source:complete(_, callback)
  log.debug('get classnames for completion');
	-- Get the current working directory
	local current_directory = vim.fn.getcwd()

	-- Check if the current directory contains a .git folder
	local git_folder_exists = vim.fn.isdirectory(current_directory .. "/.git")

	-- if git_folder_exists == 1 then
	if vim.tbl_count(rootDir) ~= 0 then
		self.items = {}

		-- handle embedded styles
		a.run(function()
			e.read_html_files(function(classes)
				for _, class in ipairs(classes) do
					table.insert(self.items, class)
				end
			end)
		end)

		-- read all local files on start
		a.run(function()
			l.read_local_files(self.file_extensions, function(classes)
				for _, class in ipairs(classes) do
					table.insert(self.items, class)
				end
			end)
		end)

    callback({ items = self.items, isComplete = false })
	end
end

function Source:is_available()
	if not next(self.user_config) then
		return false
	end

  log.debug('html-css: filetype is:', vim.bo.filetype);

	if not vim.tbl_contains(self.option.enable_on, vim.bo.filetype) then
		return false
	end

	local inside_quotes = ts.get_node({ bfnr = 0 })

  log.debug('inside quote', inside_quotes);

	if inside_quotes == nil then
		return false
	end

	local type = inside_quotes:type()

	local prev_sibling = inside_quotes:prev_named_sibling()
  log.debug('prev_sibling', prev_sibling);

	if prev_sibling == nil then
		return false
	end

	local prev_sibling_name = ts.get_node_text(prev_sibling, 0)


	if
		prev_sibling_name == "class" or prev_sibling_name == "id" and type == "quoted_attribute_value"
	then
		return true
	end

	return false
end

return Source:new()
