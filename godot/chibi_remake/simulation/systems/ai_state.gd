extends RefCounted
## AI counters, plans and training slots.
const Settings = preload("res://simulation/systems/ai_config.gd")
const THINK_PERIOD = Settings.THINK_PERIOD
const BUILD_PLAN_PERIOD = Settings.BUILD_PLAN_PERIOD
const BUILD_STATE_PERIOD = Settings.BUILD_STATE_PERIOD
const INTERCEPT_PERIOD = Settings.INTERCEPT_PERIOD
const ASSAULT_PERIOD = Settings.ASSAULT_PERIOD
const ASSAULT_PERIOD_URGENT = Settings.ASSAULT_PERIOD_URGENT
const AI_MONEY = Settings.AI_MONEY
const GIFT_WOOD = Settings.GIFT_WOOD
const GIFT_FOOD = Settings.GIFT_FOOD
const GIFT_STONE = Settings.GIFT_STONE
const HUMAN_GOLD_FOR_ASSAULT = Settings.HUMAN_GOLD_FOR_ASSAULT
const ARMY_BY_TIER = Settings.ARMY_BY_TIER
const HUMAN_WEAK_UNITS = Settings.HUMAN_WEAK_UNITS
const INTERCEPT_RADIUS = Settings.INTERCEPT_RADIUS
const Access = Settings.Access
const PLAN_TO_BUILDING = Settings.PLAN_TO_BUILDING
const PLAN_PAIR = Settings.PLAN_PAIR
const BUILD_PRIORITY_KINDS = Settings.BUILD_PRIORITY_KINDS

var host: Access

var _think := {}                  # owner -> 计数

var _plan := {}                   # owner -> 计数

var _build_clock := {}            # owner -> 11 帧施工状态机计数

var _assault := {}                # owner -> 计数

var _assault_period := {}          # owner -> 70/6（发现玩家<6后不再恢复）

var _intercept := {}              # owner -> 计数

var _research_cursor := {}         # 各势力研究系轮转，存档后不重置顺序。

var _retreat := {}                 # owner -> 1：群撤退中

var plan := {}                     # owner -> 当前建造计划项（0 = 无）

var slots: RefCounted

var naval: RefCounted
