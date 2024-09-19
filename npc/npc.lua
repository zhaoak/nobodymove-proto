-- Module for NPCs, friendly, neutral, and hostile alike.
-- Contains functions for creating, drawing, and running AI updates, plus any moving and shooting an NPC needs to do.
-- Also contains accessors for NPCs' world coordinates, velocity, and so on.

local util = require("util")
local filterValues = require("filterValues")
local dmgText = require'ui.damageNumbers'

-- defining a class metatable for all NPCs
local npcClass = { }

-- assorted defines {{{
npcClass.hitflashDuration = 0.1
-- }}}

-- if instances can't find the method in their own table, check the NPC class metatable
npcClass.__index = npcClass

-- the megalist of every NPC currently existing in the world, keyed by UID
npcClass.npcList = {}

-- If you don't know what I'm doing here, I'm creating a new class in Lua.
-- Lua doesn't have builtin class functionality, so I'm using metamethods to implement it.
-- See here for details: http://lua-users.org/wiki/ObjectOrientationTutorial
setmetatable(npcClass, {
  __call = function(cls, ...)
    local self = setmetatable({}, cls)
    self:constructor(...)
    return self
  end,
})

-- Create a new NPC instance, give it a UID, and add it to the list of NPCs in the world. Returns the new npc's UID.
-- This constructor is also called by the enemy and friendly constructors, since they are extended from the npc class.
-- Arguments:
-- initialXPos, initialYPos (numbers, required): initial X and Y positions of the NPC in the world.
-- physicsData(table): all data needed to initialize the npc in the world using Box2D.
-- Table format:
-- { 
--    body (table): table containing all data for setting Box2D body properties of npc. See https://www.love2d.org/wiki/Body
--    Table format:
--    {
--      angularDamping (number, default=0): angular damping value
--      fixedRotation (bool, default=false): whether the body should ever rotate or not
--      gravityScale (number, default=1): how much the body should be affected by gravity
--      inertia (number, default=generated by Box2D): the body's inertia
--      linearDamping (number, default=0): linear damping value
--      mass (number, default=generated from shape data by Box2D): how thicc the npc is
--    },
--    shape (table): table containing all data for setting Box2D shape properties of npc. See https://www.love2d.org/wiki/Shape
--    Table format:
--    {
--      shapeType (string, default="circle"): must be one of "circle", "polygon", "rectangle". What type of hitbox the enemy should have.
--      ADDITIONAL REQUIRED KEYS/VALUES FOR shapeType="circle":
--        radius (number, default=20): radius of circle hitbox of npc
--      ADDITIONAL REQUIRED KEYS/VALUES FOR shapeType="polygon":
--        a table `points` containing: {x1, y1, x2, y2, x3...} and so on: the points of the polygon shape. max 8 vertices, must form a convex shape.
--      ADDITIONAL REQUIRED KEYS/VALUES FOR shapeType="rectangle:
--        width, height: width and height of rectangle shape
--    },
--    fixture (table): table containing all data for setting Box2D fixture properties of npc. See https://www.love2d.org/wiki/Shape
--    Table format:
--    {
--      density (number, default=1): the fixture's density in kg/square meter
--      friction (number 0.0-1.0, default=~0.2 apparently, 1=max friction, 0=min friction): how much friction the npc generates when bumping and grinding
--      restitution (number, default=0): multiplier for bounciness, so 0=lose all velocity on collision, 1=retain all velocity, >1=GAIN velocity on collision
--    }
-- }
-- userDataTable (table): table containing userdata to set for npc.
-- Table format:
-- {
--    name (string, required): name property to set in userdata
--    team (string, required): who the npc is allied to, relative to the player. Must be one of: "friendly", "enemy", "neutral"
--    health (number, required): how much health to give this npc
-- }
-- spriteData (table): sprite data. we don't have art yet so i'll get back to this
-- aiCycleFunc(func): function for update call to run, 
-- guns(table of gun ids): table of gun IDs wielded by this NPC
function npcClass:constructor(initialXPos, initialYPos, physicsData, userDataTable, spriteData, aiCycleFunc, guns) -- {{{
  -- set default values
  physicsData = physicsData or {
    body={angularDamping=0,fixedRotation=false,gravityScale=1,linearDamping=0},
    shape={shapeType="circle",radius=20},
    fixture={restitution=0,density=1}
  }
  userDataTable = userDataTable or {
    {name="someone forgot to name me",team="enemy",health=100, aiCycleInterval = 1}
  }

  -- create physics objects for new npc
  self.body = love.physics.newBody(util.world, initialXPos, initialYPos, "dynamic")
  if physicsData.shape.shapeType == "circle" then
    self.shape = love.physics.newCircleShape(physicsData.shape.radius)
  elseif physicsData.shape.shapeType == "polygon" then
    self.shape = love.physics.newPolygonShape(unpack(physicsData.shape.points))
  elseif physicsData.shape.shapeType == "rectangle" then
    self.shape = love.physics.newRectangleShape(physicsData.shape.width, physicsData.shape.height)
  end
  self.fixture = love.physics.newFixture(self.body, self.shape, physicsData.fixture.density)

  if physicsData.body.angularDamping ~= nil then self.body:setAngularDamping(physicsData.body.angularDamping) end
  if physicsData.body.fixedRotation ~= nil then self.body:setFixedRotation(physicsData.body.fixedRotation) end
  if physicsData.body.gravityScale ~= nil then self.body:setGravityScale(physicsData.body.gravityScale) end
  if physicsData.body.inertia ~= nil then self.body:setInertia(physicsData.body.inertia) end
  if physicsData.body.linearDamping ~= nil then self.body:setLinearDamping(physicsData.body.linearDamping) end
  if physicsData.body.mass ~= nil then self.body:setMass(physicsData.body.mass) end
  if physicsData.fixture.density ~= nil then self.fixture:setDensity(physicsData.fixture.density) end
  if physicsData.fixture.restitution ~= nil then self.fixture:setRestitution(physicsData.fixture.restitution) end
  if physicsData.fixture.friction ~= nil then self.fixture:setFriction(physicsData.fixture.friction) end

  -- set collision filter data
  if userDataTable.team == "enemy" then
    self.fixture:setCategory(filterValues.category.enemy)
    self.fixture:setMask(filterValues.category.enemy, filterValues.category.projectile_enemy, filterValues.category.terrain_bg)
    self.fixture:setGroupIndex(0)
  elseif userDataTable.team == "friendly" then
    self.fixture:setCategory(filterValues.category.friendly)
    self.fixture:setMask(filterValues.category.friendly, filterValues.category.projectile_player, filterValues.category.terrain_bg)
    self.fixture:setGroupIndex(0)
  elseif userDataTable.team == "neutral" then
    self.fixture:setCategory(filterValues.category.neutral)
    self.fixture:setMask(filterValues.category.terrain_bg)
    self.fixture:setGroupIndex(0)
  end

  -- set knockback values to zero
  self.thisTickTotalKnockbackX = 0
  self.thisTickTotalKnockbackY = 0

  -- queue for impulses at specific coords to apply in update step
  self.thisTickImpulseAtLocationQueue = {}

  -- generate and assign a UID and userdata, then add npc to npc list
  self.uid = util.gen_uid("npc")
  self.fixture:setUserData{
    name = userDataTable.name,
    type = "npc",
    team = userDataTable.team,
    health = userDataTable.health,
    uid = self.uid,
    lifetime = 0,
    lastAICycle = 0,
    aiCycleInterval = userDataTable.aiCycleInterval,
    aiCycleFunc = aiCycleFunc
  }
  npcClass.npcList[self.uid] = self

  -- add gun ids to gun table on instance
  self.guns = {}

end -- }}}

