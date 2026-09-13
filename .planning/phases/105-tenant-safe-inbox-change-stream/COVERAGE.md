# Phase 105 Coverage

| Requirement | Plan | Executable evidence |
|-------------|------|---------------------|
| INBX-03 | 105-01 | core behavior/adversarial publisher tests, post-commit trigger tests, first-transition lifecycle tests, Phoenix-free compile/dependency scan |
| INBX-04 | 105-02 | PubSub topic/message isolation tests, connected LiveView arrival/lifecycle refresh, wrong-scope and auth-drift denial, `mix verify.inbox` |

## Decision Coverage

| Decisions | Plan |
|-----------|------|
| D-01–D-05, D-11 | 105-01 |
| D-06–D-10, D-12 | 105-02 |

All 12 context decisions and both roadmap requirements have at least one implementation task and machine-executable verification path.
