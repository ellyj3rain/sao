-- Compatibility-only True Music bootstrap shim (historical misspelling kept intentionally).
-- Must never fail: legacy packs still require this exact path during bootstrap.
if type(GlobalMusic) ~= "table" then
    GlobalMusic = {}
end
