const SYSTEM_TIMERS = TimerOutputs.TimerOutput()

enable_timers() = TimerOutputs.enable_timer!(SYSTEM_TIMERS)
disable_timers() = TimerOutputs.disable_timer!(SYSTEM_TIMERS)
reset_timers() = TimerOutputs.reset_timer!(SYSTEM_TIMERS)
print_timers() = print(stderr, SYSTEM_TIMERS)
log_timers() = @info "InfrastructureSystems Timers: $SYSTEM_TIMERS"

# Disable by default.
disable_timers()
