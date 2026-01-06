-- dailychamp.nvim
-- A Neovim plugin for managing daily task markdown files
-- Designed for use with DailyChamp App (Flutter)

local M = {}

-- Default configuration (easily customizable)
M.config = {
  -- Date format for day headers
  date_format = "%Y-%m-%d", -- 2026-01-06
  day_format = "%A",        -- Monday, Tuesday, etc.
  
  -- Template sections (customize order and names)
  sections = {
    "Goals",
    "Tasks", 
    "Notes",
    "Reflections"
  },
  
  -- Default task time estimate
  default_hours = "1.0",
  
  -- File paths (customize to your setup)
  file_path = vim.fn.expand("~/Nextcloud/Notes/dailychamp/daily.md"),
  
  -- Keybindings prefix (uses localleader for filetype-specific bindings)
  leader = "<localleader>",
}

-- Setup function to override defaults
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

-- Helper: Get current date formatted
local function get_date_string()
  return os.date(M.config.date_format)
end

local function get_day_string()
  return os.date(M.config.day_format)
end

-- Helper: Get cursor position
local function get_cursor_pos()
  return vim.api.nvim_win_get_cursor(0)
end

-- Helper: Set cursor position
local function set_cursor_pos(row, col)
  vim.api.nvim_win_set_cursor(0, {row, col})
end

-- Helper: Insert lines at current position
local function insert_lines(lines)
  local row = get_cursor_pos()[1]
  vim.api.nvim_buf_set_lines(0, row - 1, row - 1, false, lines)
end

-- Helper: Append lines at end of buffer
local function append_lines(lines)
  local line_count = vim.api.nvim_buf_line_count(0)
  vim.api.nvim_buf_set_lines(0, line_count, line_count, false, lines)
end

-- Helper: Find line matching pattern
local function find_line(pattern)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  for i, line in ipairs(lines) do
    if line:match(pattern) then
      return i
    end
  end
  return nil
end

-- Helper: Extract sections from a day entry
local function get_sections_from_day(date_string)
  local pattern = "^# " .. date_string:gsub("%-", "%%-")
  local line_num = find_line(pattern)
  
  if not line_num then
    return nil
  end
  
  local all_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local sections = {}
  local day_end = nil
  
  -- Find the end of this day entry (next day header, separator, or end of file)
  for i = line_num + 1, #all_lines do
    if all_lines[i]:match("^%-%-%-") or all_lines[i]:match("^# %d%d%d%d%-%d%d%-%d%d") then
      day_end = i
      break
    end
  end
  day_end = day_end or #all_lines
  
  -- Extract section names (without tasks/content)
  for i = line_num + 1, day_end - 1 do
    local section = all_lines[i]:match("^## (.+)")
    if section then
      table.insert(sections, section)
    end
  end
  
  return sections
end

-- Template: New day entry
function M.new_day(date_override)
  local date = date_override or get_date_string()
  local day
  
  if date_override then
    -- Parse the date string and calculate the day of week
    local year, month, day_num = date_override:match("(%d+)-(%d+)-(%d+)")
    if year and month and day_num then
      local time = os.time({year = tonumber(year), month = tonumber(month), day = tonumber(day_num)})
      day = os.date(M.config.day_format, time)
    else
      day = get_day_string() -- fallback to today if parsing fails
    end
  else
    day = get_day_string()
  end
  
  local lines = {
    "# " .. date .. " " .. day,
    "",
  }
  
  -- Try to copy sections from the previous day
  local year, month, day_num = date:match("(%d+)-(%d+)-(%d+)")
  local sections_to_use = nil
  
  if year and month and day_num then
    local time = os.time({year = tonumber(year), month = tonumber(month), day = tonumber(day_num)})
    local prev_time = time - 86400 -- Previous day
    local prev_date = os.date(M.config.date_format, prev_time)
    sections_to_use = get_sections_from_day(prev_date)
  end
  
  -- Use previous day's sections if found and not empty, otherwise use config defaults
  local sections = M.config.sections
  if sections_to_use and #sections_to_use > 0 then
    sections = sections_to_use
  end
  
  for _, section in ipairs(sections) do
    table.insert(lines, "## " .. section)
    table.insert(lines, "")
  end
  
  table.insert(lines, "")
  
  return lines
end

