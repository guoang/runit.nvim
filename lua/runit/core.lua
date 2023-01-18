local M = {}

function M.get_project_root()
  local ok, project = pcall(require, "project_nvim.project")
  if not ok then
    print("[Runit] ahmedkhalf/project.nvim is required.")
    return nil
  end
  return project.get_project_root()
end

local function table_concat(t1, t2)
  for i = 1, #t2 do
    t1[#t1 + 1] = t2[i]
  end
  return t1
end

function M.format_command(config, cmd, step, args)
  local commands = {}
  local shell_commands = {}
  local vim_commands = {}
  local lua_functions = {}
  local file_path = vim.fn.expand("%:p")
  local file_name = vim.fn.expand("%:t")
  args.step = step:sub(2)
  args.file_path = args.file_path or file_path
  args.file_name = args.file_name or file_name
  args.proj_path = args.proj_path or ""
  args.proj_name = args.proj_name or ""
  if type(cmd) == "string" then
    cmd = cmd:gsub("${__step__}", args.step)
    cmd = cmd:gsub("${__file_path__}", args.file_path)
    cmd = cmd:gsub("${__file_name__}", args.file_name)
    cmd = cmd:gsub("${__proj_path__}", args.proj_path)
    cmd = cmd:gsub("${__proj_name__}", args.proj_name)
    if cmd:match("^!") then
      -- shell command
      table.insert(shell_commands, cmd:sub(2))
      table.insert(commands, cmd)
    elseif cmd:match("^:!") then
      -- shell command
      table.insert(shell_commands, cmd:sub(3))
      table.insert(commands, cmd:sub(2))
    elseif cmd:match("^:") then
      -- vim command
      table.insert(vim_commands, cmd:sub(2))
      table.insert(commands, cmd:sub(2))
    elseif cmd:match("^#") then
      -- other step
      local cs, scs, vcs, lfs = M.get_commands(config, cmd, args)
      table_concat(commands, cs)
      table_concat(shell_commands, scs)
      table_concat(vim_commands, vcs)
      table_concat(lua_functions, lfs)
    else
      -- shell command
      table.insert(shell_commands, cmd)
      table.insert(commands, "!" .. cmd)
    end
  elseif type(cmd) == "function" then
    table.insert(lua_functions, cmd)
    table.insert(commands, function()
      cmd(args)
    end)
  end
  return commands, shell_commands, vim_commands, lua_functions
end

function M.get_commands(config, steps, args)
  if type(steps) == "string" then
    steps = { steps }
  end
  local commands = {}
  local shell_commands = {}
  local vim_commands = {}
  local lua_functions = {}
  for _, step in ipairs(steps) do
    local cmd
    if type(step) == "string" and step:match("^#") then
      cmd = config[step:sub(2)]
    elseif type(step) == "string" then
      cmd = step
    else
      print("[Runit] Invalid step: " .. step)
    end
    if cmd ~= nil then
      if type(cmd) == "table" then
        for _, c in ipairs(cmd) do
          local cs, scs, vcs, lfs = M.format_command(config, c, step, args)
          table_concat(commands, cs)
          table_concat(shell_commands, scs)
          table_concat(vim_commands, vcs)
          table_concat(lua_functions, lfs)
        end
      elseif type(cmd) == "string" or type(cmd) == "function" then
        local cs, scs, vcs, lfs = M.format_command(config, cmd, step, args)
        table_concat(commands, cs)
        table_concat(shell_commands, scs)
        table_concat(vim_commands, vcs)
        table_concat(lua_functions, lfs)
      end
    end
  end
  return commands, shell_commands, vim_commands, lua_functions
end

function M.run_by_config(conf, steps, args)
  local commands, shell_commands, vim_commands, lua_functions = M.get_commands(conf, steps, args)
  for _, cmd in ipairs(commands) do
    print(cmd)
  end
  if #commands == 0 then
    print("[Runit] No commands found")
    return false
  end
  -- if only shell commands, use vim-dispatch
  if #vim_commands == 0 and #lua_functions == 0 then
    if not vim.fn.exists(":Dispatch") then
      vim.cmd("!" .. table.concat(shell_commands, " && "))
    else
      vim.cmd("Dispatch " .. table.concat(shell_commands, " && "))
    end
  else
    -- exec commands in order
    -- TODO: break if any command failed
    for _, cmd in ipairs(commands) do
      if type(cmd) == "string" then
        vim.cmd(cmd)
      elseif type(cmd) == "function" then
        if cmd() == false then
          break
        end
      end
    end
  end
  conf["__last__"] = steps
  return true
end

return M
