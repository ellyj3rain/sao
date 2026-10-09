if MODE=='ghost' then ISPanel=ISBaseObject:derive('ControlledPanelHost')end
if MODE=='globalmusic' then REGISTRY={Foreign='preserved'};GlobalMusic=REGISTRY end
if MODE=='recmedia' then REGISTRY=RecMedia;NATIVE_ROWS={};for key,row in pairs(RecMedia)do NATIVE_ROWS[key]=row end end
if MODE=='explorer' then
 UIFont={Small='small',Large='large'};function getTextManager()return{getFontHeight=function()return 12 end}end
 function getDebug()return false end
 ISPanel=ISBaseObject:derive('ControlledPanelHost');ISPanelJoypad=ISPanel:derive('ControlledJoypadHost');ISCollapsableWindowJoypad=ISBaseObject:derive('ControlledWindowHost')
end
