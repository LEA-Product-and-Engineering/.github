# Org default review policy — automated adjudication

Used by the LLM review pipeline when the target repo's base branch does not
yet carry `.github/review-policy.md` (i.e., the pipeline-enablement PR
itself). It is the shared core of every repo policy; repo-specific rules take
over once the repo's own policy file is merged.

## Blocks merge (`request_changes`)

1. **security** — missing or weakened authentication/authorization; cross-tenant
   data access (any query or lookup not scoped to the owning company/client);
   secrets, credentials, tokens, or private keys in code or config; injection
   paths (SQL, shell, template); PII written to logs or returned in responses
   beyond what the endpoint requires.
2. **correctness** — clear bugs (unreachable logic, inverted conditions, wrong
   operators, unhandled None/null on a required path); data-loss risk;
   destructive or irreversible data migrations without a rollback path.
3. **control_integrity** — changes that disable or weaken CI workflows,
   required status checks, branch rulesets, review policy files, the review
   pipeline workflows, encryption settings, audit logging, or error reporting.
4. **untested_new_logic** — an entirely untested new endpoint, service,
   workflow, or module containing business logic. (Coverage *gaps* in
   existing code are notes, not blocks.)

## Never blocks (non-blocking notes only)

Style, naming, refactoring suggestions, performance improvements short of an
obvious hot-path problem, documentation, dependency nitpicks.
