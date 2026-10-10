data:extend {
  {
    type = "int-setting", name = "qb-tracker-limit", setting_type = "runtime-per-user",
    default_value = 3, minimum_value = 1, maximum_value = 10, order = "a",
  },
  {
    type = "bool-setting", name = "qb-chat-messages", setting_type = "runtime-per-user",
    default_value = true, order = "b",
  },
  {
    type = "bool-setting", name = "qb-rewards", setting_type = "runtime-global",
    default_value = true, order = "a",
  },
}
