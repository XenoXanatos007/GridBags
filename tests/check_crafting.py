"""Crafting qualification, overlapping material rules, safety and configuration, Lua 5.1."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute((root / 'tests/eso_mock.lua').read_text())
for line in (root / 'GridBags/GridBags.txt').read_text().splitlines():
    if line.endswith('.lua') and line != 'GridBags.lua':
        lua.execute((root / 'GridBags' / line).read_text())
lua.globals().G = lua.execute((root / 'GridBags/GridBags.lua').read_text() + '\nreturn G')
lua.execute('G:Initialize()')
lua.execute((root / 'tests/crafting.lua').read_text())
