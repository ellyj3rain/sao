-- Original SAO API implementation uses these attributed inspected data facts.
SAO=SAO or {}
SAO.WindowPaneSources=SAO.WindowPaneSources or {}
local S=SAO.WindowPaneSources
S.material={fullType="RepairableWindows.LargeGlassPane",weight=.8,
    icon="GlassPane",staticModel="GlassPanel",worldStaticModel="GlassPanel"}
S.provenance={source="RepairableWindows42.13",author="albion",version="2.1.0",
    workshopId="3378304610",role="inspected behavior/data facts; original SAO runtime and definitions",
    nativeOwner="Project Zomboid installed Item/CraftRecipe/IsoWindow/ItemContainer",
    copyingGrant="not-established; no third-party runtime/custom art copied"}
S.supply={mold="RepairableWindows.ClayLargeSheetMold",unfiredMold="RepairableWindows.ClayLargeSheetMoldUnfired",
    crucible="Base.CeramicCrucibleWithGlass",crucibles=4,clay=12,
    paneRecipe="Base.MakeLargeGlassPane",learnedBasis="MakeGlassPanel"}
return S
