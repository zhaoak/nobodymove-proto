-- Gun objects.
local M = { }

M.gunlist = {} -- data for every gun existing in world, held by player or enemy, lives here

local projectileLib = require'projectiles'
local util = require'util'

-- utility function for creating the projectiles fired from guns
local function createProjectiles (gun, x, y, worldRelativeAimAngle)
  if gun.type == "hitscan" then
    -- cast a ray etc
  end

  if gun.type == "bullet" then
    projectileLib.createBulletShot(gun, x, y, worldRelativeAimAngle)
  end
end

-- The shoot function for shooting a specific gun, which is passed in via arg.
-- This function handles creating the projectiles from the gun and resetting its cooldown,
-- as well as returning the knockback force, so whoever shot the gun can apply it to themself.
-- The code calling this function should fetch the gun they want to shoot from the gun masterlist via ID,
-- then pass that gun in as an argument.
-- args:
-- gun (gun object): the gun to shoot
-- x, y (numbers): world coordinates to spawn the projectiles at
-- worldRelativeAimAngle: angle gun is aiming at/being aimed at, the player/item/enemy calling this func should have this value available
-- resetCooldown(bool): whether or not to reset the gun's cooldown timer; some shots triggered by events are 'bonus' shots and don't reset cooldown
local function shoot (gun, x, y, worldRelativeAimAngle, resetCooldown) -- {{{
  if resetCooldown then gun.current.cooldown = gun.cooldown end
  -- store the state of the shot, so mods can modify it as they go
  -- adding more chaos each time, hopefully
  local shot = {holderKnockback=gun.holderKnockback, damage=gun.hitDamage} -- stuff like spread, pellets, speed, etc everything idk yet

  -- for _, mod in ipairs(gun.mods) do
  --   shot = mod:apply(shot)
  -- end

  createProjectiles(gun, x, y, worldRelativeAimAngle)

  -- apply recoil penalty to gun's aim
  -- randomly select either -1 or +1, to randomly select if recoil will apply clockwise or counterclockwise
  local randTable = { [1] = -1, [2] = 1 }
  local rand = math.random(2)
  local recoilAimPenalty = gun.recoil * randTable[rand]
  -- then apply the penalty
  gun.current.recoilAimPenaltyOffset = gun.current.recoilAimPenaltyOffset + recoilAimPenalty

  return shot.holderKnockback
end -- }}}


local function draw (gunId, player) -- {{{
  -- print("drawing gun w/id "..gunId)
  local gun = M.gunlist[gunId]
  local adjustedAimAngle = player.currentAimAngle + gun.current.recoilAimPenaltyOffset

  local spriteLocationOffsetX = math.sin(adjustedAimAngle) * (gun.playerHoldDistance + player.hardboxRadius)
  local spriteLocationOffsetY = math.cos(adjustedAimAngle) * (gun.playerHoldDistance + player.hardboxRadius)
  -- if the player is aiming left, flip the gun sprite
  local flipGunSprite = 1
  if adjustedAimAngle < 0 then
    flipGunSprite = -1
  end
  if arg[2] == "debug" then
    -- draws the angle where the player is aiming with their mouse as a line in red
    love.graphics.setColor(1,0,0,1)
    local aimX1 = player.body:getX()+(math.sin(player.currentAimAngle) * player.hardboxRadius)
    local aimX2 = player.body:getX()+(math.sin(player.currentAimAngle) * player.reachRadius)
    local aimY1 = player.body:getY()+(math.cos(player.currentAimAngle) * player.hardboxRadius)
    local aimY2 = player.body:getY()+(math.cos(player.currentAimAngle) * player.reachRadius)
    love.graphics.line(aimX1, aimY1, aimX2, aimY2)
    -- draws the gun's current aim angle, factoring in recoil penalty, in orange
    love.graphics.setColor(1,0.5,0,0.6)
    local recoilX2 = player.body:getX()+(math.sin(player.currentAimAngle) * player.reachRadius)
    local recoilY2 = player.body:getY()+(math.cos(player.currentAimAngle) * player.reachRadius)
    love.graphics.line(player.body:getX()+spriteLocationOffsetX, player.body:getY()+spriteLocationOffsetY, player.body:getX()+(spriteLocationOffsetX*2), player.body:getY()+(spriteLocationOffsetY*2))
  end

  -- reset the colors so gun sprite uses proper palette
  love.graphics.setColor(1,1,1,1)

  -- draw the gun sprite
  -- y-origin arg has a small positive offset to line up testgun sprite's barrel with actual aim angle, this is temporary and will need to vary with other gun sprites
  love.graphics.draw(gun.gunSprite, player.body:getX()+spriteLocationOffsetX, player.body:getY()+spriteLocationOffsetY, (math.pi/2) - adjustedAimAngle, 0.3, 0.3*flipGunSprite, 0, 15)
end -- }}}

