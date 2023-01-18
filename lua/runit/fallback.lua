local core = require("runit.core")

local M = {}

local function check_deps()
  local status_ok, _ = pcall(require, "project_nvim.project")
  if not status_ok then
    print("[Runit] ahmedkhalf/project.nvim is required.")
    return false
  end
  status_ok, _ = pcall(require, "plenary")
  if not status_ok then
    print("[Runit] nvim-lua/plenary.nvim is required.")
    return false
  end
  if not vim.fn.exists(":Dispatch") then
    print("[Runit] tpope/vim-dispatch is required.")
    return false
  end
  return true
end

local function get_project_fallback_builddir(command)
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
      return "cd " .. build_path:absolute() .. " && " .. command
    end
  end
end

local function get_project_fallback_makefile(command)
  if not check_deps() then
    return
  end
  local project = require("project_nvim.project")
  local path = require("plenary.path")
  local root = project.get_project_root()
  if root ~= nil then
    -- check make file
    local mkf_path = path:new(root, "Makefile")
    if mkf_path:exists() and mkf_path:is_file() then
      return "cd " .. root:absolute() .. " && " .. command
    end
  end
end

local function get_project_fallback_cmake_config()
  if not check_deps() then
    return
  end
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
            return "cd " .. build_path:absolute() .. " && cmake ."
          else
            return "cd " .. build_path:absolute() .. " && cmake ."
          end
        else
          return false
        end
      else
        build_path.mkdir()
        if build_path:exists() then
          return "cd " .. build_path:absolute() .. " && cmake -DCMAKE_INSTALL_PREFIX=./install .."
        end
      end
    end
  end
  return false
end

function M.get_project_fallback_config()
  local conf = {}
  local cmd = nil
  -- config fallback
  cmd = get_project_fallback_cmake_config()
  if cmd then
    conf["config"] = cmd
  end
  -- build fallback
  cmd = get_project_fallback_builddir("make -j8")
  if cmd then
    conf["build"] = cmd
  else
    cmd = get_project_fallback_makefile("make -j8")
    if cmd then
      conf["build"] = cmd
    end
  end
  -- test fallback
  cmd = get_project_fallback_builddir("make test")
  if cmd then
    conf["test"] = cmd
  else
    cmd = get_project_fallback_makefile("make test")
    if cmd then
      conf["test"] = cmd
    end
  end
  -- install fallback
  cmd = get_project_fallback_builddir("make install")
  if cmd then
    conf["install"] = cmd
  else
    cmd = get_project_fallback_makefile("make install")
    if cmd then
      conf["install"] = cmd
    end
  end
  -- clean fallback
  cmd = get_project_fallback_builddir("make clean")
  if cmd then
    conf["clean"] = cmd
  else
    cmd = get_project_fallback_makefile("make clean")
    if cmd then
      conf["clean"] = cmd
    end
  end

  conf["all"] = { "#config", "#build", "#test", "#install" }
  return conf
end

function M.run_project_fallback(steps)
  local root = core.get_project_root()
  if root == nil then
    print("[Runit] No project found.")
    return false
  end
  local name = root:match("^.+/(.+)$")
  local conf = M.get_project_fallback_config()
  return core.run_by_config(conf, steps, {
    proj_path = root,
    proj_name = name,
  })
end

return M
