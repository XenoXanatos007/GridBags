local checks = 0
local function check(value, message) assert(value, message); checks = checks + 1 end
bankOpen = false; G.sceneName = "inventory"; G.selectedCharacter = GridBagsSnapshots.characterId
PLAYER_INVENTORY.selectedTabType = INVENTORY_BACKPACK
G.saved.enabled = true; G.saved.externalFilters = false
G:Refresh()
for _, panel in ipairs(G.panels) do
    check(panel.search.mouseEnabled and panel.search.keyboardEnabled ~= true and panel.search.editEnabled
        and panel.search.template == "ZO_DefaultEditForBackdrop",
        "native search accepts clicks without raw keyboard capture")
    check(not panel.search.focused, "opening inventory does not focus search")
    panel.search.handlers.OnMouseDown(panel.search, MOUSE_BUTTON_INDEX_LEFT)
    check(panel.search.focused, "click input takes focus")
    panel.search.handlers.OnEscape(panel.search)
    check(not panel.search.focused, "escape releases focus")
    panel.searchBackground.handlers.OnMouseDown(panel.searchBackground, MOUSE_BUTTON_INDEX_LEFT)
    check(panel.search.focused, "click input padding takes focus")
end
check(not G.backpack.search.focused and G.bank.search.focused, "only clicked search has typing focus")
G.backpack.search.handlers.OnMouseDown(G.backpack.search, MOUSE_BUTTON_INDEX_LEFT)
check(G.backpack.search.focused and not G.bank.search.focused, "native focus switches between inputs")
G.backpack.search:SetText("LoGoUt")
G.backpack.search.handlers.OnTextChanged(G.backpack.search)
check(G.backpack.query == "logout" and G.backpack.scrollRow == 0, "typing updates normalized query and resets scroll")
G:Refresh()
check(G.backpack.search.focused, "live filtering keeps typing focus")
G.saved.enabled = false; G:Refresh()
check(G.root:IsHidden() and not G.returnToGrid:IsHidden(), "standard inventory has grid return button")
check(not G.backpack.search.focused and not G.bank.search.focused, "hiding grid releases both search boxes")
G.returnButton.handlers.OnClicked(G.returnButton)
check(G.saved.enabled and not G.root:IsHidden() and G.returnToGrid:IsHidden(), "return button re-enables grid")
bankOpen = true; G.sceneName = "bank"; G.saved.enabled = false; G:Refresh()
check(not G.returnToGrid:IsHidden(), "standard bank has grid return button")
G.returnButton.handlers.OnClicked(G.returnButton)
check(G.saved.enabled and not G.root:IsHidden(), "return button works at banker")
G.saved.enabled = false; bankOpen = false; G.sceneName = nil; G:Refresh()
check(G.returnToGrid:IsHidden(), "return button absent on HUD")
G.sceneName = "inventory"; gamepad = true; G:Refresh()
check(G.returnToGrid:IsHidden(), "return button absent in gamepad mode")
gamepad = false; PLAYER_INVENTORY.selectedTabType = 6; G:Refresh()
check(G.returnToGrid:IsHidden(), "return button absent on unsupported inventory tab")
PLAYER_INVENTORY.selectedTabType = INVENTORY_BACKPACK; G.saved.enabled = true
SCENE_MANAGER:GetScene("inventory").callback(nil, SCENE_SHOWING)
check(not G.backpack.search.focused and not G.bank.search.focused, "scene opening resets typing focus")
check(G.backpack.search.keyboardEnabled ~= true and G.bank.search.keyboardEnabled ~= true,
    "idle inputs do not request raw keyboard events")
print(string.format("PASS: %d search/return-button regression checks (Lua 5.1, mocked ESO interfaces).", checks))
