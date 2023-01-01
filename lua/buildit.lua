-- Automatically config, build, test, and install your project
-- 1. Is in project?
--  1.1 Yes: has project config?
--    1.1.1 Yes: Use project config
--    1.1.2 No: Has "build" directory in project root?
--      1.1.2.1 Yes: cd build; make
--      1.1.2.2 No: do nothing
--  1.2 No: Try to build file in current buffer by file type config

local buildit_project_config = {}
local buildit_ft_config = {}
local cmake_command = "cmake"

local function buildit_determine_os()
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

local function buildit_check_deps()
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

local function buildit_run_dispatch_by_project_config(step)
  if not buildit_check_deps() then
    return false
  end
  local project = require("project_nvim.project")
  local root = project.get_project_root()
  if root ~= nil then
    local name = root:match("^.+/(.+)$")
    if buildit_project_config[name] ~= nil then
      local config = buildit_project_config[name][step]
      if config ~= nil then
        local dir = config['dir']
        local shell_cmd = config['shell_cmd_cmd']
        local vim_cmd = config['vim_cmd']
        if shell_cmd ~= nil then
          if dir ~= nil then
            shell_cmd = "cd " .. dir .. " && " .. shell_cmd
          else
            shell_cmd = "cd " .. root.absolute() .. " && " .. shell_cmd
          end
          vim.cmd({cmd = "Dispatch", args = { shell_cmd }})
          return true
        elseif vim_cmd ~= nil then
          vim.command(vim_cmd)
          return true
        end
      end
    end
  end
  return false
end

local function buildit_run_dispatch_by_ft_config(step)
  if not buildit_check_deps() then
    return false
  end
  local ft = vim.bo.filetype
  if buildit_ft_config[ft] ~= nil then
    local config = buildit_ft_config[ft][step]
    if config ~= nil then
      local dir = config['dir']
      local shell_cmd = config['shell_cmd_cmd']
      local vim_cmd = config['vim_cmd']
      if shell_cmd ~= nil then
        if dir ~= nil then
          shell_cmd = "cd " .. dir .. " && " .. shell_cmd
        else
          local path = require("plenary.path")
          local filepath = path:new(vim.fn.expand('%'))
          local filedir = filepath:parent()
          shell_cmd = "cd " .. filedir.absolute() .. " && " .. shell_cmd
        end
        vim.cmd({cmd = "Dispatch", args = { shell_cmd }})
        return true
      elseif vim_cmd ~= nil then
        vim.command(vim_cmd)
      end
    end
  end
  return false
end

-- common fallback {{{

local function buildit_project_fallback_builddir(command)
  local project = require("project_nvim.project")
  local path = require("plenary.path")
  local root = project.get_project_root()
  if root ~= nil then
    -- check build dir
    local build_path = path:new(root, "build")
    if build_path:exists() and build_path:is_dir() then
      local cmd = "cd " .. build_path:absolute() .. " && " .. command
      vim.cmd({ cmd = "Dispatch", args = { cmd }})
      return true
    end
  end
  return false
end

local function buildit_project_fallback_makefile(command)
  local project = require("project_nvim.project")
  local path = require("plenary.path")
  local root = project.get_project_root()
  if root ~= nil then
    -- check make file
    local mkf_path = path:new(root, "Makefile")
    if mkf_path:exists() and mkf_path:is_file() then
      local cmd = "cd " .. root:absolute() .. " && " .. command
      vim.cmd({ cmd = "Dispatch", args = { cmd }})
      return true
    end
  end
  return false
end

-- }}}

