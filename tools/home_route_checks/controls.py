"""Named production-source defects, each tied to the violated behavior."""

def replace(source, old, new):
    if source.count(old) != 1:
        raise AssertionError("home route mutation target drifted: " + old)
    return source.replace(old, new, 1)


def variants(source):
    specs = [
        ("old-unbounded-retry", "and homeRouteReady(rec, body, homeX, homeY, homeZ)", "and true", "immediate_retry_suppressed"),
        ("drop-receipt", "agent.rec.homeRouteFailure = homeFailure", "agent.rec.homeRouteFailure = nil", "receipt_retained"),
        ("forget-record-on-read", "local failed = rec.homeRouteFailure", "local failed = nil", "immediate_retry_suppressed"),
        ("never-reconsider", "return now ~= nil and now >= failed.atHours + HOME_ROUTE_RETRY_HOURS * failed.attempts", "return false", "retry_at_delay_allowed"),
        ("ignore-delay", "return now ~= nil and now >= failed.atHours + HOME_ROUTE_RETRY_HOURS * failed.attempts", "return true", "immediate_retry_suppressed"),
        ("fixed-first-delay", "failed.atHours + HOME_ROUTE_RETRY_HOURS * failed.attempts", "failed.atHours + HOME_ROUTE_RETRY_HOURS", "second_delay_not_first_delay"),
        ("ignore-target-x", "failed.x ~= math.floor(x)", "false", "changed_target_allowed"),
        ("ignore-target-floor", "failed.z ~= math.floor(z or 0)", "false", "changed_target_floor_allowed"),
        ("ignore-changed-approach", "return dx * dx + dy * dy <= HOME_ROUTE_RECONSIDER_REACH * HOME_ROUTE_RECONSIDER_REACH", "return true", "changed_approach_allowed"),
        ("reset-on-small-motion", "<= HOME_ROUTE_RECONSIDER_REACH * HOME_ROUTE_RECONSIDER_REACH", "<= 0", "small_motion_keeps_failure"),
        ("ignore-approach-floor", "failed.fromZ ~= math.floor(body:getZ())", "false", "changed_approach_floor_allowed"),
        ("future-receipt-holds", "if now and now < failed.atHours then rec.homeRouteFailure = nil; return true end", "", "rewound_clock_does_not_permanently_hold"),
        ("uncapped-failure-count", "math.min(HOME_ROUTE_RETRY_LIMIT, prior.attempts + 1)", "prior.attempts + 1", "failure_count_capped"),
        ("ignore-arrival", 'if status == "done:arrived" then return nil, true end', 'if status == "done:arrived" then return nil, false end', "successful_arrival_clears_failure"),
        ("ignore-occupancy", "if insideHome then rec.homeRouteFailure = nil end", "", "actual_occupancy_clears_failure"),
        ("write-before-owner-closes", 'if setState(agent, id, "IDLE", s) and homeEnded then', 'setState(agent, id, "IDLE", s)\n            if homeEnded then', "refused_reconciliation_keeps_owner"),
        ("learn-censored-result", "if not HOME_ROUTE_FAILURES[status] then return nil, false end", "", "non_access_result_not_learned_IDLE"),
        ("ignore-job-body", "or not job or job.body ~= body", "or not job", "foreign_job_body_not_learned"),
        ("ignore-job-goal", "or math.floor(job.goal.x) ~= math.floor(x)", "or false", "different_job_goal_not_learned"),
    ]
    for label, old, new, marker in specs:
        if marker is not None:
            yield label, replace(source, old, new), marker
    yield "home-hold-consumes-decision", replace(source,
        "if insideHome then rec.homeRouteFailure = nil end",
        "if insideHome then rec.homeRouteFailure = nil end\n"
        "            if not homeRouteReady(rec, body, homeX, homeY, homeZ) then return true end"), "other_productive_decision_remains_available"
