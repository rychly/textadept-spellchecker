--------------------
-- GUI modification
--------------------

local _M = {}


local spellcheck_menu = {
  title = _L["S_pell check"],
  {
    _L["_Backend selection"],
    function() ui.print("Spellchecker: Backend selection not implemented yet") end
  }
}

function _M.init()
  table.insert(textadept.menu.menubar, #textadept.menu.menubar, spellcheck_menu)
end

return _M