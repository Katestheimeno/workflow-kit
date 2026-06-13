# Testing discipline

Stack-agnostic testing rules. Replace the framework-specific details (runner, layout,
markers) with your project's, or drop in a stack-specific version of this file.

---

## 1. Mandatory triggers — tests MUST exist when you add

- A new module, type, or public function.
- A new service / use-case, or a new branch in an existing one.
- A new data-access function (query/repository method).
- A new input/output schema or validator.
- A new entry point (route/handler/command/action).
- A new permission/authorization rule.
- A new event/signal handler.
- A new background job (retry behavior + idempotency branches).
- Any new `if/else`, `try/catch`, or early `return` in existing code.

## 2. Structure

Put tests where the project already puts them. Discover the existing layout before
adding files, and match it. Keep test data builders/factories in one well-known place
and reuse shared fixtures rather than redeclaring setup per file.

## 3. Coverage

- **Coverage is behavior, not lines.** A covered line with no assertion is wallpaper.
- **New code aspiration:** every branch you add (`if/else`, `try/catch`, early `return`, new conditional) has a test.
- Respect the project's coverage floor if it sets one.

## 4. Test cases to write for every change

| Category | What to verify |
|---|---|
| Happy path | Correct input → correct output |
| Edge cases | Empty / null / boundary values / empty collection |
| Failure modes | Invalid input, missing fields, malformed data |
| Authorization | Unauthenticated, wrong role, correct role, **object-level (IDOR)** |
| Validation | Every validator and constraint |
| Collection behavior | Filtering, ordering, pagination |
| Side effects | Events fired, cache invalidated, jobs enqueued, messages sent |
| Authorization boundaries | Principal A cannot access principal B's data |

## 5. Discipline

- Use the project's **factories/builders** — no ad-hoc object construction when a builder exists.
- **Reuse shared fixtures.** Don't redeclare per file.
- **Mock externals** — email, push, third-party APIs, queues. Integration with real services belongs to staging, not unit tests.
- Use the project's tools for **time-sensitive** tests (freeze/clock control).
- **Parametrize** similar cases rather than copy-paste.
- **One logical assertion per test** (multiple assert lines OK if the same concept).
- **Test names are sentences:** `test_user_cannot_accept_quote_they_do_not_own` beats `test_accept_quote_403`.

## 6. What NOT to do

- **Do not** mock what you own. If your service calls your data layer, let the real one run against the test environment.
- **Do not** commit skipped tests without a ticket reference in the reason.
- **Do not** rely on test-order side effects — each test is self-contained.
- **Do not** hit external networks from unit tests.