-- config {{{

-- fallback {{{

local function buildit_config_project_fallback_cmake()
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
            vim.cmd({ cmd = "Dispatch", args = { config_cmd }})
            return true
          else
            local config_cmd = "cd " .. build_path:absolute() .. " && " .. cmake_command .. " .."
            vim.cmd({ cmd = "Dispatch", args = { config_cmd }})
            return true
          end
        else
          return false
        end
      else
        build_path.mkdir()
        if build_path:exists() then
          local config_cmd = "cd " .. build_path:absolute() .. " && " .. cmake_command .. " .."
          vim.cmd({ cmd = "Dispatch", args = { config_cmd }})
          return true
        end
      end
    end
  end
  return false
end

-- }}}

local function buildit_config_project()
  if not buildit_check_deps() then
    return false
  end
  if buildit_run_dispatch_by_project_config("config") then
    return true
  end
  -- fallback --
  if buildit_config_project_fallback_cmake() then
    return true
  end
  -- TODO: others
  return false
end

local function buildit_config_current_file()
  buildit_run_dispatch_by_ft_config("config")
end

-- }}}

-- build {{{

-- fallback {{{

-- }}}

local function buildit_build_project()
  if not buildit_check_deps() then
    return false
  end
  if buildit_run_dispatch_by_project_config("build") then
    return true
  end
  -- fallback --
  if buildit_project_fallback_builddir("make") then
    return true
  end
  if buildit_project_fallback_makefile("make") then
    return true
  end
  return false
end

local function buildit_build_current_file()
  buildit_run_dispatch_by_ft_config("build")
end

-- }}}

-- test {{{

-- fallback {{{

-- }}}

local function buildit_test_project()
  if not buildit_check_deps() then
    return false
  end
  if buildit_run_dispatch_by_project_config("test") then
    return true
  end
  -- fallback --
  if buildit_project_fallback_builddir("make test") then
    return true
  end
  if buildit_project_fallback_makefile("make test") then
    return true
  end
  return false
end

local function buildit_test_current_file()
  buildit_run_dispatch_by_ft_config("test")
end

-- }}}

-- install {{{
-- fallback {{{

-- }}}

local function buildit_install_project()
  if not buildit_check_deps() then
    return false
  end
  if buildit_run_dispatch_by_project_config("install") then
    return true
  end
  -- fallback --
  if buildit_project_fallback_builddir("make install") then
    return true
  end
  if buildit_project_fallback_makefile("make install") then
    return true
  end
  return false
end

local function buildit_install_current_file()
  buildit_run_dispatch_by_ft_config("install")
end

-- }}}

-- auto {{{

local function buildit_config_auto()
  if not buildit_check_deps() then
    return false
  end
  local project = require("project_nvim.project")
  if project.get_project_root() ~= nil then
    buildit_config_project()
  else
    buildit_config_current_file()
  end
end

local function buildit_build_auto()
  if not buildit_check_deps() then
    return false
  end
  local project = require("project_nvim.project")
  if project.get_project_root() ~= nil then
    buildit_build_project()
  else
    buildit_build_current_file()
  end
end

local function buildit_test_auto()
  if not buildit_check_deps() then
    return false
  end
  local project = require("project_nvim.project")
  if project.get_project_root() ~= nil then
    buildit_test_project()
  else
    buildit_test_current_file()
  end
end

local function buildit_install_auto()
  if not buildit_check_deps() then
    return false
  end
  local project = require("project_nvim.project")
  if project.get_project_root() ~= nil then
    buildit_install_project()
  else
    buildit_install_current_file()
  end
end

-- }}}

local function setup(opts)
  if opts['project'] ~= nil then
    buildit_project_config = opts['project']
  end
  if opts['filetype'] ~= nil then
    buildit_ft_config = opts['filetype']
  end
  if opts['ft'] ~= nil then
    buildit_ft_config = opts['ft']
  end
  buildit_determine_os()
end

M = {
  setup = setup,
  buildit_config_project = buildit_config_project,
  buildit_build_project = buildit_build_project,
  buildit_test_project = buildit_test_project,
  buildit_install_project = buildit_install_project,

  buildit_config_current_file = buildit_config_current_file,
  buildit_build_current_file = buildit_build_current_file,
  buildit_test_current_file = buildit_test_current_file,
  buildit_install_current_file = buildit_install_current_file,

  buildit_config_auto = buildit_config_auto,
  buildit_build_auto = buildit_build_auto,
  buildit_test_auto = buildit_test_auto,
  buildit_install_auto = buildit_install_auto,
}

return M
