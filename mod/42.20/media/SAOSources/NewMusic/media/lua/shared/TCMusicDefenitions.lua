-- Compatibility-only True Music shim in shared namespace.
-- Some legacy packs still resolve require() against shared paths at bootstrap.
if type(GlobalMusic) ~= "table" then
    GlobalMusic = {}
end
