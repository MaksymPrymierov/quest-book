local mod_gui = require("mod-gui")
local defs = require("scripts.quests")

local BUTTON = "qb_open_button"
local WINDOW = "qb_window"
local TRACKER = "qb_tracker"
local CHECK_INTERVAL = 60
local TRACKER_LIMIT = 3

-- Static lookup tables built from the definitions
local quest_by_id = {}
local chapter_by_id = {}
for i, chapter in ipairs(defs.chapters) do
  chapter.order = i
  chapter_by_id[chapter.id] = chapter
end
for i, quest in ipairs(defs.quests) do
  if not quest.requires then
    quest.requires = i > 1 and { defs.quests[i - 1].id } or {}
  end
  quest.order = i
  quest_by_id[quest.id] = quest
end

---------------------------------------------------------------------------
-- Prototype validity
---------------------------------------------------------------------------

local function objective_valid(obj)
  local t = obj.type
  if t == "produce" then
    if obj.fluid then return prototypes.fluid[obj.fluid] ~= nil end
    return prototypes.item[obj.item] ~= nil
  elseif t == "research" then
    return prototypes.technology[obj.tech] ~= nil
  elseif t == "build" then
    return prototypes.entity[obj.entity] ~= nil
  elseif t == "rocket" then
    return true
  elseif t == "visit" then
    return prototypes.space_location[obj.planet] ~= nil and game.planets[obj.planet] ~= nil
  elseif t == "reach" then
    return prototypes.space_location[obj.location] ~= nil
  end
  return false
end

local function quest_valid(quest)
  for _, obj in ipairs(quest.objectives) do
    if not objective_valid(obj) then return false end
  end
  for _, reward in ipairs(quest.rewards or {}) do
    if not prototypes.item[reward.name] then return false end
  end
  return true
end

-- Recomputed whenever mods change; kept in storage so it is deterministic in MP.
local function refresh_validity()
  storage.valid = {}
  for _, quest in ipairs(defs.quests) do
    storage.valid[quest.id] = quest_valid(quest)
  end
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local function force_state(force)
  local s = storage.forces[force.index]
  if not s then
    s = { completed = {}, objectives = {}, visited = {}, reached = {}, announced = {} }
    storage.forces[force.index] = s
  end
  return s
end

local function player_state(player)
  local s = storage.players[player.index]
  if not s then
    s = { tracker = true, claimed = {}, selected = nil }
    storage.players[player.index] = s
  end
  return s
end

-- A skipped (invalid) quest counts as done for its dependants.
local function is_done(fs, id)
  return fs.completed[id] ~= nil or not storage.valid[id]
end

local function is_unlocked(fs, quest)
  for _, req in ipairs(quest.requires) do
    if not is_done(fs, req) then return false end
  end
  return true
end

local function quest_status(fs, quest)
  if not storage.valid[quest.id] then return "skipped" end
  if fs.completed[quest.id] then return "done" end
  if is_unlocked(fs, quest) then return "active" end
  return "locked"
end