-- Command: Smart insert new day - jump to today if exists, create if not
function M.insert_new_day()
  local today = get_date_string()
  -- Escape special characters in date for pattern matching
  local pattern = "^# " .. today:gsub("%-", "%%-")
  local line_num = find_line(pattern)
  
  if line_num then
    -- Today exists, jump to it
    set_cursor_pos(line_num, 0)
    vim.cmd("normal! zz") -- Center screen
    print("Jumped to today: " .. today)
  else
    -- Today doesn't exist, create it at top (copy from yesterday)
    local lines = M.new_day_with_template()
    vim.api.nvim_buf_set_lines(0, 0, 0, false, lines)
    -- Move cursor to first section
    set_cursor_pos(3, 0) -- After first ## header
    print("Created new day entry for " .. today)
  end
end

-- Helper: Get available templates from templates/*.md
local function get_available_templates()
  -- Get the directory where daily.md is located
  local daily_dir = vim.fn.fnamemodify(M.config.file_path, ":h")
  local template_dir = daily_dir .. "/templates"
  local templates = {}
  
  -- Check if templates directory exists
  if vim.fn.isdirectory(template_dir) == 1 then
    local files = vim.fn.glob(template_dir .. "/*.md", false, true)
    for _, file in ipairs(files) do
      local filename = vim.fn.fnamemodify(file, ":t:r") -- Get filename without extension
      table.insert(templates, filename)
    end
  end
  
  return templates
end

-- Helper: Load sections from template file
local function load_template_sections(template_name)
  -- Get the directory where daily.md is located
  local daily_dir = vim.fn.fnamemodify(M.config.file_path, ":h")
  local template_path = daily_dir .. "/templates/" .. template_name .. ".md"
  
  if vim.fn.filereadable(template_path) == 0 then
    return nil
  end
  
  local lines = vim.fn.readfile(template_path)
  local sections = {}
  
  for _, line in ipairs(lines) do
    local section = line:match("^## (.+)")
    if section then
      table.insert(sections, section)
    end
  end
  
  return sections
end

-- Template: New day entry with optional template override
function M.new_day_with_template(date_override, template_sections)
  local date = date_override or get_date_string()
  local day
  
  if date_override then
    -- Parse the date string and calculate the day of week
    local year, month, day_num = date_override:match("(%d+)-(%d+)-(%d+)")
    if year and month and day_num then
      local time = os.time({year = tonumber(year), month = tonumber(month), day = tonumber(day_num)})
      day = os.date(M.config.day_format, time)
    else
      day = get_day_string()
    end
  else
    day = get_day_string()
  end
  
  local lines = {
    "# " .. date .. " " .. day,
    "",
  }
  
  -- Determine which sections to use
  local sections
  if template_sections then
    -- Use provided template sections
    sections = template_sections
  else
    -- Try to copy sections from the previous day
    local year, month, day_num = date:match("(%d+)-(%d+)-(%d+)")
    local sections_to_use = nil
    
    if year and month and day_num then
      local time = os.time({year = tonumber(year), month = tonumber(month), day = tonumber(day_num)})
      local prev_time = time - 86400 -- Previous day
      local prev_date = os.date(M.config.date_format, prev_time)
      sections_to_use = get_sections_from_day(prev_date)
    end
    
    -- Use previous day's sections if found and not empty, otherwise use config defaults
    sections = M.config.sections
    if sections_to_use and #sections_to_use > 0 then
      sections = sections_to_use
    end
  end
  
  for _, section in ipairs(sections) do
    table.insert(lines, "## " .. section)
    table.insert(lines, "")
  end
  
  table.insert(lines, "")
  
  return lines
end

-- Command: Insert new day with date prompt and template selection
function M.insert_new_day_with_prompt()
  vim.ui.input({ 
    prompt = "Date (YYYY-MM-DD): ",
    default = get_date_string()
  }, function(date)
    if not date or date == "" then return end
    
    -- Check if this date already exists
    local pattern = "^# " .. date:gsub("%-", "%%-")
    local line_num = find_line(pattern)
    
    if line_num then
      set_cursor_pos(line_num, 0)
      vim.cmd("normal! zz")
      print("Entry for " .. date .. " already exists. Jumped to it.")
      return
    end
    
    -- Get available templates
    local templates = get_available_templates()
    
    if #templates == 0 then
      -- No templates found, create with default behavior
      local lines = M.new_day_with_template(date, nil)
      vim.api.nvim_buf_set_lines(0, 0, 0, false, lines)
      set_cursor_pos(3, 0)
      print("Created new day entry for " .. date)
    else
      -- Show template selection
      table.insert(templates, 1, "previous-day") -- Add "previous day" option at start
      
      vim.ui.select(templates, {
        prompt = "Select template:",
        format_item = function(item)
          if item == "previous-day" then
            return "📅 Copy from previous day"
          else
            return "📄 " .. item
          end
        end
      }, function(choice)
        if not choice then
          print("Cancelled")
          return
        end
        
        local template_sections = nil
        if choice ~= "previous-day" then
          template_sections = load_template_sections(choice)
          if not template_sections or #template_sections == 0 then
            print("Could not load template: " .. choice)
            return
          end
        end
        
        local lines = M.new_day_with_template(date, template_sections)
        vim.api.nvim_buf_set_lines(0, 0, 0, false, lines)
        set_cursor_pos(3, 0)
        print("Created new day entry for " .. date)
      end)
    end
  end)
end

-- Command: Insert new day at cursor
function M.insert_new_day_at_cursor()
  local lines = M.new_day()
  insert_lines(lines)
  print("Inserted new day entry at cursor")
end

-- Template: New task (checkbox)
function M.new_task(title, hours)
  title = title or ""
  hours = hours or M.config.default_hours
  return "- [ ] " .. title .. " | " .. hours .. "h"
end

-- Command: Insert new task
function M.insert_task()
  vim.ui.input({ prompt = "Task title: " }, function(title)
    if not title or title == "" then return end
    
    vim.ui.input({ 
      prompt = "Estimated hours (" .. M.config.default_hours .. "): ",
      default = M.config.default_hours 
    }, function(hours)
      hours = (hours and hours ~= "") and hours or M.config.default_hours
      local task = M.new_task(title, hours)
      local row = get_cursor_pos()[1]
      vim.api.nvim_buf_set_lines(0, row, row, false, {task})
      set_cursor_pos(row + 1, 0)
      print("Added task: " .. title)
    end)
  end)
end

-- Command: Quick insert task (no prompts, enter inline)
function M.quick_task()
  local row = get_cursor_pos()[1]
  local task = M.new_task("", M.config.default_hours)
  vim.api.nvim_buf_set_lines(0, row, row, false, {task})
  -- Move cursor to title position (after "- [ ] ")
  set_cursor_pos(row + 1, 6)
  -- Enter insert mode
  vim.cmd("startinsert")
end

-- Command: Toggle task completion
function M.toggle_task()
  local row = get_cursor_pos()[1]
  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
  
  if line:match("^%s*%- %[ %]") then
    -- Incomplete -> Complete
    local new_line = line:gsub("^(%s*%- )%[ %]", "%1[x]")
    vim.api.nvim_buf_set_lines(0, row - 1, row, false, {new_line})
    print("Task completed ✓")
  elseif line:match("^%s*%- %[[xX]%]") then
    -- Complete -> Incomplete
    local new_line = line:gsub("^(%s*%- )%[[xX]%]", "%1[ ]")
    vim.api.nvim_buf_set_lines(0, row - 1, row, false, {new_line})
    print("Task reopened")
  else
    print("Not a task line")
  end
end

-- Template: New section
function M.new_section(name)
  return {
    "## " .. name,
    ""
  }
end

-- Command: Insert new section
function M.insert_section()
  vim.ui.input({ prompt = "Section name: " }, function(name)
    if not name or name == "" then return end
    local lines = M.new_section(name)
    insert_lines(lines)
    print("Added section: " .. name)
  end)
end

-- Command: Jump to today's entry
function M.jump_to_today()
  local today = get_date_string()
  local pattern = "^# " .. today:gsub("%-", "%%-")
  local line_num = find_line(pattern)
  
  if line_num then
    set_cursor_pos(line_num, 0)
    vim.cmd("normal! zz") -- Center screen
    print("Jumped to today: " .. today)
  else
    print("Today's entry not found. Create it with :DailyChampNewDay")
  end
end

-- Command: Jump to specific date
function M.jump_to_date()
  vim.ui.input({ 
    prompt = "Date (YYYY-MM-DD): ",
    default = get_date_string()
  }, function(date)
    if not date or date == "" then return end
    local pattern = "^# " .. date:gsub("%-", "%%-")
    local line_num = find_line(pattern)
    
    if line_num then
      set_cursor_pos(line_num, 0)
      vim.cmd("normal! zz")
      print("Jumped to: " .. date)
    else
      print("Entry not found for: " .. date)
    end
  end)
end

-- Command: Copy task to tomorrow (same section or create section if needed)
function M.copy_task_to_tomorrow()
  local row = get_cursor_pos()[1]
  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
  
  -- Check if it's a task
  if not line:match("^%s*%- %[[ xX]%]") then
    print("Not a task line")
    return
  end
  
  -- Extract task title and hours, make it incomplete
  local task = line:gsub("%- %[[xX]%]", "- [ ]")
  
  -- Find current section by searching backwards
  local current_section = nil
  local all_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  for i = row, 1, -1 do
    if all_lines[i]:match("^## (.+)") then
      current_section = all_lines[i]:match("^## (.+)")
      break
    end
    -- Stop at day header
    if all_lines[i]:match("^# %d") then
      break
    end
  end
  
  -- Find tomorrow's entry
  local tomorrow = os.date(M.config.date_format, os.time() + 86400) -- +1 day
  local pattern = "^# " .. tomorrow:gsub("%-", "%%-")
  local line_num = find_line(pattern)
  
  if not line_num then
    print("Tomorrow's entry not found. Create it first!")
    return
  end
  
  -- Find the same section in tomorrow's entry, or create it
  local lines = vim.api.nvim_buf_get_lines(0, line_num, -1, false)
  local section_line = nil
  local day_end = nil
  
  for i, l in ipairs(lines) do
    -- Stop at next day separator
    if l:match("^%-%-%-") or (i > 1 and l:match("^# %d")) then
      day_end = line_num + i - 1
      break
    end
    -- Check if we found the matching section
    if current_section and l:match("^## " .. current_section:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")) then
      section_line = line_num + i
      break
    end
  end
  
  if not day_end then
    day_end = line_num + #lines
  end
  
  if section_line then
    -- Section exists, add task after the section header
    vim.api.nvim_buf_set_lines(0, section_line, section_line, false, {task})
    print("Task copied to tomorrow's " .. current_section .. " section")
  else
    -- Section doesn't exist, create it before the day separator
    local new_lines = {"## " .. (current_section or "Tasks"), task, ""}
    vim.api.nvim_buf_set_lines(0, day_end - 1, day_end - 1, false, new_lines)
    print("Created " .. (current_section or "Tasks") .. " section and copied task")
  end
end

-- Command: Add note
function M.add_note()
  vim.ui.input({ prompt = "Note: " }, function(note)
    if not note or note == "" then return end
    local row = get_cursor_pos()[1]
    vim.api.nvim_buf_set_lines(0, row, row, false, {"- " .. note})
    set_cursor_pos(row + 1, 0)
    print("Added note")
  end)
end

-- Command: Open dailychamp/daily.md file
function M.open_file()
  vim.cmd("edit " .. M.config.file_path)
end

-- Helper: Count tasks in current day
function M.count_day_stats()
  local row = get_cursor_pos()[1]
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  
  -- Find current day boundaries
  local day_start = nil
  local day_end = nil
  
  -- Find start (search backwards for # date)
  for i = row, 1, -1 do
    if lines[i]:match("^# %d%d%d%d%-%d%d%-%d%d") then
      day_start = i
      break
    end
  end
  
  -- Find end (search forwards for --- or next # date)
  for i = row, #lines do
    if lines[i]:match("^%-%-%-") or (i > row and lines[i]:match("^# %d%d%d%d%-%d%d%-%d%d")) then
      day_end = i
      break
    end
  end
  
  if not day_start then
    print("Not inside a day entry")
    return
  end
  
  day_end = day_end or #lines
  
  -- Count tasks
  local total = 0
  local completed = 0
  
  for i = day_start, day_end do
    if lines[i]:match("^%s*%- %[[ xX]%]") then
      total = total + 1
      if lines[i]:match("^%s*%- %[[xX]%]") then
        completed = completed + 1
      end
    end
  end
  
  local percentage = total > 0 and math.floor((completed / total) * 100) or 0
  print(string.format("Tasks: %d/%d completed (%d%%)", completed, total, percentage))
end

return M
