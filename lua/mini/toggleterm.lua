local bufname = "MiniTerminal"
local jobid = -1
local bufid = -1
local terminal_opened_win_id = -1
local M = {}
local config = {
  prefix = "",
  pos = "bot",
  size = 20
}

function M.setup(user_config)
  config = vim.tbl_deep_extend("force", config, user_config or {})
  config.prefix = string.format("%s %d new ", config.pos, config.size)
end

-- It is a single global terminal that can be called from any buffer, unlike other toggle terms this is a single instance.
function M.MiniTerm()
  local buf_exist = vim.api.nvim_buf_is_valid(bufid)
  local current_wind_id = vim.api.nvim_get_current_win()
  if buf_exist then
    local bufinfo = vim.fn.getbufinfo(bufid)[1]
    if bufinfo.hidden == 1 then
      terminal_opened_win_id = current_wind_id
      vim.cmd(config.prefix .. "| buffer " .. bufname)
    else
      vim.fn.win_gotoid(bufinfo.windows[1])
      vim.cmd(":hide")
      if current_wind_id ~= terminal_opened_win_id and current_wind_id ~= bufinfo.windows[1] then
        vim.fn.win_gotoid(current_wind_id)
        terminal_opened_win_id = current_wind_id
        vim.cmd(config.prefix .. "| buffer " .. bufname)
      end
    end
  else
    terminal_opened_win_id = current_wind_id
    vim.cmd(config.prefix .. "| term")
    vim.cmd("file " .. bufname)
    vim.opt_local.relativenumber = false
    vim.opt_local.number = false
    vim.bo.buflisted = false
    bufid = vim.api.nvim_buf_get_number(0)
    jobid = vim.b.terminal_job_id
  end
end

-- Function that sends a command to Miniterm
---@param cmd string
function M.MiniTermSend(cmd)
  local buf_exist = vim.api.nvim_buf_is_valid(bufid)
  if buf_exist then
    vim.fn.jobsend(jobid, cmd .. "\n")
  end
end

return M
