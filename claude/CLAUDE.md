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

<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
<!-- CODEGRAPH_END -->
