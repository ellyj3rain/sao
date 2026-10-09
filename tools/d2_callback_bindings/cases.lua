local family=string.match(CASE,"^([^:]+)")
local mode=string.match(CASE,":(.+)$")
local ambition={completed=true,isActive=true,goal1=100,goal1progress=0}
if family=="LSCommando" or family=="LSTheProfessional" then
    if mode=="zombie" or mode=="zombie-update" then ambition.completed=false end
    -- Completed action still starts its real OnPlayerUpdate listener while the
    -- controlled current weapon fails the source-specific equipment predicate.
    LSUtil.isWeaponType=function() return false end
elseif family=="LSElDorado" or family=="LSExplorer" then ambition.isActive=false end
BODY.data.Ambitions[family]=ambition
LSAmbtMng[family](BODY,ambition)
local callbackNames={LSBladeMaster="LSBMTick",LSLordDeath="LSAMBTLDTick",LSCommando="LSCDOnPlayerUpdate",LSTheProfessional="LSTPOnPlayerUpdate"}
local zombieNames={LSCommando="LSCDOnZDead",LSTheProfessional="LSTPOnZDead",LSElDorado="LSEDOnZDead",LSExplorer="LSEXOnZDead",LSGoodEating="LSGEOnZDead",LSKnockdown="LSKDOnZDead",LSLordDeath="LSAMBTLDOnZDead"}
if mode=="tick" then
    registered("OnTick")
    emit("OnTick");emit("OnTick")
    check(BODY.variables.LSCombatSpeed=="Execute","original_active_tick_effect")
    BODY.data.Ambitions[family]=nil
    emit("OnTick");emit("OnTick")
    retired("OnTick",callbackNames[family])
    check(BODY.variables.LSCombatSpeed=="End","original_retirement_effect")
elseif mode=="update" then
    registered("OnPlayerUpdate")
    BODY.data.Ambitions[family]=nil
    emit("OnPlayerUpdate",BODY)
    retired("OnPlayerUpdate",callbackNames[family])
    retired("OnWeaponHitCharacter","paired_hit")
elseif mode=="zombie-update" then
    registered("OnZombieDead")
    LSUtil.isWeaponType=function(player,weapon,kind) return family=="LSCommando" and kind=="FIREARM" or family=="LSTheProfessional" and kind=="HANDGUN" end
    emit("OnWeaponHitCharacter",BODY,TARGET,WEAPON,10)
    emit("OnZombieDead",TARGET)
    check(ambition.goal1progress==1,"original_zombie_progress_once")
    emit("OnZombieDead",TARGET)
    check(ambition.goal1progress==1,"original_zombie_replay_not_progress")
    emit("OnWeaponHitCharacter",BODY,TARGET,WEAPON,10)
    BODY.data.Ambitions[family]=nil
    emit("OnZombieDead",TARGET)
    retired("OnZombieDead",zombieNames[family])
else
    registered("OnZombieDead");registered("OnWeaponHitCharacter")
    BODY.data.Ambitions[family]=nil
    emit("OnWeaponHitCharacter",BODY,TARGET,WEAPON,10)
    retired("OnZombieDead",zombieNames[family])
    retired("OnWeaponHitCharacter","paired_hit")
    check(TARGET.health==100,"no_retired_combat_effect")
end
local hits=LISTENER_HITS
if mode=="tick" then emit("OnTick")
elseif mode=="update" then emit("OnPlayerUpdate",BODY)
else emit("OnZombieDead",TARGET) end
check(LISTENER_HITS==hits+1,"unrelated_listener_preserved")
for _,event in pairs(Events) do event.Remove(sentinel) end
LIFECYCLE_PROVEN=true