local function active_quests(fs)
  local list = {}
  for _, quest in ipairs(defs.quests) do
    if quest_status(fs, quest) == "active" then list[#list + 1] = quest end
  end
  return list
end

local function all_done(fs)
  for _, quest in ipairs(defs.quests) do
    if not is_done(fs, quest.id) then return false end
  end
  return true
end

---------------------------------------------------------------------------
-- Objective progress
---------------------------------------------------------------------------

local function produced(force, obj)
  local total = 0
  for _, surface in pairs(game.surfaces) do
    local stats = obj.fluid and force.get_fluid_production_statistics(surface)
      or force.get_item_production_statistics(surface)
    total = total + stats.get_input_count(obj.fluid or obj.item)
  end
  return total
end

-- Returns current, target
local function objective_progress(force, fs, obj)
  local t = obj.type
  if t == "produce" then
    return math.floor(produced(force, obj)), obj.count
  elseif t == "research" then
    local tech = force.technologies[obj.tech]
    return (tech and tech.researched) and 1 or 0, 1
  elseif t == "build" then
    return force.get_entity_count(obj.entity), obj.count
  elseif t == "rocket" then
    return force.rockets_launched, obj.count
  elseif t == "visit" then
    return fs.visited[obj.planet] and 1 or 0, 1
  elseif t == "reach" then
    return fs.reached[obj.location] and 1 or 0, 1
  end
  return 0, 1
end

-- Completed objectives are sticky so that e.g. deconstructing a building
-- does not un-complete a quest.
local function objective_state(force, fs, quest, index)
  local done = fs.objectives[quest.id]
  if fs.completed[quest.id] or (done and done[index]) then
    local obj = quest.objectives[index]
    local target = obj.count or 1
    return target, target, true
  end
  local current, target = objective_progress(force, fs, quest.objectives[index])
  return math.min(current, target), target, current >= target
end

---------------------------------------------------------------------------
-- Texts
---------------------------------------------------------------------------

local function objective_caption(obj)
  local t = obj.type
  if t == "produce" then
    if obj.fluid then
      return { "quest-book.obj-produce", "[fluid=" .. obj.fluid .. "]", prototypes.fluid[obj.fluid].localised_name }
    end
    return { "quest-book.obj-produce", "[item=" .. obj.item .. "]", prototypes.item[obj.item].localised_name }
  elseif t == "research" then
    return { "quest-book.obj-research", "[technology=" .. obj.tech .. "]", prototypes.technology[obj.tech].localised_name }
  elseif t == "build" then
    return { "quest-book.obj-build", "[entity=" .. obj.entity .. "]", prototypes.entity[obj.entity].localised_name }
  elseif t == "rocket" then
    return { "quest-book.obj-rocket" }
  elseif t == "visit" then
    return { "quest-book.obj-visit", "[planet=" .. obj.planet .. "]", prototypes.space_location[obj.planet].localised_name }
  elseif t == "reach" then
    return { "quest-book.obj-reach", "[img=space-location/" .. obj.location .. "]", prototypes.space_location[obj.location].localised_name }
  end
end

-- What clicking an objective opens: the technology tree for research,
-- Factoriopedia for everything else. Returns nil if there is nothing to show.
local function objective_help(obj)
  local t = obj.type
  if t == "research" then
    return "technology", prototypes.technology[obj.tech]
  end
  local proto
  if t == "produce" then
    proto = obj.fluid and prototypes.fluid[obj.fluid] or prototypes.item[obj.item]
    -- rocket parts have no Factoriopedia page of their own; they are made in the silo
    if obj.item == "rocket-part" then proto = prototypes.entity["rocket-silo"] end
  elseif t == "build" then
    proto = prototypes.entity[obj.entity]
  elseif t == "rocket" then
    proto = prototypes.entity["rocket-silo"]
  elseif t == "visit" then
    proto = prototypes.space_location[obj.planet]
  elseif t == "reach" then
    proto = prototypes.space_location[obj.location]
  end
  if proto and not proto.hidden_in_factoriopedia then return "factoriopedia", proto end
end

-- Adds an objective label that opens its help page on click, when it has one.
local function add_objective_label(parent, quest, index, caption)
  local kind = objective_help(quest.objectives[index])
  if not kind then return parent.add { type = "label", caption = caption } end
  return parent.add {
    type = "label", caption = caption, style = "clickable_label",
    tooltip = { "quest-book.help-" .. kind },
    tags = { qb_action = "help", quest = quest.id, objective = index },
  }
end

local function open_objective_help(player, obj)
  local kind, proto = objective_help(obj)
  if kind == "technology" then
    player.open_technology_gui(proto)
  elseif kind == "factoriopedia" then
    player.open_factoriopedia_gui(proto)
  end
end

local STATUS_ICON = {
  done = "[img=utility/check_mark_green]",
  active = "[img=utility/status_yellow]",
  locked = "[img=utility/status_inactive]",
}

---------------------------------------------------------------------------
-- GUI: tracker
---------------------------------------------------------------------------

local update_window_progress

local function destroy_tracker(player)
  local frame = player.gui.left[TRACKER]
  if frame then frame.destroy() end
end

local function update_tracker(player)
  local ps = player_state(player)
  local fs = force_state(player.force)
  local list = active_quests(fs)
  if not ps.tracker or #list == 0 then
    destroy_tracker(player)
    return
  end

  local frame = player.gui.left[TRACKER]
  if frame then
    frame.clear()
  else
    frame = player.gui.left.add { type = "frame", name = TRACKER, direction = "vertical", caption = { "quest-book.tracker-title" } }
    frame.style.maximal_width = 340
  end

  for i = 1, math.min(#list, TRACKER_LIMIT) do
    local quest = list[i]
    local title = frame.add {
      type = "label",
      caption = { "", "[img=" .. chapter_by_id[quest.chapter].icon .. "] ", { "quest-book-title." .. quest.id } },
      tags = { qb_action = "select", quest = quest.id },
      tooltip = { "quest-book.tracker-open-tooltip" },
    }
    title.style.font = "default-bold"
    title.style.font_color = { 1, 0.85, 0.5 }
    for index, obj in ipairs(quest.objectives) do
      local current, target, done = objective_state(player.force, fs, quest, index)
      local text = done and "[img=utility/check_mark_green] " or "    "
      local caption = { "", text, objective_caption(obj) }
      if target > 1 and not done then
        caption[#caption + 1] = "  " .. current .. "/" .. target
      end
      local label = add_objective_label(frame, quest, index, caption)
      label.style.single_line = false
      label.style.maximal_width = 320
      if done then label.style.font_color = { 0.6, 0.6, 0.6 } end
    end
  end
  if #list > TRACKER_LIMIT then
    frame.add { type = "label", caption = { "quest-book.tracker-more", #list - TRACKER_LIMIT } }.style.font_color = { 0.7, 0.7, 0.7 }
  end
end

---------------------------------------------------------------------------
-- GUI: main window
---------------------------------------------------------------------------

local function default_selection(fs)
  local list = active_quests(fs)
  if list[1] then return list[1].id end
  for i = #defs.quests, 1, -1 do
    local quest = defs.quests[i]
    if fs.completed[quest.id] then return quest.id end
  end
  return defs.quests[1].id
end

local function build_quest_list(parent, player, fs, selected)
  local scroll = parent.add { type = "scroll-pane", direction = "vertical", style = "naked_scroll_pane" }
  scroll.style.width = 280
  scroll.style.vertically_stretchable = true
  scroll.style.padding = 4

  for _, chapter in ipairs(defs.chapters) do
    local visible = {}
    for _, quest in ipairs(defs.quests) do
      if quest.chapter == chapter.id and storage.valid[quest.id] then visible[#visible + 1] = quest end
    end
    if #visible > 0 then
      local header = scroll.add { type = "label", caption = { "", "[img=" .. chapter.icon .. "] ", { "quest-book-chapter." .. chapter.id } } }
      header.style.font = "heading-2"
      header.style.top_margin = 6
      for _, quest in ipairs(visible) do
        local status = quest_status(fs, quest)
        local caption
        if status == "locked" then
          caption = { "", STATUS_ICON.locked, " ", { "quest-book.locked-title" } }
        else
          caption = { "", STATUS_ICON[status], " ", { "quest-book-title." .. quest.id } }
        end
        local ps = player_state(player)
        if status == "done" and quest.rewards and not ps.claimed[quest.id] then
          caption[#caption + 1] = " [img=utility/notification]"
        end
        local button = scroll.add {
          type = "button",
          caption = caption,
          style = quest.id == selected and "qb_quest_button_selected" or "qb_quest_button",
          tags = { qb_action = "select", quest = quest.id },
          enabled = status ~= "locked",
        }
        button.style.horizontally_stretchable = true
      end
    end
  end
end

-- Updates objective rows of the open window in place (keeps scroll positions).
update_window_progress = function(player)
  local ps = player_state(player)
  if not ps.rows then return end
  local fs = force_state(player.force)
  for _, row in pairs(ps.rows) do
    if not row.icon.valid then
      ps.rows = nil
      return
    end
    local current, target, done = objective_state(player.force, fs, quest_by_id[row.quest], row.index)
    row.icon.sprite = done and "utility/check_mark_green" or "utility/status_yellow"
    if row.bar then
      row.bar.value = current / target
      row.bar.caption = current .. " / " .. target
      row.bar.style.color = done and { 0.3, 0.8, 0.3 } or { 0.9, 0.7, 0.2 }
    end
  end
end

local function build_details(parent, player, fs, quest)
  local pane = parent.add { type = "frame", direction = "vertical", style = "inside_shallow_frame_with_padding" }
  pane.style.width = 520
  pane.style.vertically_stretchable = true
  local scroll = pane.add { type = "scroll-pane", direction = "vertical", style = "naked_scroll_pane" }
  scroll.style.vertically_stretchable = true
  scroll.style.horizontally_stretchable = true

  local status = quest_status(fs, quest)
  local chapter = chapter_by_id[quest.chapter]
  scroll.add { type = "label", caption = { "", "[img=" .. chapter.icon .. "] ", { "quest-book-chapter." .. chapter.id } } }.style.font_color = { 0.7, 0.7, 0.7 }
  local title = scroll.add { type = "label", caption = { "quest-book-title." .. quest.id } }
  title.style.font = "heading-1"

  local story = scroll.add { type = "label", caption = { "quest-book-story." .. quest.id } }
  story.style.single_line = false
  story.style.maximal_width = 480
  story.style.top_margin = 6
  story.style.bottom_margin = 10
  story.style.font = "default-large"
  story.style.font_color = { 0.95, 0.9, 0.8 }

  scroll.add { type = "line" }
  scroll.add { type = "label", caption = { "quest-book.objectives" }, style = "caption_label" }

  local ps = player_state(player)
  ps.rows = {}
  for index, obj in ipairs(quest.objectives) do
    local row = scroll.add { type = "flow", direction = "horizontal" }
    row.style.vertical_align = "center"
    row.style.top_margin = 4
    local icon = row.add { type = "sprite" }
    icon.style.size = 16
    icon.style.stretch_image_to_widget_size = true
    local label = add_objective_label(row, quest, index, objective_caption(obj))
    label.style.width = 300
    label.style.single_line = false
    local bar
    if (obj.count or 1) > 1 then
      bar = row.add { type = "progressbar" }
      bar.style.width = 150
    end
    ps.rows[index] = { quest = quest.id, index = index, icon = icon, bar = bar }
  end
  update_window_progress(player)

  if quest.rewards then
    scroll.add { type = "line" }.style.top_margin = 8
    scroll.add { type = "label", caption = { "quest-book.rewards" }, style = "caption_label" }
    local row = scroll.add { type = "flow", direction = "horizontal" }
    row.style.vertical_align = "center"
    for _, reward in ipairs(quest.rewards) do
      row.add { type = "sprite-button", sprite = "item/" .. reward.name, number = reward.count, style = "slot_button", elem_tooltip = { type = "item", name = reward.name } }
    end
    if ps.claimed[quest.id] then
      row.add { type = "label", caption = { "quest-book.reward-claimed" } }.style.left_margin = 12
    else
      local claim = row.add { type = "button", caption = { "quest-book.claim" }, style = "confirm_button", tags = { qb_action = "claim", quest = quest.id }, enabled = status == "done" }
      claim.style.left_margin = 12
    end
  end

  if status == "done" then
    local done = scroll.add { type = "label", caption = { "quest-book.quest-done" } }
    done.style.top_margin = 10
    done.style.font_color = { 0.4, 0.9, 0.4 }
  end
end

local function build_window(player)
  local existing = player.gui.screen[WINDOW]
  local location = existing and existing.location
  if existing then existing.destroy() end

  local fs = force_state(player.force)
  local ps = player_state(player)
  local quest = ps.selected and quest_by_id[ps.selected]
  if not quest or quest_status(fs, quest) == "locked" or not storage.valid[quest.id] then
    quest = quest_by_id[default_selection(fs)]
    ps.selected = quest.id
  end

  local window = player.gui.screen.add { type = "frame", name = WINDOW, direction = "vertical" }
  window.style.height = 640
  if location then window.location = location else window.auto_center = true end

  local titlebar = window.add { type = "flow", direction = "horizontal" }
  titlebar.drag_target = window
  titlebar.style.horizontal_spacing = 8
  titlebar.add { type = "label", caption = { "quest-book.window-title" }, style = "frame_title", ignored_by_interaction = true }
  local drag = titlebar.add { type = "empty-widget", style = "draggable_space_header", ignored_by_interaction = true }
  drag.style.horizontally_stretchable = true
  drag.style.height = 24
  titlebar.add {
    type = "checkbox", state = ps.tracker, caption = { "quest-book.show-tracker" },
    tags = { qb_action = "tracker" },
  }
  titlebar.add {
    type = "sprite-button", sprite = "utility/close", style = "close_button",
    tags = { qb_action = "close" }, tooltip = { "gui.close-instruction" },
  }

  local body = window.add { type = "flow", direction = "horizontal" }
  body.style.horizontal_spacing = 12
  body.style.vertically_stretchable = true
  build_quest_list(body, player, fs, quest.id)
  build_details(body, player, fs, quest)

  if all_done(fs) then
    local finale = window.add { type = "label", caption = { "quest-book.finale-banner" } }
    finale.style.font = "default-bold"
    finale.style.font_color = { 0.4, 0.9, 0.4 }
  end

  player.opened = window
end

local function close_window(player)
  local window = player.gui.screen[WINDOW]
  if window then window.destroy() end
  player_state(player).rows = nil
end

local function toggle_window(player)
  if player.gui.screen[WINDOW] then close_window(player) else build_window(player) end
end

local function ensure_button(player)
  local flow = mod_gui.get_button_flow(player)
  -- remove the button left over from 0.0.1
  if flow.qb_open_btn then flow.qb_open_btn.destroy() end
  if not flow[BUTTON] then
    flow.add {
      type = "sprite-button", name = BUTTON, sprite = "qb_book",
      style = mod_gui.button_style, tooltip = { "quest-book.button-tooltip" },
      tags = { qb_action = "toggle" },
    }
  end
end

local function refresh_player(player)
  update_tracker(player)
  if player.gui.screen[WINDOW] then build_window(player) end
end

local function refresh_force(force)
  for _, player in pairs(force.connected_players) do refresh_player(player) end
end

---------------------------------------------------------------------------
-- Progress checking
---------------------------------------------------------------------------

local function announce_unlocks(force, fs, silent)
  for _, quest in ipairs(active_quests(fs)) do
    if not fs.announced[quest.id] then
      fs.announced[quest.id] = true
      if not silent then
        force.print({ "quest-book.quest-unlocked", { "quest-book-title." .. quest.id } }, { color = { 1, 0.85, 0.5 } })
      end
    end
  end
end

local function complete_quest(force, fs, quest)
  fs.completed[quest.id] = game.tick
  fs.objectives[quest.id] = nil
  force.print({ "quest-book.quest-completed", { "quest-book-title." .. quest.id } }, { color = { 0.4, 0.9, 0.4 } })
  if quest.rewards then force.print({ "quest-book.reward-available" }) end
  force.play_sound { path = "utility/achievement_unlocked" }
end

local function check_force(force)
  local fs = force_state(force)
  local changed = false
  -- loop until stable: completing one quest can unlock another that is already satisfied
  repeat
    local progressed = false
    for _, quest in ipairs(active_quests(fs)) do
      local done = fs.objectives[quest.id] or {}
      local all = true
      for index in ipairs(quest.objectives) do
        if not done[index] then
          local current, target = objective_progress(force, fs, quest.objectives[index])
          if current >= target then done[index] = true else all = false end
        end
      end
      fs.objectives[quest.id] = done
      if all then
        complete_quest(force, fs, quest)
        progressed = true
        changed = true
      end
    end
  until not progressed

  if changed then
    announce_unlocks(force, fs, false)
    if all_done(fs) and not fs.finished then
      fs.finished = game.tick
      force.print({ "quest-book.finale" }, { color = { 0.6, 0.9, 1 } })
      force.play_sound { path = "utility/game_won" }
    end
  end
  return changed
end

local function track_locations(force)
  local fs = force_state(force)
  for _, player in pairs(force.connected_players) do
    local surface = player.physical_surface
    if surface and surface.planet then fs.visited[surface.planet.name] = true end
  end
  for _, platform in pairs(force.platforms) do
    if platform.valid then
      local location = platform.space_location or platform.last_visited_space_location
      if location then fs.reached[location.name] = true end
    end
  end
end

local function tick()
  for _, force in pairs(game.forces) do
    if #force.connected_players > 0 then
      track_locations(force)
      if check_force(force) then
        refresh_force(force)
      else
        for _, player in pairs(force.connected_players) do
          update_tracker(player)
          update_window_progress(player)
        end
      end
    end
  end
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

local function init_storage()
  storage.forces = storage.forces or {}
  storage.players = storage.players or {}
  refresh_validity()
end

local function init_player(player)
  player_state(player)
  ensure_button(player)
  update_tracker(player)
end

script.on_init(function()
  init_storage()
  for _, force in pairs(game.forces) do announce_unlocks(force, force_state(force), true) end
  for _, player in pairs(game.players) do init_player(player) end
end)

script.on_configuration_changed(function()
  init_storage()
  for _, player in pairs(game.players) do
    close_window(player)
    init_player(player)
  end
end)

script.on_event(defines.events.on_player_created, function(e)
  local player = game.get_player(e.player_index)
  init_player(player)
  player.print({ "quest-book.welcome" }, { color = { 1, 0.85, 0.5 } })
end)

script.on_event(defines.events.on_player_changed_force, function(e)
  refresh_player(game.get_player(e.player_index))
end)

script.on_event(defines.events.on_player_changed_surface, function(e)
  local player = game.get_player(e.player_index)
  local surface = player.physical_surface
  if surface and surface.planet then
    force_state(player.force).visited[surface.planet.name] = true
  end
end)

script.on_event(defines.events.on_research_finished, function(e)
  local force = e.research.force
  if check_force(force) then refresh_force(force) end
end)

script.on_nth_tick(CHECK_INTERVAL, tick)

script.on_event("qb-toggle", function(e)
  toggle_window(game.get_player(e.player_index))
end)

script.on_event(defines.events.on_lua_shortcut, function(e)
  if e.prototype_name == "qb-toggle" then toggle_window(game.get_player(e.player_index)) end
end)

script.on_event(defines.events.on_gui_closed, function(e)
  if e.element and e.element.valid and e.element.name == WINDOW then close_window(game.get_player(e.player_index)) end
end)

local function claim(player, quest)
  local ps = player_state(player)
  local fs = force_state(player.force)
  if ps.claimed[quest.id] or not fs.completed[quest.id] then return end
  ps.claimed[quest.id] = true
  for _, reward in ipairs(quest.rewards) do
    local inserted = player.insert { name = reward.name, count = reward.count }
    local rest = reward.count - inserted
    if rest > 0 and player.physical_surface then
      player.physical_surface.spill_item_stack {
        position = player.physical_position, stack = { name = reward.name, count = rest },
        enable_looted = true, allow_belts = false,
      }
    end
  end
  player.play_sound { path = "utility/new_objective" }
end

script.on_event(defines.events.on_gui_click, function(e)
  local element = e.element
  if not (element and element.valid) then return end
  local action = element.tags and element.tags.qb_action
  if not action then return end
  local player = game.get_player(e.player_index)

  if action == "toggle" then
    toggle_window(player)
  elseif action == "close" then
    close_window(player)
  elseif action == "select" then
    player_state(player).selected = element.tags.quest
    build_window(player)
  elseif action == "help" then
    local quest = quest_by_id[element.tags.quest]
    local obj = quest and quest.objectives[element.tags.objective]
    if obj then open_objective_help(player, obj) end
  elseif action == "claim" then
    claim(player, quest_by_id[element.tags.quest])
    build_window(player)
  end
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(e)
  local element = e.element
  if element.valid and element.tags and element.tags.qb_action == "tracker" then
    local player = game.get_player(e.player_index)
    player_state(player).tracker = element.state
    update_tracker(player)
  end
end)

---------------------------------------------------------------------------
-- Admin commands (testing)
---------------------------------------------------------------------------

commands.add_command("qb-complete", { "quest-book.cmd-complete" }, function(cmd)
  local player = cmd.player_index and game.get_player(cmd.player_index)
  if player and not player.admin then return end
  local force = player and player.force or game.forces.player
  local fs = force_state(force)
  local quest = quest_by_id[cmd.parameter or ""]
  local targets = quest and { quest } or active_quests(fs)
  for _, q in ipairs(targets) do
    if not fs.completed[q.id] then complete_quest(force, fs, q) end
  end
  announce_unlocks(force, fs, false)
  refresh_force(force)
end)

commands.add_command("qb-reset", { "quest-book.cmd-reset" }, function(cmd)
  local player = cmd.player_index and game.get_player(cmd.player_index)
  if player and not player.admin then return end
  local force = player and player.force or game.forces.player
  storage.forces[force.index] = nil
  for _, p in pairs(force.players) do
    if storage.players[p.index] then storage.players[p.index].claimed = {} end
  end
  announce_unlocks(force, force_state(force), true)
  refresh_force(force)
end)

---------------------------------------------------------------------------
-- Remote interface (other mods, scenarios, tests)
---------------------------------------------------------------------------

remote.add_interface("quest-book", {
  -- Returns { [quest id] = "done" | "active" | "locked" | "skipped" }
  get_status = function(force_name)
    local fs = force_state(game.forces[force_name or "player"])
    local result = {}
    for _, quest in ipairs(defs.quests) do result[quest.id] = quest_status(fs, quest) end
    return result
  end,
  -- Runs a progress check immediately, returns true if any quest was completed.
  check = function(force_name)
    local force = game.forces[force_name or "player"]
    track_locations(force)
    return check_force(force)
  end,
})
