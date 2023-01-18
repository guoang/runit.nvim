local config = require("runit.config")
local core = require("runit.core")
local fallback = require("runit.fallback")
local M = {}

local function run_by_ft_config(steps)
  local ft = vim.bo.filetype
  if config.ft_config[ft] == nil then
    print("[Runit] No config for filetype " .. ft)
    return -2
  end
  core.run_by_config(config.ft_config[ft], steps, {})
  return 0
end

local function run_by_project_config(steps)
  local root = core.get_project_root()
  if root == nil then
    print("[Runit] No project found.")
    return -1
  end
  local name = root:match("^.+/(.+)$")
  if config.project_config[name] == nil then
    print("[Runit] No project config found for " .. name)
    return -2
  end
  core.run_by_config(config.project_config[name], steps, {
    proj_path = root,
    proj_name = name,
  })
  return 0
end

function M.run_file(steps)
  if run_by_ft_config(steps) == 0 then
    return true
  end
  return false
end

function M.run_project(steps, guess)
  local r = run_by_project_config(steps)
  if r == 0 then
    return true
  end
  if r == -1 then  -- no project found
    return false
  end
  if r == -2 then  -- no project config found
    if guess then
      if fallback.run_project_fallback(steps) then
        return true
      end
    end
  end
  return false
end

function M.run(steps)
  if not M.run_project(steps, true) then
    -- fallback to ft
    return M.run_file(steps)
  end
end

function M.focus_project(steps)
  local root = core.get_project_root()
  if root == nil then
    print("[Runit] No project found.")
    return false
  end
  local name = root:match("^.+/(.+)$")
  if config.project_config[name] == nil then
    config.project_config[name] = {}
  end
  config.project_config[name]["__focus__"] = steps
  return true
end

function M.focus_file(steps)
  local ft = vim.bo.filetype
  if config.ft_config[ft] == nil then
    config.ft_config[ft] = {}
  end
  config.ft_config[ft]["__focus__"] = steps
end

function M.focus(steps)
  if not M.focus_project(steps) then
    M.focus_file(steps)
  end
end

-- can be called multiple times
function M.setup(opts)
  if opts["project"] ~= nil then
    for k, v in pairs(opts["project"]) do
      config.project_config[k] = v
    end
  end
  if opts["filetype"] ~= nil then
    for k, v in pairs(opts["filetype"]) do
      config.ft_config[k] = v
    end
  end
  if opts["ft"] ~= nil then
    for k, v in pairs(opts["ft"]) do
      config.ft_config[k] = v
    end
  end
end

return M
