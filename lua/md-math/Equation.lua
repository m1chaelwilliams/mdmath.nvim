local vim = vim
local nvim = require'md-math.nvim'
local uv = vim.loop
local marks = require'md-math.marks'
local util = require'md-math.util'
local Processor = require'md-math.Processor'
local Image = require'md-math.Image'
local tracker = require'md-math.tracker'
local terminfo = require'md-math.terminfo'

local Equation = util.class 'Equation'

function Equation:__tostring()
    return '<Equation>'
end

function Equation:_create(res, err)
    if not res then
        local text = ' ' .. err
        local color = 'Error'
        vim.schedule(function()
            if self.valid then
                self.mark_id = marks.add(self.bufnr, self.pos[1], self.pos[2], {
                    text = { text, self.text:len() },
                    color = color,
                    text_pos = 'eol',
                })
                self.created = true
            end
        end)
        return
    end

    local filename = res

    -- Multiline equations
    if self.lines then
        local width = self.width
        local height = #self.lines

        local image = Image.new(height, width, filename)
        local texts = image:text()
        local color = image:color()

        -- Increase text width to match the original width
        local padding_len = self.width > width and self.width - width or 0
        local padding = (' '):rep(padding_len)

        local lines = {}
        for i, text in ipairs(texts) do
            local rtext = text .. padding

            lines[i] = { rtext, self.lines[i]:len() }
        end

        vim.schedule(function()
            if self.valid then
                self.mark_id = marks.add(self.bufnr, self.pos[1], self.pos[2], {
                    lines = lines,
                    color = color,
                    text_pos = 'overlay',
                })
                self.image = image
                self.created = true
            else -- free resources
                image:close()
            end
        end)
    else
        local image = Image.new(1, self.width, filename)
        local text = image:text()[1]
        local color = image:color()

        vim.schedule(function()
            if self.valid then
                self.mark_id = marks.add(self.bufnr, self.pos[1], self.pos[2], {
                    text = { text, self.text:len() },
                    color = color,
                    text_pos = 'overlay',
                })
                self.image = image
                self.created = true
            else -- free resources
                image:close()
            end
        end)
    end
end

local function get_size(filename, callback)
    local stdout = uv.new_pipe(false)
    local handle

    -- Spawn the external program
    handle = uv.spawn("/home/thiagomm/get-size", {
        args = { filename },
        stdio = {nil, stdout, nil}
    }, function(code, signal)
        -- Called when the process exits
        uv.close(handle)  -- Ensure we close the handle after the process exits
        if code ~= 0 then
            callback(nil, "Process exited with code " .. code)
        end
    end)

    -- Read the stdout data
    local output = ""
    uv.read_start(stdout, function(err, data)
        if err then
            callback(nil, err)
            uv.read_stop(stdout)
            uv.close(stdout)  -- Close stdout pipe on error
        elseif data then
            output = output .. data
        else
            -- No more data to read, process the output
            uv.read_stop(stdout)
            uv.close(stdout)  -- Close stdout pipe after reading

            -- Parse the '<width>x<height>' format
            local width, height = output:match("(%d+)x(%d+)")
            if width and height then
                callback({ width = tonumber(width), height = tonumber(height) })
            else
                callback(nil, "Failed to parse size")
            end
        end
    end)

    -- Ensure handle and stdout are closed if there's an error during spawning
    if not handle then
        uv.close(stdout)
        callback(nil, "Failed to spawn process")
    end
end

function Equation:_init(bufnr, row, col, text)
    if text:find('\n') then
        local lines = vim.split(text, '\n')
        -- Only support rectangular equations
        if util.linewidth(bufnr, row) ~= lines[1]:len() or util.linewidth(bufnr, row + #lines - 1) ~= lines[#lines]:len() then
            return false
        end

        local width = 0
        for i, line in ipairs(lines) do
            width = math.max(width, util.strwidth(line))
        end
        self.lines = lines
        self.width = width
    elseif util.linewidth(bufnr, row) == text:len() then
        -- Treat single line equations as a special case
        self.width = util.strwidth(text)
        self.lines = { text }
    end

    self.bufnr = bufnr
    -- TODO: pos should be shared with the mark
    self.pos = tracker.add(bufnr, row, col, text:len())
    self.pos.on_finish = function()
        self:invalidate()
    end

    self.text = text
    if not self.lines then
        self.width = util.strwidth(text)
    end
    self.created = false
    self.valid = true
    
    -- remove trailing '$'
    self.equation = text:gsub('^%$*(.-)%$*$', '%1')

    local cell_width, cell_height = terminfo.cell_size()

    -- dynamic width for multiline equations
    local img_width = self.lines and (self.width * cell_width) or (self.width * cell_width)
    local img_height = (self.lines and #self.lines or 1) * cell_height

    local processor = Processor.from_bufnr(bufnr)
    processor:request(self.equation, img_width, img_height, function(res, err)
        if self.valid then
            self:_create(res, err)
        end
    end)
end

-- TODO: should we call invalidate() on '__gc'?
function Equation:invalidate()
    if not self.valid then
        return
    end
    self.valid = false
    if not self.created then
        return
    end

    -- UU.notify('Invalidating', self.text)

    self.pos:cancel()
    marks.remove(self.bufnr, self.mark_id)
    self.mark_id = nil
end

return Equation
