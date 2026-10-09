-- Exact native-compiled client command producer -> complete existing server consumer.
-- Transport, player/UI scene and catalogue availability are controlled boundaries.
CLIENT=true
local function wearer(id)
 local w=nativeWearer(id);function w:resetModel()end;return w
end
local function window(num)
 local needle=nativeNeedle();local w=LSMirrorMenu:new(0,0,500,500,num,{MakeupTattooNeedle=needle},{},{},{},{})
 w.playermodel={setCharacter=function()end};w.resetSpecificButton={setEnable=function()end};w.resetAllButton={setEnable=function()end};w.destroy=function(self)self.destroyed=true end
 return w,needle
end
local a,b=wearer('MP-A'),wearer('MP-B');PLAYERS[0]=a;PLAYERS[1]=b
local changed,needle=window(0);local unchanged,otherNeedle=window(1);local before,otherBefore=needle:getCurrentUsesFloat(),otherNeedle:getCurrentUsesFloat()
local current=instanceItem('Face_Tattoo');changed:onClickMakeupPreview({onClickArgs={current,'Face_Tattoo',1,false}})
unchanged:onConfirmChanges({});check(SENT[1]==b and SENT[2]=='LS' and SENT[3]=='SetMirrorMakeup','mirror_client_exact_unchanged_receiver');check(SENT[4][1][3]==false,'mirror_client_unchanged_command_omits_needle');local unchangedArgs=SENT[4]
changed:onConfirmChanges({});check(SENT[1]==a and SENT[4][1][3]==needle,'mirror_client_changed_exact_needle_argument');check(near(needle:getCurrentUsesFloat(),before) and near(otherNeedle:getCurrentUsesFloat(),otherBefore),'mirror_client_retains_local_uses');local changedArgs=SENT[4]
CLIENT=false;LSMirrorMenu_server.setMirrorChanges(b,unchangedArgs);check(near(otherNeedle:getCurrentUsesFloat(),otherBefore),'mirror_server_unchanged_native_needle_retained')
LSMirrorMenu_server.setMirrorChanges(a,changedArgs);check(needle:getCurrentUsesFloat()<before and near(otherNeedle:getCurrentUsesFloat(),otherBefore),'mirror_server_changed_native_needle_only');check(a:nativeWornCount()==1,'mirror_server_real_worn_item_preserved')
check(useTattoo==false,'mirror_client_foreign_owner');PROVEN=true
