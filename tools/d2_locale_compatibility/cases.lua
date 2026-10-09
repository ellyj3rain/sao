assert(RadioCustomInt and type(RadioCustomInt.MTL)=='function',"D2_LOCALE:active_source_callback_loaded")
RadioCustomInt.MTL(BODY,1)
assert(#HALOS==1 and HALOS[1].name=='Welding' and HALOS[1].amount==50,
    "D2_LOCALE:actual_source_welding_halo_native_label")
assert(EVENTS==1,"D2_LOCALE:original_radio_scheduler_binding")
SOURCE_CALL_PROVEN=true
