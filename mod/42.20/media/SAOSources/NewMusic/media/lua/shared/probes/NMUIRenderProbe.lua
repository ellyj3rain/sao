-- Lightweight UI performance probe with rolling 2s summaries.
NMUIRenderProbe = NMUIRenderProbe or {}

local SUMMARY_WINDOW_MS = 2000
local DETAIL_THRESHOLD_MS = 4.0
local FRAME_THRESHOLD_MS = 12.0
local HOT_METRIC_THRESHOLD_MS = 1.25
local DETAIL_LOG_INTERVAL_MS = 1000

local function nowMs()
    return (getTimestampMs and tonumber(getTimestampMs()))
        or (getTimeInMillis and tonumber(getTimeInMillis()))
        or 0
end

local function isEnabled()
    return NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("ui_render") == true
end

local function ensureWindowStore(window)
    if not window then return nil end
    window._nmUiPerf = window._nmUiPerf or {
        startedMs = nowMs(),
        lastFlushMs = 0,
        metrics = {},
        counters = {},
        runId = tostring(math.floor(nowMs()))
    }
    return window._nmUiPerf
end

local function resolveWindowKind(window)
    if not window then
        return "unknown"
    end
    local kind = tostring(window._nmUiPerfKind or "")
    if kind ~= "" then
        return kind
    end
    local targetKind = tostring(window.target and window.target.kind or "")
    if targetKind == "vehicle" then
        return "generic"
    end
    return "unknown"
end

local function metricAverage(metric)
    local count = tonumber(metric and metric.count) or 0
    if count <= 0 then
        return 0
    end
    return (tonumber(metric.sumMs) or 0) / count
end

local function resolveHotMetricSummary(metrics)
    local hotKey = "none"
    local hotAvg = 0
    for key, metric in pairs(metrics or {}) do
        local avg = metricAverage(metric)
        if avg >= HOT_METRIC_THRESHOLD_MS and avg > hotAvg then
            hotKey = tostring(key or "unknown")
            hotAvg = avg
        end
    end
    return hotKey, hotAvg
end

local function counterValue(counters, key)
    return tonumber(counters and counters[key] or 0) or 0
end

local function ensureMetric(store, key)
    local metrics = store.metrics
    metrics[key] = metrics[key] or { count = 0, sumMs = 0.0, maxMs = 0.0 }
    return metrics[key]
end

function NMUIRenderProbe.count(window, key, delta)
    if not isEnabled() then return end
    local store = ensureWindowStore(window)
    if not store then return end
    local k = tostring(key or "unknown")
    store.counters[k] = (tonumber(store.counters[k]) or 0) + (tonumber(delta) or 1)
end

function NMUIRenderProbe.beginWindow(window)
    if not isEnabled() then return nil end
    if not ensureWindowStore(window) then return nil end
    return nowMs()
end

function NMUIRenderProbe.endWindow(window, key, startedMs)
    if not isEnabled() then return 0 end
    if not startedMs then return 0 end
    local store = ensureWindowStore(window)
    if not store then return 0 end
    local elapsed = math.max(0, nowMs() - tonumber(startedMs or 0))
    local metric = ensureMetric(store, tostring(key or "unknown"))
    metric.count = metric.count + 1
    metric.sumMs = metric.sumMs + elapsed
    if elapsed > metric.maxMs then
        metric.maxMs = elapsed
    end
    if elapsed >= DETAIL_THRESHOLD_MS and NMCore and NMCore.shouldLogEvery
        and NMCore.shouldLogEvery("uiPerf.detail." .. tostring(key), nowMs(), DETAIL_LOG_INTERVAL_MS) then
        NMCore.logChannel(
            "ui_render",
            "ui_perf_detail",
            string.format("run=%s key=%s ms=%.2f", tostring(store.runId), tostring(key), elapsed)
        )
    end
    return elapsed
end