-- NPC apply-knockback methods {{{
-- calculate knockback from NPC shooting they gun
-- converts an amount of force and angle into a velocity vector
function npcClass:calculateShotKnockback(gunKnockback, gunAimAngle)
  -- calculate and return knockback on X and Y axes
  local knockbackX = -math.sin(gunAimAngle)*gunKnockback
  local knockbackY = -math.cos(gunAimAngle)*gunKnockback
  return knockbackX, knockbackY
end

-- apply knockback to NPC's center of mass
-- used for handling knockback from shooting guns
-- summed knockback is applied in update step
function npcClass:addToThisTickKnockback(knockbackX, knockbackY)
  self.thisTickTotalKnockbackX = self.thisTickTotalKnockbackX + knockbackX
  self.thisTickTotalKnockbackY = self.thisTickTotalKnockbackY + knockbackY
end

-- apply an impulse to an NPC at a specific position on its shape
-- used for handling knockback from projectiles hitting specific parts of hitbox
-- impulse is applied in npc update step
-- posX and posY should be in world coordinates, not local
function npcClass:addToThisTickKnockbackAtWorldPosition(knockbackX, knockbackY, posX, posY)
  table.insert(self.thisTickImpulseAtLocationQueue, {
    knockbackX=knockbackX,knockbackY=knockbackY,posX=posX,posY=posY})
end
-- }}}

