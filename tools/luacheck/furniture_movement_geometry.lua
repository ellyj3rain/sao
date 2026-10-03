-- Geometry/pathfinding and balance calculation are controlled; transfer, FPP safety,
-- action complete(), delayed-client animation and SAO wrappers execute production Lua.
function FurniturePushPull.moveFootprintIsValid() return true end
function FurniturePushPull.getBalance() return 1,1,1,0.1 end
function FurniturePushPull.validateServerMove() return {enduranceCost=0.1} end
function FurniturePushPull.getMovePlan() return {enduranceCost=0.1} end
function FurniturePushPull.validatePullCommit() return true end
function FurniturePushPull.getMovePlan(character,object,mode) return {enduranceCost=0.1,destination=__square(object.square.x+1,object.square.y,object.square.z)} end
