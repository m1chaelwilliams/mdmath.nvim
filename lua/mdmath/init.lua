local api = vim.api

local M = {}

M.is_loaded = false

function M.setup(opts)
    if M.is_loaded then
        if opts then
            error("Attempt to setup mdmath.nvim multiple times (see README for more information)")
        end
        return
    end

    local filetypes = opts
        and opts.filetypes
        or {'markdown'}

    assert(type(filetypes) == 'table', 'filetypes: expected table, got ' .. type(filetypes))

    -- empty case: {}
    if filetypes[1] ~= nil then
        local group = api.nvim_create_augroup('MdMath', {clear = true})

        api.nvim_create_autocmd('FileType', {
            group = group,
            pattern = filetypes,
            callback = function()
                local bufnr = api.nvim_get_current_buf()
                
                -- defer the function, since it's not needed for the UI
                vim.defer_fn(function()
                    if api.nvim_buf_is_valid(bufnr) then
                        M.enable(bufnr)
                    end
                end, 100)
            end,
        })

        local subcommands = {
            enable = M.enable,
            disable = M.disable,
            clear = M.clear,
        }

        api.nvim_create_user_command('MdMath', function(opts)
            local cmd = opts.fargs[1]
            if not subcommands[cmd] then
                vim.notify('MdMath: invalid subcommand: ' .. cmd, vim.log.levels.ERROR)
                return
            end

            subcommands[cmd]()
        end, {
            nargs = 1,
            complete = function()
                return { 'enable', 'disable', 'clear' }
            end,
        });
    end

    require'mdmath.config'._set(opts)
    M.is_loaded = true
end

function M.enable(bufnr)
    if not M.is_loaded then
        error "Attempt to call mdmath.nvim before it's loaded (see README for more information)"
    end
    require 'mdmath.manager'.enable(bufnr or 0)
end

function M.disable(bufnr)
    if not M.is_loaded then
        error "Attempt to call mdmath.nvim before it's loaded (see README for more information)"
    end
    require 'mdmath.manager'.disable(bufnr or 0)
end

function M.clear(bufnr)
    if not M.is_loaded then
        error "Attempt to call mdmath.nvim before it's loaded (see README for more information)"
    end
    require 'mdmath.manager'.clear(bufnr or 0)
end

return M
