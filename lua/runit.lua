local doc = [[
Automatically config, build, test, and install your project
  Are we in project?
    Y: Is there a project config?
      Y: Use project config
      N: Is there a "build" directory in project root?
        Y: cd build; make
          N: Is there a Makefile in project root?
            Y: make
            N: do nothing
    N: Try to build file in current buffer by file type config
]]

local cmake_command = "cmake"
local project_config = {}
local ft_config = {
	markdown = "MarkdownPreview",
	html = function(file)
		vim.cmd("silent !open " .. file)
	end,
	cpp = function(file)
		vim.cmd(
			"Dispatch c++ -g -std=gnu++2a -I/usr/local/include/ "
				.. "-L/usr/local/lib -o a.out "
				.. file
				.. " && ./a.out && rm a.out"
		)
	end,
	c = function(file)
		vim.cmd(
			"Dispatch cc -g -std=gnu99 -I/usr/local/include/ "
				.. "-L/usr/local/lib -o a.out "
				.. file
				.. " && ./a.out && rm a.out"
		)
	end,
	python = function(file)
		vim.cmd("Dispatch python3 " .. file)
	end,
  cmake = function(file)
    vim.cmd("Dispatch " .. cmake_command .. " -P " .. file)
  end,
  php = function(file)
    vim.cmd("Dispatch php " .. file)
  end,
  lua = function(file)
    vim.cmd("Dispatch lua " .. file)
  end,
}

local function determine_os()
	if vim.fn.has("macunix") == 1 then
		return "macOS"
	elseif vim.fn.has("win32") == 1 then
		-- WSL share same config with Windows
		cmake_command = "cmake.exe"
		return "Windows"
	elseif vim.fn.has("unix") == 1 and vim.fn.empty("$WSL_DISTRO_NAME") ~= 1 then
		return "WSL"
	else
		return "Linux"
	end
end

local function check_deps()
	local status_ok, _ = pcall(require, "project_nvim.project")
	if not status_ok then
		print("ahmedkhalf/project.nvim is required.")
		return false
	end
	status_ok, _ = pcall(require, "plenary")
	if not status_ok then
		print("nvim-lua/plenary.nvim is required.")
		return false
	end
	if not vim.fn.exists(":Dispatch") then
		print("tpope/vim-dispatch is required.")
		return false
	end
	return true
end

local function run_by_ft_config()
	local ft = vim.bo.filetype
	if ft_config[ft] == nil then
		return -2
	end
	local config = ft_config[ft]
	if config ~= nil then
		if type(config) == "string" then
			vim.cmd(config)
		elseif type(config) == "function" then
			config(vim.fn.expand("%:p"))
		else
			return -1
		end
	end
	return 0
end

local function run_by_project_config(step, root)
	if root == nil then
		local ok, project = pcall(require, "project_nvim.project")
		if not ok then
			print("ahmedkhalf/project.nvim is required.")
			return -1
		end
		root = project.get_project_root()
	end
	if root == nil then
		return -1
	end
	local name = root:match("^.+/(.+)$")
	if project_config[name] == nil then
		return -2
	end
	local config = project_config[name][step]
	if config == nil then
		return -1
	end
	if type(config) == "string" then
		vim.cmd(config)
	elseif type(config) == "function" then
		config(name, root, step)
	else
		return -1
	end
	return 0
end

-- common fallback {{{

local function run_project_fallback_builddir(command)
	if not check_deps() then
		return
	end
	local project = require("project_nvim.project")
	local path = require("plenary.path")
	local root = project.get_project_root()
	if root ~= nil then
		-- check build dir
		local build_path = path:new(root, "build")
		if build_path:exists() and build_path:is_dir() then
			local cmd = "cd " .. build_path:absolute() .. " && " .. command
			vim.cmd({ cmd = "Dispatch", args = { cmd } })
			return true
		end
	end
	return false
end

local function run_project_fallback_makefile(command)
	local project = require("project_nvim.project")
	local path = require("plenary.path")
	local root = project.get_project_root()
	if root ~= nil then
		-- check make file
		local mkf_path = path:new(root, "Makefile")
		if mkf_path:exists() and mkf_path:is_file() then
			local cmd = "cd " .. root:absolute() .. " && " .. command
			vim.cmd({ cmd = "Dispatch", args = { cmd } })
			return true
		end
	end
	return false
end

-- }}}

-- config fallback {{{

local function run_config_project_fallback_cmake()
	local project = require("project_nvim.project")
	local path = require("plenary.path")
	local root = project.get_project_root()
	if root ~= nil then
		-- check CMakeList.txt
		local cmakelist_path = path:new(root, "CMakeList.txt")
		if cmakelist_path:exists() and cmakelist_path:is_file() then
			-- check build dir
			local build_path = path:new(root, "build")
			if build_path:exists() then
				if build_path:is_dir() then
					-- check CMakeCache.txt
					if path:new(root, "build", "CMakeCache.txt").exists() then
						local config_cmd = "cd " .. build_path:absolute() .. " && " .. cmake_command .. " ."
						vim.cmd({ cmd = "Dispatch", args = { config_cmd } })
						return true
					else
						local config_cmd = "cd " .. build_path:absolute() .. " && " .. cmake_command .. " .."
						vim.cmd({ cmd = "Dispatch", args = { config_cmd } })
						return true
					end
				else
					return false
				end
			else
				build_path.mkdir()
				if build_path:exists() then
					local config_cmd = "cd " .. build_path:absolute() .. " && " .. cmake_command .. " .."
					vim.cmd({ cmd = "Dispatch", args = { config_cmd } })
					return true
				end
			end
		end
	end
	return false
end

-- }}}

local function run_file()
	if run_by_ft_config() == 0 then
		return true
	end
	return false
end

local function run_project(step, root)
	local r = run_by_project_config(step, root)
	if r == 0 then
		return true
	end
	if r == -2 then
		-- fallback
		if step == "config" then
			return run_config_project_fallback_cmake()
		elseif step == "build" then
			if run_project_fallback_builddir("make") then
				return true
			end
			if run_project_fallback_makefile("make") then
				return true
			end
			return false
		elseif step == "test" then
			if run_project_fallback_builddir("make test") then
				return true
			end
			if run_project_fallback_makefile("make test") then
				return true
			end
			return false
		elseif step == "install" then
			if run_project_fallback_builddir("make install") then
				return true
			end
			if run_project_fallback_makefile("make install") then
				return true
			end
			return false
		end
	end
end

-- can be called multiple times
local function setup(opts)
	if opts["project"] ~= nil then
		for k, v in pairs(opts["project"]) do
			project_config[k] = v
		end
	end
	if opts["filetype"] ~= nil then
		for k, v in pairs(opts["filetype"]) do
			ft_config[k] = v
		end
	end
	if opts["ft"] ~= nil then
		for k, v in pairs(opts["ft"]) do
			ft_config[k] = v
		end
	end
	determine_os()
end

M = {
	setup = setup,

	run_project = run_project,
	run_file = run_file,
}

return M