function NMUIRenderProbe.flush(window)
    if not isEnabled() then return end
    local store = ensureWindowStore(window)
    if not store then return end
    local now = nowMs()
    local lastFlushMs = tonumber(store.lastFlushMs) or 0
    if (now - lastFlushMs) < SUMMARY_WINDOW_MS then
        return
    end
    store.lastFlushMs = now
    local frame = store.metrics["device.frame"] or { count = 0, sumMs = 0, maxMs = 0 }
    local frameAvg = (frame.count > 0) and (frame.sumMs / frame.count) or 0
    local render = store.metrics["device.render"] or { count = 0, sumMs = 0, maxMs = 0 }
    local update = store.metrics["device.update"] or { count = 0, sumMs = 0, maxMs = 0 }
    local resolve = store.metrics["device.resolveContext"] or { count = 0, sumMs = 0, maxMs = 0 }
    local hostFrame = store.metrics["device.buildHostFrame"] or { count = 0, sumMs = 0, maxMs = 0 }
    local slotFrame = store.metrics["device.buildSlotFrameModel"] or { count = 0, sumMs = 0, maxMs = 0 }
    local renderModel = store.metrics["device.buildRenderModel"] or { count = 0, sumMs = 0, maxMs = 0 }
    local autoClose = store.metrics["device.autoCloseCheck"] or { count = 0, sumMs = 0, maxMs = 0 }
    local hpRender = store.metrics["slot.headphone.render"] or { count = 0, sumMs = 0, maxMs = 0 }
    local hpStyle = store.metrics["slot.headphone.render.style"] or { count = 0, sumMs = 0, maxMs = 0 }
    local hpResolveState = store.metrics["slot.headphone.render.resolve_state"] or { count = 0, sumMs = 0, maxMs = 0 }
    local hpResolveTex = store.metrics["slot.headphone.render.resolve_tex"] or { count = 0, sumMs = 0, maxMs = 0 }
    local hpDrawTex = store.metrics["slot.headphone.render.draw_tex"] or { count = 0, sumMs = 0, maxMs = 0 }
    local hpPlaceholder = store.metrics["slot.headphone.render.placeholder"] or { count = 0, sumMs = 0, maxMs = 0 }
    local counters = store.counters or {}
    local uiKind = resolveWindowKind(window)
    local hotMetricKey, hotMetricAvg = resolveHotMetricSummary(store.metrics)
    local slotContentRebuild = counterValue(counters, "slot_frame.content_rebuild")
    local slotInteractionRebuild = counterValue(counters, "slot_frame.interaction_rebuild")
    NMCore.logChannel(
        "ui_render",
        "ui_perf_summary",
        string.format(
            "run=%s ui=%s frame_avg_ms=%.2f frame_max_ms=%.2f frame_calls=%d render_avg_ms=%.2f update_avg_ms=%.2f resolve_avg_ms=%.2f resolve_calls=%d hostFrame_avg_ms=%.2f slotFrame_avg_ms=%.2f renderModel_avg_ms=%.2f renderModel_rebuild=%d slotContent_rebuild=%d slotInteraction_rebuild=%d context_cache_hit=%d context_cache_miss=%d fallback=%d dragChecks=%d candidateScans=%d hot_metric=%s hot_metric_avg_ms=%.2f hp_avg_ms=%.2f hp_max_ms=%.2f hp_style_max=%.2f hp_state_max=%.2f hp_tex_resolve_max=%.2f hp_tex_draw_max=%.2f hp_placeholder_max=%.2f autoClose_calls=%d fastPath=%d slowPath=%d",
            tostring(store.runId),
            tostring(uiKind),
            frameAvg,
            tonumber(frame.maxMs) or 0,
            tonumber(frame.count) or 0,
            metricAverage(render),
            metricAverage(update),
            metricAverage(resolve),
            tonumber(resolve.count) or 0,
            metricAverage(hostFrame),
            metricAverage(slotFrame),
            metricAverage(renderModel),
            tonumber(counters["render_model.rebuild"] or 0),
            slotContentRebuild,
            slotInteractionRebuild,
            tonumber(counters["context.cache_hit"] or 0),
            tonumber(counters["context.cache_miss"] or 0),
            tonumber(counters["context.fallback"] or 0),
            tonumber(counters["slot.drag_check"] or 0),
            tonumber(counters["slot.candidate_scan"] or 0),
            tostring(hotMetricKey),
            tonumber(hotMetricAvg) or 0,
            metricAverage(hpRender),
            tonumber(hpRender.maxMs) or 0,
            tonumber(hpStyle.maxMs) or 0,
            tonumber(hpResolveState.maxMs) or 0,
            tonumber(hpResolveTex.maxMs) or 0,
            tonumber(hpDrawTex.maxMs) or 0,
            tonumber(hpPlaceholder.maxMs) or 0,
            tonumber(autoClose.count) or 0,
            tonumber(counters["autoclose.fast"] or 0),
            tonumber(counters["autoclose.slow"] or 0)
        )
    )
    if hotMetricKey ~= "none" and NMCore and NMCore.logChannel then
        NMCore.logChannel(
            "ui_render",
            "ui_perf_hot_metric",
            string.format(
                "run=%s ui=%s key=%s avg_ms=%.2f max_ms=%.2f",
                tostring(store.runId),
                tostring(uiKind),
                tostring(hotMetricKey),
                tonumber(hotMetricAvg) or 0,
                tonumber(store.metrics[hotMetricKey] and store.metrics[hotMetricKey].maxMs or 0) or 0
            )
        )
    end
    local rebuildDiagCount =
        counterValue(counters, "invalidate.ui_change")
        + counterValue(counters, "invalidate.context_cache")
        + counterValue(counters, "invalidate.slot_frame_model")
        + counterValue(counters, "invalidate.render_model")
        + counterValue(counters, "slot_frame.content_rebuild")
        + counterValue(counters, "slot_frame.interaction_rebuild")
        + counterValue(counters, "render_model.miss_missing_cache")
        + counterValue(counters, "render_model.miss_render_revision")
        + counterValue(counters, "render_model.miss_animation_revision")
        + counterValue(counters, "render_model.miss_frame_epoch")
    if rebuildDiagCount > 0 and NMCore and NMCore.logChannel then
        NMCore.logChannel(
            "ui_render",
            "ui_perf_rebuild_diag",
            string.format(
                "run=%s ui=%s invalidate_ui_change=%d invalidate_context=%d invalidate_slot_interaction=%d invalidate_render=%d revision_context=%d revision_slot_content=%d revision_slot_interaction=%d revision_render=%d revision_animation=%d slotContent_rebuild=%d slotInteraction_rebuild=%d render_miss_missing=%d render_miss_render=%d render_miss_animation=%d render_miss_frame=%d",
                tostring(store.runId),
                tostring(uiKind),
                counterValue(counters, "invalidate.ui_change"),
                counterValue(counters, "invalidate.context_cache"),
                counterValue(counters, "invalidate.slot_frame_model"),
                counterValue(counters, "invalidate.render_model"),
                counterValue(counters, "revision_bump.context"),
                counterValue(counters, "revision_bump.slot_content"),
                counterValue(counters, "revision_bump.slot_interaction"),
                counterValue(counters, "revision_bump.render"),
                counterValue(counters, "revision_bump.animation"),
                counterValue(counters, "slot_frame.content_rebuild"),
                counterValue(counters, "slot_frame.interaction_rebuild"),
                counterValue(counters, "render_model.miss_missing_cache"),
                counterValue(counters, "render_model.miss_render_revision"),
                counterValue(counters, "render_model.miss_animation_revision"),
                counterValue(counters, "render_model.miss_frame_epoch")
            )
        )
    end
    if frameAvg >= FRAME_THRESHOLD_MS and NMCore and NMCore.logChannel then
        NMCore.logChannel(
            "ui_render",
            "ui_perf_frame_hot",
            string.format(
                "run=%s ui=%s frame_avg_ms=%.2f frame_max_ms=%.2f",
                tostring(store.runId),
                tostring(uiKind),
                frameAvg,
                tonumber(frame.maxMs) or 0
            )
        )
    end
    store.metrics = {}
    store.counters = {}
end

return NMUIRenderProbe
