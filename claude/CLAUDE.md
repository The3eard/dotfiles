## How I like work done

- Surgical changes: every changed line traces to the request. Match the surrounding code's style, comment density and idiom. Leave unrelated code alone; mention pre-existing problems instead of fixing them.
- Minimum code that solves the problem; no speculative abstractions or configurability.
- Verify before saying done: a bug fix comes with a failing test made green, a refactor with the affected suite run.
- When two readings of a request would produce materially different work, ask; otherwise pick the obvious one and state the assumption.

## Code documentation style

Documentation is proportional to complexity. Document the contract and the *why*, never the *what* the signature already says. Deletion test: if removing the comment loses nothing that isn't in the name, the signature or a test, remove it.

- Present tense, current state only. No history, dates, epics or people's names.
- Ticket IDs only where a reader who can't see the ticket would act wrongly: a dangerous invariant, an incident not to re-trigger, a workaround for an external bug. Never as a changelog stamp.
- Inline `//` only for the *why* of a genuinely surprising line.
- Javadoc: first sentence is a one-line third-person summary ending in a period. `@param`/`@return`/`@throws` only for what the signature can't carry (units, ranges, nullability, when an `Optional` is empty, which caller decision an exception drives). Partial Javadoc is fine. `@deprecated` names the replacement with `{@link}`. Explain a flow once, at the highest level (class or `package-info.java`).
- Load-bearing invariants (ordering, locking, security) are the exception to brevity and the legitimate place for a ticket reference.
- REST controllers: the description lives in the OpenAPI annotations; a Javadoc that repeats `@Operation` is redundant. `@ApiResponse` only for codes a client must handle. On DTOs, `@Schema(description, example, requiredMode)` is worth it: it is the public contract.

## Workflow model tiers

When I ask for a **workflow**, pick models by complexity instead of one default: orchestration on **fable** for complex tasks, **opus** for simpler ones; agents inside on **haiku** (mechanical), **sonnet** (intermediate) or **opus** (heavy reasoning, synthesis, critical verification). Classify each phase before writing the script and set `model` per `agent()`.

## graphify

In repositories with a graphify knowledge graph (`graphify-out/graph.json` at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code, and put this rule in every subagent prompt that explores code:

- `graphify query "<question>"` for a scoped subgraph, `graphify path "<A>" "<B>"` for how two symbols connect, `graphify explain "<symbol>"` for one symbol and its neighbours, `graphify affected "<symbol>"` for blast radius. Read raw files only for the lines the graph already located.
- `graphify-out/GRAPH_REPORT.md` only for broad architecture review, when query/path/explain don't surface enough.
- After modifying code, or in a worktree whose graph came from another branch, run `graphify update .` (AST only, no API cost).

If there is no `graphify-out/`, skip graphify entirely — indexing is the user's decision. `/graphify` (the skill) builds or rebuilds a graph.
