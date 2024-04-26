@scoped_enum(
    RunStatus,
    NOT_READY = -2,
    INITIALIZED = -1,
    SUCCESSFULLY_FINALIZED = 0,
    RUNNING = 1,
    FAILED = 2,
)

@scoped_enum(SimulationBuildStatus, IN_PROGRESS = -1, BUILT = 0, FAILED = 1, EMPTY = 2,)
