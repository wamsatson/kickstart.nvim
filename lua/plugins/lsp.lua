return {
  -- Main LSP Configuration
  'neovim/nvim-lspconfig',
  dependencies = {
    -- Automatically install LSPs and related tools to stdpath for Neovim
    -- Mason must be loaded before its dependents so we need to set it up here.
    -- NOTE: `opts = {}` is the same as calling `require('mason').setup({})`
    { 'williamboman/mason.nvim', opts = {} },
    'williamboman/mason-lspconfig.nvim',
    'WhoIsSethDaniel/mason-tool-installer.nvim',

    -- Useful status updates for LSP.
    { 'j-hui/fidget.nvim', opts = {} },

    -- Allows extra capabilities provided by nvim-cmp
    'hrsh7th/cmp-nvim-lsp',

    -- Schema store for JSON and YAML validation
    'b0o/schemastore.nvim',
  },
  config = function()
    --  LSP servers and clients are able to communicate to each other what features they support.
    --  By default, Neovim doesn't support everything that is in the LSP specification.
    --  When you add nvim-cmp, luasnip, etc. Neovim now has *more* capabilities.
    --  So, we create new capabilities with nvim cmp, and then broadcast that to the servers.
    local capabilities = vim.lsp.protocol.make_client_capabilities()
    capabilities = vim.tbl_deep_extend('force', capabilities, require('cmp_nvim_lsp').default_capabilities())

    -- Enable the following language servers
    --  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
    --
    --  Add any additional override configuration in the following tables. Available keys are:
    --  - cmd (table): Override the default command used to start the server
    --  - filetypes (table): Override the default list of associated filetypes for the server
    --  - capabilities (table): Override fields in capabilities. Can be used to disable certain LSP features.
    --  - settings (table): Override the default settings passed when initializing the server.
    --        For example, to see the options for `lua_ls`, you could go to: https://luals.github.io/wiki/settings/
    local servers = {
      -- clangd = {},
      -- gopls = {},
      pyright = {
        -- This function will be called before Pyright is initialized
        -- to detect the Poetry environment and set it up correctly
        before_init = function(params, config)
          -- Try to find Poetry environment by checking for pyproject.toml
          local root_dir = config.root_dir
          local poetry_path = root_dir .. "/pyproject.toml"
          local found_poetry = vim.fn.filereadable(poetry_path) == 1
          
          if found_poetry then
            -- Get the poetry environment path
            local cmd = "cd " .. vim.fn.shellescape(root_dir) .. " && poetry env info -p"
            local handle = io.popen(cmd)
            if handle then
              local poetry_env = handle:read("*a"):gsub("\n", "")
              handle:close()
              
              if poetry_env ~= "" then
                -- Find Python version in the path
                local python_version_cmd = poetry_env .. "/bin/python -c 'import sys; print(f\"{sys.version_info.major}.{sys.version_info.minor}\")'"
                local version_handle = io.popen(python_version_cmd)
                local python_version = "3.x"
                if version_handle then
                  python_version = version_handle:read("*a"):gsub("\n", "")
                  version_handle:close()
                end
                
                -- Construct the paths
                local python_path = poetry_env .. "/bin/python"
                local site_packages = poetry_env .. "/lib/python" .. python_version .. "/site-packages"
                
                -- Log the detected Poetry environment
                vim.notify("Poetry environment detected: " .. python_path, vim.log.levels.INFO)
                vim.notify("Site packages: " .. site_packages, vim.log.levels.DEBUG)
                
                -- Initialize settings if they don't exist
                if not config.settings then config.settings = {} end
                if not config.settings.python then config.settings.python = {} end
                if not config.settings.python.analysis then config.settings.python.analysis = {} end
                
                -- Update the pythonPath in the LSP config
                config.settings.python.pythonPath = python_path
                config.settings.python.venvPath = poetry_env
                
                -- Set extraPaths for import resolution
                config.settings.python.analysis.extraPaths = {
                  site_packages,
                  root_dir,  -- Include project root for local imports
                }
                
                -- Additional analysis settings to improve import resolution
                config.settings.python.analysis.useLibraryCodeForTypes = true
                config.settings.python.analysis.autoSearchPaths = true
                config.settings.python.analysis.diagnosticMode = "workspace"
                config.settings.python.analysis.autoImportCompletions = true
              end
            end
          end
          
          return config
        end,
        settings = {
          python = {
            -- These settings will apply when a Poetry environment is not detected
            analysis = {
              autoSearchPaths = true,
              diagnosticMode = 'workspace',
              useLibraryCodeForTypes = true,
              typeCheckingMode = 'basic',
            },
          },
        },
      },
      -- rust_analyzer = {},

      -- YAML/Docker support
      yamlls = {
        settings = {
          yaml = {
            schemaStore = {
              -- Enable built-in schema store for JSON schema aware completion
              enable = true,
              -- Avoid loading schemas from the SchemaStore when you have local schemas
              url = '',
            },
            -- Enable validation
            validate = true,
            -- Use Kubernetes schemas for appropriate files
            schemas = {
              kubernetes = '/*.k8s.yaml',
              ['http://json.schemastore.org/github-workflow'] = '.github/workflows/*.{yml,yaml}',
              ['http://json.schemastore.org/github-action'] = '.github/action.{yml,yaml}',
              ['http://json.schemastore.org/ansible-stable-2.9'] = 'roles/tasks/*.{yml,yaml}',
              ['http://json.schemastore.org/prettierrc'] = '.prettierrc.{yml,yaml}',
              ['http://json.schemastore.org/docker-compose-2'] = '*docker-compose*.{yml,yaml}',
              ['https://json.schemastore.org/circleciconfig'] = '.circleci/**/*.{yml,yaml}',
            },
            format = {
              enable = true,
            },
            -- Hover over YAML keys
            hover = true,
            -- Enable autocompletion
            completion = true,
            -- Configure how deeply to indent
            editor = {
              tabSize = 2,
            },
          },
        },
      },

      -- Docker support
      dockerls = {},

      -- JSON support
      jsonls = {
        settings = {
          json = {
            -- Use schemastore to get schemas
            schemas = require('schemastore').json.schemas(),
            validate = { enable = true },
            -- Configure formatting
            format = { enable = true },
          },
        },
      },

      -- Terraform/Terragrunt support
      terraformls = {
        filetypes = { 'terraform', 'terraform-vars', 'tf' },
      },

      -- For Terragrunt HCL files
      tflint = {
        filetypes = { 'terraform', 'terraform-vars', 'tf', 'hcl' },
      },
      -- ... etc. See `:help lspconfig-all` for a list of all the pre-configured LSPs
      --
      -- Some languages (like typescript) have entire language plugins that can be useful:
      --    https://github.com/pmizio/typescript-tools.nvim
      --
      -- But for many setups, the LSP (`ts_ls`) will work just fine
      -- ts_ls = {},
      --

      lua_ls = {
        -- cmd = { ... },
        -- filetypes = { ... },
        -- capabilities = {},
        settings = {
          Lua = {
            completion = {
              callSnippet = 'Replace',
            },
            runtime = {
              -- Tell the language server which version of Lua you're using
              version = 'LuaJIT',
            },
            workspace = {
              -- Make the server aware of Neovim runtime files
              library = vim.api.nvim_get_runtime_file('', true),
              checkThirdParty = false,
            },
            -- You can toggle below to ignore Lua_LS's noisy `missing-fields` warnings
            -- diagnostics = { disable = { 'missing-fields' } },
            diagnostics = {
              -- Recognize these as globals to avoid "undefined global" errors
              globals = {
                'vim',
                -- Neovim APIs
                'assert',
                'bit',
                'coroutine',
                'debug',
                'io',
                'jit',
                'math',
                'os',
                'package',
                'string',
                'table',
                'utf8',
                -- Vim-specific globals
                'ipairs',
                'pairs',
                'pcall',
                'require',
                'setmetatable',
                'tonumber',
                'tostring',
                'type',
                'unpack',
                'xpcall',
                -- Common plugins might use these
                'use',
                'describe',
                'it',
                'before_each',
                'after_each',
              },
              -- You can toggle below to ignore Lua_LS's noisy `missing-fields` warnings
              disable = { 'missing-fields' },
            },
            telemetry = {
              enable = false,
            },
          },
        },
      },
    }

    -- Initialize Lua LSP immediately to apply our global settings early
    require('lspconfig').lua_ls.setup(servers.lua_ls)

    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
      callback = function(event)
        local map = function(keys, func, desc, mode)
          mode = mode or 'n'
          vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
        end

        map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
        map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
        map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
        map('<leader>D', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition')
        map('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
        map('<leader>ls', require('telescope.builtin').lsp_dynamic_workspace_symbols, 'Workspace [S]ymbols')
        map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
        map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction', { 'n', 'x' })
        map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

        local function client_supports_method(client, method, bufnr)
          if vim.fn.has 'nvim-0.11' == 1 then
            return client:supports_method(method, bufnr)
          else
            return client.supports_method(method, { bufnr = bufnr })
          end
        end

        -- The following two autocommands are used to highlight references of the
        -- word under your cursor when your cursor rests there for a little while.
        --    See `:help CursorHold` for information about when this is executed
        --
        -- When you move your cursor, the highlights will be cleared (the second autocommand).
        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
          local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
          vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
            buffer = event.buf,
            group = highlight_augroup,
            callback = vim.lsp.buf.document_highlight,
          })

          vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
            buffer = event.buf,
            group = highlight_augroup,
            callback = vim.lsp.buf.clear_references,
          })

          vim.api.nvim_create_autocmd('LspDetach', {
            group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
            callback = function(event2)
              vim.lsp.buf.clear_references()
              vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
            end,
          })
        end

        -- The following code creates a keymap to toggle inlay hints in your
        -- code, if the language server you are using supports them
        --
        -- This may be unwanted, since they displace some of your code
        if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
          map('<leader>th', function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
          end, '[T]oggle Inlay [H]ints')
        end
      end,
    })

    -- Diagnostic Config
    -- See :help vim.diagnostic.Opts
    vim.diagnostic.config {
      severity_sort = true,
      float = { border = 'rounded', source = 'if_many' },
      underline = { severity = vim.diagnostic.severity.ERROR },
      signs = vim.g.have_nerd_font and {
        text = {
          [vim.diagnostic.severity.ERROR] = '󰅚 ',
          [vim.diagnostic.severity.WARN] = '󰀪 ',
          [vim.diagnostic.severity.INFO] = '󰋽 ',
          [vim.diagnostic.severity.HINT] = '󰌶 ',
        },
      } or {},
      virtual_text = {
        source = 'if_many',
        spacing = 2,
        format = function(diagnostic)
          local diagnostic_message = {
            [vim.diagnostic.severity.ERROR] = diagnostic.message,
            [vim.diagnostic.severity.WARN] = diagnostic.message,
            [vim.diagnostic.severity.INFO] = diagnostic.message,
            [vim.diagnostic.severity.HINT] = diagnostic.message,
          }
          return diagnostic_message[diagnostic.severity]
        end,
      },
    }

    -- Server configurations were moved to the top of the file for proper initialization order

    -- Ensure the servers and tools above are installed
    --
    -- To check the current status of installed tools and/or manually install
    -- other tools, you can run
    --    :Mason
    --
    -- You can press `g?` for help in this menu.
    --
    -- `mason` had to be setup earlier: to configure its options see the
    -- `dependencies` table for `nvim-lspconfig` above.
    --
    -- You can add other tools here that you want Mason to install
    -- for you, so that they are available from within Neovim.
    local ensure_installed = vim.tbl_keys(servers or {})
    vim.list_extend(ensure_installed, {
      'stylua', -- Used to format Lua code
      'pyright', -- Python LSP
      'ruff', -- Fast Python linter written in Rust
      'black', -- Python formatter
      'isort', -- Python import sorter

      -- YAML/Docker/JSON/Terraform tools
      'yaml-language-server', -- YAML language server
      'dockerfile-language-server', -- Dockerfile language server
      'json-lsp', -- JSON language server
      'terraform-ls', -- Terraform language server
      'tflint', -- Terraform linter that can also handle HCL
    })
    require('mason-tool-installer').setup { ensure_installed = ensure_installed }

    require('mason-lspconfig').setup {
      ensure_installed = {}, -- explicitly set to an empty table (Kickstart populates installs via mason-tool-installer)
      automatic_installation = false,
      handlers = {
        function(server_name)
          local server = servers[server_name] or {}
          -- This handles overriding only values explicitly passed
          -- by the server configuration above. Useful when disabling
          -- certain features of an LSP (for example, turning off formatting for ts_ls)
          server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
          require('lspconfig')[server_name].setup(server)
        end,
      },
    }

    -- Setup additional Python-specific LSP configurations
    -- Setup ruff-lsp for Python linting
    require('lspconfig').ruff.setup {
      capabilities = capabilities,
      init_options = {
        settings = {
          -- Any extra CLI arguments for ruff
          args = {},
        },
      },
    }

    -- Helper function to find a Poetry virtual environment and apply it to Pyright
    local function find_poetry_venv()
      local cwd = vim.fn.getcwd()
      local pyproject_file = cwd .. "/pyproject.toml"
  
      if vim.fn.filereadable(pyproject_file) ~= 0 then
        -- pyproject.toml exists, now check if it's a Poetry project
        local file_content = vim.fn.readfile(pyproject_file)
        local is_poetry = false
        
        for _, line in ipairs(file_content) do
          if line:match("^%[tool%.poetry%]") then
            is_poetry = true
            break
          end
        end
        
        if is_poetry then
          -- Get Poetry virtual environment path
          local handle = io.popen("cd " .. vim.fn.shellescape(cwd) .. " && poetry env info -p 2>/dev/null")
          if handle then
            local poetry_venv = handle:read("*a"):gsub("\n", "")
            handle:close()
            
            if poetry_venv ~= "" then
              -- Find Python version
              local python_version_cmd = poetry_venv .. "/bin/python -c 'import sys; print(f\"{sys.version_info.major}.{sys.version_info.minor}\")'"
              local version_handle = io.popen(python_version_cmd)
              local python_version = "3.x"
              if version_handle then
                python_version = version_handle:read("*a"):gsub("\n", "")
                version_handle:close()
              end
              
              -- Construct the site-packages path
              local site_packages = poetry_venv .. "/lib/python" .. python_version .. "/site-packages"
              
              vim.notify("Poetry environment found: " .. poetry_venv, vim.log.levels.INFO)
              return {
                path = poetry_venv,
                python_path = poetry_venv .. "/bin/python",
                site_packages = site_packages,
                python_version = python_version
              }
            end
          end
        end
      end
      
      return nil
    end

    -- Set up autocmd to detect Poetry environments when entering Python files
    vim.api.nvim_create_autocmd("FileType", {
      pattern = {"python"},
      callback = function()
        local venv_info = find_poetry_venv()
        if venv_info then
          -- Update Python path for the current buffer
          vim.b.python_host_prog = venv_info.python_path
          
          -- Get the Pyright client
          local clients = vim.lsp.get_active_clients({name = "pyright"})
          if #clients > 0 then
            local client = clients[1]
            -- Update settings for this client for the current buffer
            client.config.settings = client.config.settings or {}
            client.config.settings.python = client.config.settings.python or {}
            client.config.settings.python.pythonPath = venv_info.python_path
            client.config.settings.python.analysis = client.config.settings.python.analysis or {}
            client.config.settings.python.analysis.extraPaths = {
              venv_info.site_packages,
              vim.fn.getcwd(),  -- Include current directory
            }
            
            -- Notify the LSP server about the updated settings
            client.notify("workspace/didChangeConfiguration", {
              settings = client.config.settings
            })
            
            vim.notify("Applied Poetry environment to Pyright", vim.log.levels.INFO)
          end
        end
      end,
    })
    
    -- Create a command to force reload Python LSP settings with Poetry environment
    vim.api.nvim_create_user_command("ReloadPythonLSP", function()
      vim.cmd("LspRestart pyright")
      local venv_info = find_poetry_venv()
      if venv_info then
        vim.notify("Reloaded Pyright with Poetry environment: " .. venv_info.path, vim.log.levels.INFO)
      else
        vim.notify("No Poetry environment found", vim.log.levels.WARN)
      end
    end, {desc = "Reload Python LSP with Poetry environment"})

    -- Add file type associations for Docker Compose files
    vim.api.nvim_create_autocmd({ 'BufNewFile', 'BufRead' }, {
      pattern = { 'docker-compose*.yml', 'docker-compose*.yaml' },
      callback = function()
        vim.bo.filetype = 'yaml.docker-compose'
      end,
    })

    -- Add file type associations for Terragrunt files
    vim.api.nvim_create_autocmd({ 'BufNewFile', 'BufRead' }, {
      pattern = { '*.hcl', 'terragrunt.hcl' },
      callback = function()
        -- Set filetype to hcl for terraformls and tflint to pick up
        vim.bo.filetype = 'hcl'
      end,
    })
  end,
}