-- This function creates a gun, adds it to `gunlist`, and returns its UID.
-- Whoever is using the gun should then add that UID to a list of gun UIDs they own.
-- To shoot/render the gun from outside this file, use `gunlib.gunlist[gunUID]:shoot()`.
M.equipGun = function(gunName, firegroup) -- {{{
-- find gundef file by name
  local gun = dofile('gundefs/'..gunName..".lua")

  -- set cooldown of new gun
  -- `gun.current` holds all data about the gun that can change during gameplay
  -- (cooldown, firegroup, etc)
  gun.current = {}
  gun.current.cooldown = gun.cooldown

  -- set firegroup of new gun, default to 1 if not specified
  gun.current.firegroup = firegroup or 1

  -- create shootQueue for new gun
  -- the shootQueue is used for burst fire and other mods that create time-delayed shots
  gun.current.shootQueue = {}

  -- set recoil penalty state of new gun to zero on equip (no penalty)
  gun.current.recoilAimPenaltyOffset = 0

  -- set UID of new gun
  gun.uid = util.gen_uid("guns")

  -- add methods
  gun.shoot = shoot
  gun.draw = draw
  -- gun.modify = modify

  -- add it to the list of all guns in world, then return its uid
  M.gunlist[gun.uid] = gun
  return gun.uid
end -- }}}

M.setup = function()
  M.gunlist = {}
end

-- assorted utility functions {{{
local function recoverFromRecoilPenalty(dt, gun)
  if gun.current.recoilAimPenaltyOffset > (gun.recoilRecoverySpeed * dt) then
    gun.current.recoilAimPenaltyOffset = gun.current.recoilAimPenaltyOffset - (gun.recoilRecoverySpeed * dt)
  elseif gun.current.recoilAimPenaltyOffset < (-gun.recoilRecoverySpeed * dt) then
    gun.current.recoilAimPenaltyOffset = gun.current.recoilAimPenaltyOffset + (gun.recoilRecoverySpeed * dt)
  else
    gun.current.recoilAimPenaltyOffset = 0
  end
end
-- }}}

M.update = function (dt) -- {{{
  for _,gun in pairs(M.gunlist) do
    -- decrement each gun's cooldown timer
    gun.current.cooldown = gun.current.cooldown - dt
    
    -- iterate through each gun's shootQueue, decrementing timers and shooting the gun if timer is up
    local next = next
    if next(gun.current.shootQueue) ~= nil then
      for i, queuedShot in ipairs(gun.current.shootQueue) do
        queuedShot.firesIn = queuedShot.firesIn - dt
        -- if queued shot is ready to fire...
        if queuedShot.firesIn <= 0 then
          -- then calculate where it should spawn the projectile(s)
          local shotWorldOriginX = math.sin(queuedShot.shotBy.currentAimAngle) * (gun.playerHoldDistance + queuedShot.shotBy.hardboxRadius)
          local shotWorldOriginY = math.cos(queuedShot.shotBy.currentAimAngle) * (gun.playerHoldDistance + queuedShot.shotBy.hardboxRadius)
          -- then shoot the gun and apply the knockback to whoever shot it
          local shotKnockback = gun:shoot(queuedShot.shotBy.body:getX()+shotWorldOriginX, queuedShot.shotBy.body:getY()+shotWorldOriginY, queuedShot.shotBy.currentAimAngle)
          local knockbackX, knockbackY = queuedShot.shotBy.calculateShotKnockback(shotKnockback, queuedShot.shotBy.crosshairCacheX, queuedShot.shotBy.crosshairCacheY)
          queuedShot.shotBy.addToThisTickPlayerKnockback(knockbackX, knockbackY)
          -- finally, remove the fired shot from the queue
          gun.current.shootQueue[i] = nil
        end
      end
    end

    -- if player has managed to get recoil aim penalty past a full rotation counterclockwise or clockwise (impressive),
    -- modulo the value so the recoil recovery doesn't spin more than a full rotation
    if gun.current.recoilAimPenaltyOffset > math.pi*2 then
      gun.current.recoilAimPenaltyOffset = gun.current.recoilAimPenaltyOffset % (2*math.pi)
    elseif gun.current.recoilAimPenaltyOffset < -math.pi*2 then
      gun.current.recoilAimPenaltyOffset = gun.current.recoilAimPenaltyOffset % (-2*math.pi)
    end
    recoverFromRecoilPenalty(dt, gun)

    -- print(gun.uid.." : "..gun.current.recoilAimPenaltyOffset)
  end
end -- }}}

-- debug functions {{{
M.dumpGunTable = function()
  print("master gunlist: "..util.tprint(M.gunlist))
end
-- }}}

return M
-- vim: foldmethod=marker
