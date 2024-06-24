const SYSTEM_TIMERS = TimerOutputs.TimerOutput()

enable_debug_timers() = TimerOutputs.enable_debug_timings(InfrastructureSystems)
disable_debug_timers() = TimerOutputs.disable_debug_timings(InfrastructureSystems)
reset_debug_timers() = TimerOutputs.reset_timer!(SYSTEM_TIMERS)
print_debug_timers() = print(stderr, SYSTEM_TIMERS)
log_debug_timers() = @info "InfrastructureSystems Timers: $SYSTEM_TIMERS"
