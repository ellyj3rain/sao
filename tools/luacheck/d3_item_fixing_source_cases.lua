-- Actual private option enumeration, reservation re-enumeration and SourceUse
-- admission functions. Private store/body/locomotion receivers are controlled.
function __runPrivateFixingSourceCases(fixture,check,control)
    local f=fixture('source-cap-'..tostring(control or 'normal'))
    f.inventory.items={f.target}
    local source={id='C:known-stock',kind='container',x=1,y=1,z=0,chunkX=0,chunkY=0,
        revision='known-revision',fingerprint='known-fingerprint',state='available',quantities={weapons=129},
        knowledgeKind='inspected',placeId='private-stock'}
    local physical={id=source.id,revision=source.revision,fingerprint=source.fingerprint,items={},itemOrder={}}
    for index=1,128 do local key=tostring(index)
        physical.itemOrder[#physical.itemOrder+1]=key
        physical.items[key]={id=index,type='Base.Pistol2',categories={weapons=true},amount=0,uses=1}
    end
    physical.itemOrder[#physical.itemOrder+1]='702';physical.items['702']={id=702,type='Base.Pistol',categories={weapons=true},amount=0,uses=1}
    local belief={cx=1,cy=1,z=0,sources={weapons=true},sourceFacts={[source.id]=source},revisions={[source.id]=source.revision},at=99}
    __privateFixingKnown={['private-stock']=belief}
    __privateFixingStore={sources={[source.id]=physical},sequence=0,reservations={}}
    SAO.Perception.knownPlaces=function() return __privateFixingKnown end
    SAO.Standing.mayAttemptBelieved=function() return __permission==true end
    SAO.WorldSources=__actualFixingWS;SAO.SourceUse=__actualFixingSU
    local WS=SAO.WorldSources
    local place={id='private-stock',cx=1,cy=1,z=0}
    local ordinary=WS.actionOptions(place,'weapons',f.id,f.body,1,'standing','acquire')
    local exact=WS.actionOptions(place,'weapons',f.id,f.body,1,'standing','acquire','Base.Pistol')
    check('exact_private_donor_filter_precedes_source_cap',exact and #exact.options==1 and exact.options[1].parameters.itemId==702
        and ordinary and #ordinary.options==16 and ordinary.options[1].parameters.itemType=='Base.Pistol2')
    if control=='source-cap' then return end
    local selected=exact and exact.options[1]
    local reserved=selected and WS.beginAction(place,'weapons',f.id,f.body,1,'standing',selected,'acquire')
    check('exact_donor_reservation_reenumeration_keeps_filter',reserved and reserved.itemId==702 and reserved.itemType=='Base.Pistol')
    if control=='reservation-filter' then return end
    f.rec.worldSourceReservation=nil;__privateFixingStore.reservations={}
    if not control then
        physical.revision='unobserved-new-revision'
        check('new_physical_stock_never_fills_private_donor',WS.actionOptions(place,'weapons',f.id,f.body,1,'standing','acquire','Base.Pistol')==nil)
        physical.revision=source.revision;__permission=false
        check('private_donor_filter_keeps_current_standing',WS.actionOptions(place,'weapons',f.id,f.body,1,'standing','acquire','Base.Pistol')==nil)
        __permission=true
        local forged={id=selected.id,owner=selected.owner,parameters={}}
        for key,value in pairs(selected.parameters) do forged.parameters[key]=value end
        forged.parameters.itemType='Base.Pistol2'
        check('forged_donor_type_cannot_reserve_private_item',WS.beginAction(place,'weapons',f.id,f.body,1,'standing',forged,'acquire')==nil)
        check('nonacquire_expected_type_refused',WS.actionOptions(place,'weapons',f.id,f.body,1,'standing','consume','Base.Pistol')==nil)
    end
    -- Query through actual SourceUse.begin/chooseOption and actual reservation.
    local called=SAO.SourceUse.beginAcquisition(f.id,f.body,place,'weapons',
        {sourceId=source.id,sourceRevision=source.revision,itemId=702,itemType='Base.Pistol'})
    check('sourceuse_exact_type_reaches_private_native_admission',called==true and f.rec.worldSourceReservation~=nil
        and __privateFixingStore.reservations[f.rec.worldSourceReservation].itemId==702)
    if control then return end
    f.rec.worldSourceReservation=nil;__privateFixingStore.reservations={}
    SAO.Controller.resourceContext=__actualFixingResourceContext
    SAO.Controller.reconcileConstruction=function() return true end
    local context=SAO.Controller.toolMaintenanceContext(f.id,f.agent,f.body)
    local sources=context.sources[context.options[1].recipeId]
    check('controller_each_fixing_queries_exact_private_type',sources and #sources==1 and sources[1].itemId==702 and sources[1].itemType=='Base.Pistol')
    -- Compatible ordinary enumeration still admits an unfiltered selected type.
    local broad=WS.actionOptions(place,'weapons',f.id,f.body,1,'standing','acquire')
    local broadReservation=WS.beginAction(place,'weapons',f.id,f.body,1,'standing',broad.options[1],'acquire')
    check('ordinary_nonfixing_acquisition_still_reserves',broadReservation and broadReservation.itemType=='Base.Pistol2')
end
