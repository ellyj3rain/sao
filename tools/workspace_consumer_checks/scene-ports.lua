-- Nonrendering action animation/cursor/log endpoints; actual native placement
-- and source/site/means/person/planning/result/use owners remain loaded.
function getCell()return __consumer.body:getCell()end
function getSpecificPlayer()return __consumer.body end -- same-actor Lua call only
function getSandboxOptions()return {getOptionByName=function()return {getValue=function()return 3 end}end}end
ISBuildMenu=ISBuildMenu or{};ISBuildMenu.cheat=false
Core=Core or{getTileScale=function()return 1 end}
function getSprite(name)return IsoSpriteManager.instance:getSprite(name)end
-- The isolated route endpoint moves the actual native actor before owner tick.
-- Original site/reach/body admission remains with its ordinary native owners.
SAO.Locomotion.tick=function(id)
 local job=SAO.Locomotion.jobs[id]
 return job~=nil and job.done==true
end
