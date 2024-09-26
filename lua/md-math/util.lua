local nvim = require'md-math.nvim'

local M = {}

function M.new_class(name)
    local class = {}
    class.__index = class
    class.__name = name
    class.new = function(...)
        local self = setmetatable({}, class)
        if self._init then
            self:_init(...)
        end
        return self
    end
    return class
end

function M.get_cursor(winid)
    local cursor = nvim.win_get_cursor(winid or 0)
    return cursor[1] - 1, cursor[2]
end

-- FIXME: Almost sure this can be made more efficient
function M.linewidth(bufnr, row)
    local line = nvim.buf_get_lines(bufnr, row, row + 1, false)
    return line and line[1]:len() or 0
end

function M.compute_offset(bufnr, row, col)
    local row_offset = nvim.buf_get_offset(bufnr, row)
    if row_offset == -1 then
        return nil
    end

    local len = M.linewidth(bufnr, row)

    local col_offset = len < col and len or col
    return row_offset + col_offset
end

function M.get_current_view()
    local a = vim.fn.line('w0')
    local b = vim.fn.line('w$')
    return a - 1, b
end

function M.strwidth(str)
    -- TODO: Is nvim.strwidth() the same thing?
    return vim.fn.strdisplaywidth(str)
end

return M
