-- Controlled Kahlua screen objects; catalog and option ID semantics are real.
local function check(name,condition)
 assert(condition,'D2_SOURCE_UI:'..name)
end
SAO={Log={line=function()end},Seams={wentDark=function()end}}
assert(loadstring(__sources['Owned:Catalog'],'owned-source-pages'))()
assert(loadstring(__sources['Owned:WeekOneCatalog'],'owned-weekone-pages'))()
require=function(name)
 if name=='SAO_SourceSandboxPages'then return SAO.SourceSandboxPages end
 if name=='SAO_WeekOneSandboxPages'then return SAO.WeekOneSandboxPages end
 error('unexpected require '..tostring(name))
end
getText=function(key)return key end
local ids={
 'Text.DividerMusicNew','NewMusic.MaxTrackingRange',
 'ComputerMod.DiscSpawnChance','ProjectArcade.SfxVolumePct',
 'FWOFitness.InitialPerkBonus','FWOWorkingTreadmill.FitnessXPMultiply',
 'KnoxAquarium.FreeTanks','MultiplierConfig.Art',
}
local unknown='NewMusic.ActiveDeviceLimit'
local pages,chosen={},{}
for index,id in ipairs(ids)do
 local rule=assert(SAO.SourceSandboxPages.options[id])
 chosen[id]=index%2==0 and rule.originalPage or rule.ownedPage
 pages[#pages+1]={name=getText('Sandbox_'..rule.originalPage),settings={{name=id}}}
 pages[#pages+1]={name=getText('Sandbox_'..rule.ownedPage),settings={{name=id}}}
end
local mixed=SAO.SourceSandboxPages.options['MultiplierConfig.Art']
for _,page in ipairs(pages)do
 if page.name==getText('Sandbox_'..mixed.originalPage)then
  page.settings[#page.settings+1]={name='Vanilla.Unrelated'}
 end
end
local unclear=SAO.SourceSandboxPages.options[unknown]
chosen[unknown]='unrecognized-page'
pages[#pages+1]={name=getText('Sandbox_'..unclear.originalPage),settings={{name=unknown}}}
pages[#pages+1]={name=getText('Sandbox_'..unclear.ownedPage),settings={{name=unknown}}}
getSandboxOptions=function()return{getOptionByName=function(_,id)
 if chosen[id]then return{getPageName=function()return chosen[id]end}end
end}end
ServerSettingsScreen={getSandboxSettingsTable=function()return pages end}
local function panelFor(page)
 local panel={controls={}}
 for _,setting in ipairs(page.settings)do panel.controls[setting.name]={page=page.name}end
 return panel
end
ServerSettingsScreen.create=function(self)
 local category={name='Sandbox'}
 local listbox={items={{item={category=category}}}}
 function listbox:removeItemByIndex(index)table.remove(self.items,index)end
 self.pageEdit={listbox=listbox,controls={Sandbox={}}}
 function self.pageEdit:createPanel(_,page)
  local panel=panelFor(page)
  for id,control in pairs(panel.controls)do self.controls.Sandbox[id]=control end
  return panel
 end
 for _,page in ipairs(pages)do
  listbox.items[#listbox.items+1]={item={page=page,panel=self.pageEdit:createPanel(category,page)}}
 end
end
assert(loadstring(__sources['Owned:Sandbox'],'sao-source-sandbox'))()
local function sourceRows(rows,id)
 local found={}
 for _,page in ipairs(rows)do
  for _,setting in ipairs(page.settings or{})do
   if setting.name==id then found[#found+1]=page end
  end
 end
 return found
end
local solo=ServerSettingsScreen.getSandboxSettingsTable()
for _,id in ipairs(ids)do
 local found=sourceRows(solo,id)
 check('solo_single_'..id,#found==1)
 check('solo_effective_page_'..id,found[1].name==getText('Sandbox_'..chosen[id]))
 check('source_preimage_'..id,#sourceRows(pages,id)==2)
end
check('solo_uncertain_retained',#sourceRows(solo,unknown)==2)
local vanilla=sourceRows(solo,'Vanilla.Unrelated')
check('mixed_vanilla_preserved',#vanilla==1)
local server=setmetatable({},{__index=ServerSettingsScreen});server:create()
local visible={}
for _,row in ipairs(server.pageEdit.listbox.items)do
 if row.item.page then visible[#visible+1]=row.item.page end
end
for _,id in ipairs(ids)do
 local found=sourceRows(visible,id)
 check('server_single_'..id,#found==1)
 check('server_effective_page_'..id,found[1].name==getText('Sandbox_'..chosen[id]))
 local control=server.pageEdit.controls.Sandbox[id]
 check('server_control_bound_'..id,control and control.page==found[1].name)
end
check('server_uncertain_retained',#sourceRows(visible,unknown)==2)
check('server_vanilla_preserved',#sourceRows(visible,'Vanilla.Unrelated')==1)
print('PASS D2 source UI '..(#ids*5+4))
