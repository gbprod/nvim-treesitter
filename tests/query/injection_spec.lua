local config = require('nvim-treesitter.config')
local ts = vim.treesitter

local function check_assertions(file)
  local buf = vim.fn.bufadd(file)
  vim.fn.bufload(file)
  local ft = vim.bo[buf].filetype
  local lang = vim.treesitter.language.get_lang(ft) or ft
  assert.same(
    1,
    vim.fn.executable('highlight-assertions'),
    '"highlight-assertions" not executable!'
      .. ' Get it via "cargo install --git https://github.com/theHamsta/highlight-assertions"'
  )
  local assertions = vim.fn.json_decode(
    vim.fn.system(
      "highlight-assertions -p '"
        .. config.get_install_dir('parser')
        .. '/'
        .. lang
        .. ".so'"
        .. " -s '"
        .. file
        .. "'"
    )
  )
  local parser = ts.get_parser(buf, lang)

  local top_level_root = parser:parse(true)[1]:root()

  for _, assertion in ipairs(assertions) do
    local row = assertion.position.row
    local col = assertion.position.column

    local neg_assert = assertion.expected_capture_name:match('^!')
    assertion.expected_capture_name = neg_assert and assertion.expected_capture_name:sub(2)
      or assertion.expected_capture_name
    local found = false
    parser:for_each_tree(function(tstree, tree)
      if not tstree then
        return
      end
      local root = tstree:root()
      --- If there are multiple tree with the smallest range possible
      --- Check all of them to see if they fit or not
      if not ts.is_in_node_range(root, row, col) or root == top_level_root then
        return
      end
      if assertion.expected_capture_name == tree:lang() then
        found = true
      end
    end)
    if neg_assert then
      assert.False(
        found,
        'Error in '
          .. file
          .. ':'
          .. (row + 1)
          .. ':'
          .. (col + 1)
          .. ': expected "'
          .. assertion.expected_capture_name
          .. '" not to be injected here!'
      )
    else
      assert.True(
        found,
        'Error in '
          .. file
          .. ':'
          .. (row + 1)
          .. ':'
          .. (col + 1)
          .. ': expected "'
          .. assertion.expected_capture_name
          .. '" to be injected here!'
      )
    end
  end
end

describe('injections', function()
  local files = vim.fn.split(vim.fn.glob('tests/query/injections/**/*.*'))
  for _, file in ipairs(files) do
    it(file, function()
      check_assertions(file)
    end)
  end
end)