-- npc utility methods {{{
-- Get a specific NPC's X and Y location in the world
function npcClass:getX()
  return self.body:getX()
end

function npcClass:getY()
  return self.body:getY()
end

-- damages an NPC's health by damageAmount and triggers their pain animation. Also triggers damage text display.
-- Can accept negative values to heal, but will still trigger pain animation.
function npcClass:hurt(damageAmount)
  local newUserData = self.fixture:getUserData()
  dmgText.damageNumberEvent(damageAmount, newUserData.uid)
  newUserData.health = newUserData.health - damageAmount
  self.fixture:setUserData(newUserData)
  -- print(self.fixture:getUserData().health)
  -- also trigger pain animation (we odn't have those yet)
end

-- }}}

-- npc update methods {{{
function npcClass:update(dt, world, player, npcList)
  -- apply center-of-mass knockback values for this update
  self.body:applyLinearImpulse(self.thisTickTotalKnockbackX, self.thisTickTotalKnockbackY)
  -- reset center-of-mass knockback values for next tick 
  self.thisTickTotalKnockbackX = 0
  self.thisTickTotalKnockbackY = 0

  -- apply at-specific-position impulses to NPC this update
  for _, impulse in pairs(self.thisTickImpulseAtLocationQueue) do
    self.body:applyLinearImpulse(impulse.knockbackX, impulse.knockbackY, impulse.posX, impulse.posY)
  end
  -- empty the queue once everything is applied
  self.thisTickImpulseAtLocationQueue = {}

  local selfUserData = self.fixture:getUserData()
  -- update lifetime timer
  selfUserData.lifetime = selfUserData.lifetime+dt

  -- run own AI function, if enough time has passed since last cycle
  if selfUserData.lifetime > (selfUserData.lastAICycle+selfUserData.aiCycleInterval) then
    selfUserData.aiCycleFunc(self, world, player, npcList)
    -- update last ai cycle value
    selfUserData.lastAICycle = selfUserData.lifetime
  end

  -- write updated userdata
  self.fixture:setUserData(selfUserData)
end

npcClass.updateAllNpcs = function (dt, world, player, npcList)
  for _, npc in pairs(npcClass.npcList) do
    npc:update(dt, world, player, npcList)
  end
end
-- }}}

-- NPC draw methods {{{
-- Draw a specific NPC, instance method
function npcClass:draw()
  love.graphics.setColor(0.8, 0.4, 0.4, 1)
  love.graphics.polygon("fill", self.body:getWorldPoints(self.shape:getPoints()))
end

-- Draw all NPCs, static class method
function npcClass.drawAllNpcs()
  for _, npc in pairs(npcClass.npcList) do
    npc:draw()
  end
end
-- }}}

return npcClass
-- vim: foldmethod=marker
