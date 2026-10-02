data:extend({
  {
    type = "custom-input",
    name = "qb-toggle",
    key_sequence = "SHIFT + J",
    consuming = "none",
    action = "lua",
  },
  {
    type = "shortcut",
    name = "qb-toggle",
    order = "z[quest-book]",
    action = "lua",
    associated_control_input = "qb-toggle",
    icon = "__quest-book__/graphics/book-x56.png",
    icon_size = 56,
    small_icon = "__quest-book__/graphics/book-x24.png",
    small_icon_size = 24,
  },
  {
    type = "sprite",
    name = "qb_book",
    filename = "__quest-book__/graphics/book-64.png",
    size = 64,
    flags = { "gui-icon" },
  },
})

local styles = data.raw["gui-style"].default

styles.qb_quest_button = {
  type = "button_style",
  parent = "list_box_item",
  horizontally_stretchable = "on",
  minimal_height = 28,
}

styles.qb_quest_button_selected = {
  type = "button_style",
  parent = "qb_quest_button",
  default_font_color = { 0, 0, 0 },
  hovered_font_color = { 0, 0, 0 },
  default_graphical_set = { position = { 225, 17 }, corner_size = 8 },
  hovered_graphical_set = { position = { 225, 17 }, corner_size = 8 },
}
