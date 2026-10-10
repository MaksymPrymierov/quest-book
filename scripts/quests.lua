-- Story quest definitions.
--
-- Texts live in locale/*/quest-book.cfg:
--   [quest-book-chapter] <chapter id>
--   [quest-book-title]   <quest id>
--   [quest-book-story]   <quest id>
--
-- Objective types:
--   produce  {item=, count=} or {fluid=, count=}  total produced by the force (all surfaces)
--   research {tech=}
--   build    {entity=, count=}                    entities currently owned by the force
--            {entity=, kind=, count=}             any entity of prototype type `kind` counts (higher tiers,
--                                                 modded replacements); `entity` only provides the icon and
--                                                 help page. `types = {...}` overrides the prototype types;
--                                                 the name shown is [quest-book-kind] <kind> in the locale.
--   rocket   {count=}                             rockets launched by the force
--   visit    {planet=}                            a player of the force stood on the planet
--   reach    {location=}                          a platform of the force reached the space location
--
-- Completed objectives stay completed. If an objective, reward or prerequisite
-- refers to a prototype that does not exist (e.g. Space Age is disabled), the
-- whole quest is skipped and treated as completed for its dependants.
--
-- `requires` defaults to the previous quest in the list.

local chapters = {
  { id = "landing",  icon = "item/burner-mining-drill" },
  { id = "automation", icon = "item/assembling-machine-1" },
  { id = "defense",  icon = "item/gun-turret" },
  { id = "oil",      icon = "fluid/crude-oil" },
  { id = "networks", icon = "item/roboport" },
  { id = "science",  icon = "item/utility-science-pack" },
  { id = "stars",    icon = "item/rocket-silo" },
  { id = "orbit",    icon = "item/space-platform-hub" },
  { id = "vulcanus", icon = "space-location/vulcanus" },
  { id = "fulgora",  icon = "space-location/fulgora" },
  { id = "gleba",    icon = "space-location/gleba" },
  { id = "aquilo",   icon = "space-location/aquilo" },
  { id = "edge",     icon = "space-location/solar-system-edge" },
}

local quests = {
  -- Chapter 1: crash landing
  { id = "wake", chapter = "landing", requires = {},
    objectives = {
      { type = "produce", item = "iron-plate", count = 50 },
      { type = "produce", item = "copper-plate", count = 20 },
    } },
  { id = "drills", chapter = "landing",
    objectives = {
      { type = "build", entity = "burner-mining-drill", kind = "mining-drill", count = 6 },
      { type = "build", entity = "stone-furnace", kind = "furnace", count = 6 },
    },
    rewards = { { name = "wood", count = 50 } } },
  { id = "power", chapter = "landing",
    objectives = {
      { type = "build", entity = "offshore-pump", kind = "offshore-pump", count = 1 },
      { type = "build", entity = "boiler", kind = "boiler", count = 1 },
      { type = "build", entity = "steam-engine", kind = "generator", count = 2 },
    },
    rewards = { { name = "small-electric-pole", count = 20 } } },
  { id = "lab", chapter = "landing",
    objectives = {
      { type = "build", entity = "lab", kind = "lab", count = 1 },
      { type = "research", tech = "automation" },
    } },

  -- Chapter 2: automation
  { id = "red-science", chapter = "automation",
    objectives = {
      { type = "build", entity = "assembling-machine-1", kind = "assembling-machine", count = 5 },
      { type = "produce", item = "automation-science-pack", count = 100 },
    },
    rewards = { { name = "assembling-machine-1", count = 5 } } },
  { id = "belts", chapter = "automation",
    objectives = {
      { type = "research", tech = "logistics" },
      { type = "build", entity = "electric-mining-drill", kind = "mining-drill", count = 10 },
      { type = "produce", item = "transport-belt", count = 300 },
    },
    rewards = { { name = "inserter", count = 20 } } },
  { id = "green-science", chapter = "automation",
    objectives = {
      { type = "research", tech = "logistic-science-pack" },
      { type = "produce", item = "logistic-science-pack", count = 200 },
    },
    rewards = { { name = "assembling-machine-2", count = 4 } } },

  -- Chapter 3: defense (runs in parallel with automation)
  { id = "turrets", chapter = "defense", requires = { "red-science" },
    objectives = {
      { type = "research", tech = "gun-turret" },
      { type = "build", entity = "gun-turret", kind = "turret", types = { "ammo-turret", "electric-turret", "fluid-turret" }, count = 6 },
      { type = "produce", item = "firearm-magazine", count = 200 },
    },
    rewards = { { name = "firearm-magazine", count = 100 } } },
  { id = "walls", chapter = "defense",
    objectives = {
      { type = "research", tech = "stone-wall" },
      { type = "build", entity = "stone-wall", kind = "wall", count = 100 },
      { type = "research", tech = "military-2" },
    },
    rewards = { { name = "piercing-rounds-magazine", count = 100 } } },

  -- Chapter 4: black gold
  { id = "oil", chapter = "oil", requires = { "green-science" },
    objectives = {
      { type = "research", tech = "oil-processing" },
      { type = "build", entity = "pumpjack", count = 4 },
      { type = "build", entity = "oil-refinery", count = 1 },
      { type = "produce", fluid = "petroleum-gas", count = 10000 },
    } },
  { id = "plastic", chapter = "oil",
    objectives = {
      { type = "produce", item = "plastic-bar", count = 200 },
      { type = "produce", item = "advanced-circuit", count = 100 },
    } },
  { id = "military-science", chapter = "oil", requires = { "walls", "plastic" },
    objectives = {
      { type = "research", tech = "military-science-pack" },
      { type = "produce", item = "military-science-pack", count = 100 },
    },
    rewards = { { name = "grenade", count = 20 } } },
  { id = "blue-science", chapter = "oil", requires = { "plastic" },
    objectives = {
      { type = "research", tech = "chemical-science-pack" },
      { type = "produce", item = "chemical-science-pack", count = 200 },
    } },

  -- Chapter 5: grand networks
  { id = "rails", chapter = "networks", requires = { "green-science" },
    objectives = {
      { type = "research", tech = "railway" },
      { type = "build", entity = "locomotive", count = 1 },
      { type = "build", entity = "train-stop", count = 2 },
    },
    rewards = { { name = "rail", count = 100 } } },
  { id = "solar", chapter = "networks", requires = { "blue-science" },
    objectives = {
      { type = "research", tech = "solar-energy" },
      { type = "build", entity = "solar-panel", kind = "solar-panel", count = 50 },
      { type = "build", entity = "accumulator", kind = "accumulator", count = 30 },
    } },
  { id = "robots", chapter = "networks", requires = { "blue-science" },
    objectives = {
      { type = "research", tech = "construction-robotics" },
      { type = "build", entity = "roboport", count = 1 },
      { type = "produce", item = "construction-robot", count = 20 },
      { type = "research", tech = "logistic-robotics" },
    },
    rewards = { { name = "construction-robot", count = 10 } } },

  -- Chapter 6: the last sciences
  { id = "purple-science", chapter = "science", requires = { "blue-science", "rails" },
    objectives = {
      { type = "research", tech = "production-science-pack" },
      { type = "produce", item = "production-science-pack", count = 200 },
    } },
  { id = "yellow-science", chapter = "science", requires = { "blue-science", "robots" },
    objectives = {
      { type = "research", tech = "utility-science-pack" },
      { type = "produce", item = "utility-science-pack", count = 200 },
    } },
  { id = "modules", chapter = "science", requires = { "purple-science" },
    objectives = {
      { type = "research", tech = "productivity-module" },
      { type = "produce", item = "productivity-module", count = 20 },
      { type = "build", entity = "beacon", count = 4 },
    },
    rewards = { { name = "speed-module", count = 4 } } },
  { id = "nuclear", chapter = "science", requires = { "blue-science", "solar" },
    objectives = {
      { type = "research", tech = "nuclear-power" },
      { type = "produce", item = "uranium-235", count = 10 },
      { type = "build", entity = "nuclear-reactor", count = 1 },
    } },

  -- Chapter 7: to the stars
  { id = "silo", chapter = "stars", requires = { "purple-science", "yellow-science" },
    objectives = {
      { type = "research", tech = "rocket-silo" },
      { type = "build", entity = "rocket-silo", count = 1 },
      { type = "produce", item = "rocket-part", count = 50 },
    } },
  { id = "launch", chapter = "stars",
    objectives = {
      { type = "rocket", count = 1 },
    } },
  { id = "space-science", chapter = "stars",
    objectives = {
      { type = "produce", item = "space-science-pack", count = 1000 },
    } },

  -- Space Age. Chapter 8: orbit
  { id = "platform", chapter = "orbit", requires = { "launch" },
    objectives = {
      { type = "research", tech = "space-platform" },
      { type = "build", entity = "space-platform-hub", count = 1 },
      { type = "build", entity = "asteroid-collector", count = 2 },
      { type = "build", entity = "crusher", count = 2 },
    } },
  { id = "thrusters", chapter = "orbit",
    objectives = {
      { type = "research", tech = "space-platform-thruster" },
      { type = "build", entity = "thruster", count = 2 },
      { type = "research", tech = "planet-discovery-vulcanus" },
    } },

  -- Chapter 9: Vulcanus
  { id = "vulcanus-landing", chapter = "vulcanus", requires = { "thrusters" },
    objectives = {
      { type = "visit", planet = "vulcanus" },
      { type = "research", tech = "foundry" },
      { type = "build", entity = "foundry", count = 1 },
    } },
  { id = "vulcanus-science", chapter = "vulcanus",
    objectives = {
      { type = "build", entity = "big-mining-drill", count = 2 },
      { type = "produce", item = "tungsten-plate", count = 200 },
      { type = "produce", item = "metallurgic-science-pack", count = 500 },
    } },

  -- Chapter 10: Fulgora
  { id = "fulgora-landing", chapter = "fulgora", requires = { "thrusters" },
    objectives = {
      { type = "research", tech = "planet-discovery-fulgora" },
      { type = "visit", planet = "fulgora" },
      { type = "build", entity = "recycler", count = 4 },
      { type = "build", entity = "lightning-rod", count = 4 },
    } },
  { id = "fulgora-science", chapter = "fulgora",
    objectives = {
      { type = "build", entity = "electromagnetic-plant", count = 1 },
      { type = "produce", item = "holmium-plate", count = 200 },
      { type = "produce", item = "electromagnetic-science-pack", count = 500 },
    } },

  -- Chapter 11: Gleba
  { id = "gleba-landing", chapter = "gleba", requires = { "thrusters" },
    objectives = {
      { type = "research", tech = "planet-discovery-gleba" },
      { type = "visit", planet = "gleba" },
      { type = "build", entity = "agricultural-tower", count = 4 },
      { type = "build", entity = "biochamber", count = 2 },
    } },
  { id = "gleba-science", chapter = "gleba",
    objectives = {
      { type = "produce", item = "bioflux", count = 200 },
      { type = "produce", item = "agricultural-science-pack", count = 500 },
    } },

  -- Chapter 12: Aquilo
  { id = "aquilo-landing", chapter = "aquilo",
    requires = { "vulcanus-science", "fulgora-science", "gleba-science" },
    objectives = {
      { type = "research", tech = "planet-discovery-aquilo" },
      { type = "visit", planet = "aquilo" },
      { type = "build", entity = "heating-tower", count = 1 },
    } },
  { id = "aquilo-science", chapter = "aquilo",
    objectives = {
      { type = "build", entity = "cryogenic-plant", count = 1 },
      { type = "produce", item = "lithium-plate", count = 200 },
      { type = "produce", item = "cryogenic-science-pack", count = 500 },
    } },
  { id = "fusion", chapter = "aquilo",
    objectives = {
      { type = "research", tech = "fusion-reactor" },
      { type = "build", entity = "fusion-reactor", count = 1 },
      { type = "build", entity = "fusion-generator", count = 2 },
    } },

  -- Chapter 13: the edge of the system
  { id = "railgun", chapter = "edge", requires = { "aquilo-science" },
    objectives = {
      { type = "research", tech = "railgun" },
      { type = "build", entity = "railgun-turret", count = 2 },
    } },
  { id = "edge", chapter = "edge",
    objectives = {
      { type = "reach", location = "solar-system-edge" },
    } },
  { id = "shattered", chapter = "edge",
    objectives = {
      { type = "research", tech = "promethium-science-pack" },
      { type = "produce", item = "promethium-science-pack", count = 1000 },
      { type = "reach", location = "shattered-planet" },
    } },
}

return { chapters = chapters, quests = quests }
