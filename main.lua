-- nobody move prototype

-- utilities
local util = require'util'


-- filewide vars
local obj = {} -- all physics objects
local phys = {} -- physics handlers
local world -- the physics world
local nextFrameActions = {} -- uhhh ignore for now pls

-- import physics objects
obj.playfield = require("playfield")
obj.player = require("player")
obj.projectiles = require("projectiles")
local gunlib = require'guns'

function love.load() -- {{{ init
  love.graphics.setBackgroundColor(.4,.4,.4)
  love.window.setMode(1000,1000)
  love.window.setVSync(true)

  love.physics.setMeter(64)

  -- create the physics world
  world = love.physics.newWorld(0,10*64, false)
  world:setCallbacks( beginContact, endContact, preSolve, postSolve )

  obj.playfield.setup(world)
  obj.player.setup(world)
  obj.projectiles.setup(world)

end -- }}}

function love.update(dt) -- {{{
  -- reset spood on rightclick
  if love.mouse.isDown(2) then
    obj.player.setup(world)
  end

  gunlib.update(dt)
  obj.player.update(dt)
  obj.projectiles.update(dt)

  world:update(dt)
end -- }}}

function love.draw() -- {{{
  obj.playfield.draw()
  obj.player.draw()

  -- draw existing bullets and other projectiles
  obj.projectiles.draw()

  -- draw effects (explosions, impacts, etc)
end  -- }}}


-- catch resize
love.resize = function (width,height)
  obj.playfield.resize(width,height)
end

-- physics collision callbacks {{{

function beginContact(a, b, contact) -- {{{
  local fixtureAUserData = a:getUserData()
  local fixtureBUserData = b:getUserData()

  -- if terrain comes in range of spooder's reach...
  if (fixtureAUserData.name == "reach" and fixtureBUserData.type == "terrain") or (fixtureBUserData.name == "reach" and fixtureAUserData.type == "terrain") then
    -- ...then add the terrain to the cache of terrain items in latching range
    obj.player.handleTerrainEnteringRange(a, b, contact)
  end

  -- projectile impact handling
  if fixtureAUserData.type == "projectile" or fixtureBUserData.type == "projectile" then
    obj.projectiles.handleProjectileCollision(a, b, contact)
  end
end -- }}}

function endContact(a, b, contact) -- {{{
  local fixtureAUserData = a:getUserData()
  local fixtureBUserData = b:getUserData()

  -- when terrain leaves range of spooder's reach...
  if (fixtureAUserData.name == "reach" and fixtureBUserData.type == "terrain") or (fixtureBUserData.name == "reach" and fixtureAUserData.type == "terrain") then
    -- ...remove the terrain from the cache of terrain items in latching range
    obj.player.handleTerrainLeavingRange(a, b, contact)
  end
end -- }}}

function preSolve(a, b, contact) -- {{{
  -- Since 'sensors' senselessly sense solely shapes sharing space, shan't share specifics, shove sensors.
  -- Silly sensors, surely sharing shouldn't stress software simulation?
  -- So, set shapes: "sure, sharing space shouldn't shove shapes", so seeing spots shapes share shall succeed shortly.

  -- ...

  -- um. i meant. fixtures set to be sensors only track the fact that they're colliding, not anything about it
  -- so instead of making e.g. the player's reach box a sensor, just cancel the contact from doing anything with physics every time it gets created
  -- then in code when we grab the contact we can use methods like getPositions
  if a:getUserData().semisensor or b:getUserData().semisensor then
    contact:setEnabled(false)
  end
end -- }}}

function postSolve(a, b, contact, normalimpulse, tangentimpulse) -- {{{
end -- }}}

-- }}}


-- vim: foldmethod=marker
