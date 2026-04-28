---
doc_type: distilled-principles
audience: [operator, system-designer]
prerequisite: none
authority: L4 (empirical, N=1, 89+ sessions)
data_provenance: 192 meta-learnings from author's session journal
extraction_method: cluster + dedup + abstract
---

# META_LEARNINGS.md — 30 Principles distilled from 192 sessions

These are not theory. They are scars. 192 specific incidents, decisions,
bugs, and fixes — clustered into 30 transferable principles.

For full provenance (which session, which incident, which fix), the source
journal lives in the author's local project memory directories. Not all
192 transfer; the 30 below do.

These overlap with the Constitution (`CLAUDE.md`) but go deeper into
operator-specific patterns.

---

## I. Observation Discipline (5)

1. **Observe before acting; min 2:1 reading:writing ratio.** Abstract
   reasoning on concrete state has >50% error. With real data: <10%.
2. **Read every file before editing.** Catches context that assumptions miss.
3. **Trace the full call chain before modifying middleware/routing/auth.**
   Each fix without the trace reveals another problem 1 step downstream.
4. **Grep the entire tree, not the spec's file list.** Static lists go
   stale; grep is truth.
5. **Run actual commands before fixing test expectations.** Don't guess
   the output; produce it, then assert against it.

## II. Verification Discipline (5)

6. **Build verification after every change.** Sequential fixes, not batch
   — each fix discrete, build check every 3-4.
7. **Verify functionally, not structurally.** "File exists" ≠ "feature works."
   Test behavior, not presence.
8. **Test the published artifact, not the source.** "I committed the fix"
   ≠ "users have the fix."
9. **Test endpoint latency after deploy, not just build.** Build passing
   does NOT mean production is healthy.
10. **Read existing convention BEFORE adopting payload suggestions.**
    Payloads may contain decisions that conflict with codebase convention.

## III. Adversarial Self-Review (4)

11. **Multi-pillar audit catches what flat audits miss.** Each angle
    (consistency, mechanical, scenario, edge case) finds different issues.
    5 audits found 22 total; no single audit found >12.
12. **Production scenario simulation > code review.** Reading code didn't
    catch cascade failure; simulating "what if malformed input" did.
13. **Audit DURING implementation, not only after.** Post-hoc audits cost
    an extra commit cycle. Inline checks prevent findings from existing.
14. **Cross-reference parallel agent findings.** Each audit agent has blind
    spots. Always merge and dedupe across agents. **Verify agent claims
    before reporting** — agents produce false positives.

## IV. Sub-Agent & Parallelism (3)

15. **Agent outputs are hypotheses, not facts.** Always verify with primary
    source (git, filesystem, grep) before acting.
16. **Background agents need 5-min mental timeout.** If no output, launch
    replacement or go inline. Background agents die silently.
17. **File-overlap check before parallel payloads.** Map every file each
    workstream creates AND modifies. Shared files default to TODO markers,
    then post-merge consolidation pass.

## V. Anti-Patterns (5)

18. **2-failure rule means STOP at 2, not 4.** Two failed attempts = change
    strategy. Each additional attempt breaks more code.
19. **Never apply global override for local problem.** `html,body{max-width:100%}`
    to fix mobile overflow breaks desktop. Fix at component level.
20. **Never trust 100% PASS.** A 100% pass is a red flag, not green. Always
    spot-check with actual code.
21. **Never bare values without bounds.** `1fr` in CSS Grid prevents text
    truncation; `min-width: auto` on flex children expands parents. Always
    use `minmax(0, 1fr)`, `min-w-0`.
22. **Never declare "state-of-the-art" without evidence.** Tested → measured
    → engineered → re-tested. Intuition-based optimization is pattern
    matching, not thinking.

## VI. Cross-domain patterns (8) — confirmed across multiple project memories

23. **Build verification after EVERY change is non-negotiable** — found
    across 5 different project memories. Single most-cited principle.

24. **Adversarial audit BEFORE declaring completion** — appears in 12+
    project memories. The pattern: declare done → audit → 5-10 issues
    found → fix → re-declare. Build the audit INTO your workflow.

25. **Context-boot files are load-bearing** — every project that survived
    >20 sessions has a `context-boot.md` listing entry conditions, current
    state, next action. Without it: cold-start cost compounds.

26. **YAML > JSON for LLM context** — ~20% fewer tokens, no quote/comma
    noise. Found across 3 unrelated projects.

27. **Memory files are append-only journals, not normalized DB** — every
    project that tried to "clean" memory ended up regretting deleted
    entries. Pattern: write feedback per session, never delete, only archive.

28. **STATE.yaml as session anchor** — projects with explicit current_phase
    + next_action in YAML survive sessions break better than projects with
    prose-style notes. Mechanical anchor > narrative.

29. **Update ALL numeric references when adding feature** — drift comes
    from stale counts ("29 commands" when there are 30). After ANY
    count-changing change, grep for the old number across all SoT files.

30. **3-cycle audit pattern is universal** — Cycle 1 (compliance) → Cycle 2
    (blindspots) → Cycle 3 (contamination/drift). No single audit pass
    catches everything; 3 cycles approach 95% coverage.

---

## How to use this document

This is the **operator's distilled discipline**. It is not normative for any
other operator. Reading it once gives you 80% of the value; the rest comes
from finding YOUR own patterns through running cost-audit + observer mode +
post-session reflection.

The Constitution (`CLAUDE.md`) is the universal layer. This is the
specific-to-this-operator layer. Adopt what resonates; ignore what doesn't.

If you build your own version of this document over 90 days of practice,
that is the architecture working. Open a PR with your distilled principles
to `docs/REPLICATION_LOG.md`.

## How to falsify

If after 90 days of operating with these principles your error rate
**rises** instead of falls, the principles transfer poorly to your workload.
That is data. Open an issue.

---

## Sources

192 specific session entries in author's journal. Sessions covered:
marketplace builds, security audits, CSS debugging, multi-agent
orchestration, Firestore migrations, llms.txt engineering, framework
design. Each principle above traces to ≥3 incidents across ≥2 different
domain types.

Single-domain principles (e.g., "specific Tailwind v4 quirk") were filtered
out; only patterns that transferred across ≥2 domains made the cut.
