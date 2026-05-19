# Change Policy

> This document defines the only legitimate process for modifying any document in this specification.
> Changes made outside this process are not recognized.

---

## Why a Change Policy Exists

This specification is not a living blog post. It defines a trust model, a security boundary, and an architectural contract that real systems depend on.

Undisciplined changes to this specification can:

- Break the trust model without anyone noticing
- Introduce scope creep that degrades security
- Create inconsistencies between documents
- Allow "just this once" exceptions to become permanent policies

The change policy prevents that.

---

## Change Types and Approval Requirements

### Type 1: PATCH Change (Editorial)

**What it covers**: Typos, grammar, formatting, adding clarifying examples that don't change meaning.

**Approval required**: Self-review by the author. No external sign-off required.

**Version bump**: PATCH (e.g., 0.1.0 → 0.1.1)

**Process**:

1. Make the edit
2. Write a commit message: `docs(patch): [brief description]`
3. Update `VERSIONING.md` changelog

---

### Type 2: MINOR Change (Additive)

**What it covers**: Adding a new capability definition, adding a new server contract, adding a new domain boundary document, adding new allowed actions that do not conflict with existing forbidden actions.

**Approval required**: Architect review (the person who authored the original specification or their designated successor). Written approval must be recorded.

**Version bump**: MINOR (e.g., 0.1.0 → 0.2.0)

**Process**:

1. Open a Change Proposal (see template below)
2. Identify all documents that must change
3. Confirm no axioms are violated
4. Confirm no forbidden actions become allowed
5. Obtain written architect approval
6. Apply changes atomically (all files in one commit)
7. Write a commit message: `feat(arch): [brief description]`
8. Update `VERSIONING.md` changelog

---

### Type 3: MAJOR Change (Breaking)

**What it covers**: Any change to an axiom, any change to the trust hierarchy, any change to the definition of a failure class, any removal of a forbidden action, any change to the signing model.

**Approval required**: Owner approval (human owner of the system). Full architectural review. Written record of rationale.

**Version bump**: MAJOR (e.g., 0.1.0 → 1.0.0)

**Process**:

1. Open a Change Proposal with full impact analysis
2. Document which axiom or principle is being changed and why
3. Enumerate every document affected
4. Obtain written owner approval with explicit acknowledgment of the risk
5. Apply changes atomically
6. Write a commit message: `breaking(arch): [brief description]`
7. Update `VERSIONING.md` changelog with detailed rationale

---

## Change Proposal Template

```txt
## Change Proposal

**Date**: YYYY-MM-DD
**Author**: [Name / Role]
**Type**: PATCH | MINOR | MAJOR
**Target Version**: X.Y.Z

### Summary
[One paragraph: what is changing and why]

### Documents Affected
- [file path] — [what changes]

### Axioms Impacted
[List any axioms that this change touches, or "None"]

### Forbidden Actions Affected
[List any forbidden actions that become allowed, or "None"]

### Risk Assessment
[What could go wrong if this change is incorrect?]

### Approval
- [ ] Author reviewed
- [ ] Architect reviewed (for MINOR and MAJOR)
- [ ] Owner approved (for MAJOR only)
```

---

## What Cannot Be Changed (Ever)

The following cannot be modified regardless of approval level. They can only be superseded by creating an entirely new specification that explicitly deprecates this one:

1. The prohibition on the mobile agent making business decisions
2. The prohibition on plaintext secret storage
3. The requirement that all server responses be signed
4. The prohibition on communication with unpaired systems
5. The Clean Architecture layering constraint (Domain ↛ Flutter)

If a proposal requires changing any of the above five items, it is not a change to this specification — it is a proposal for a different system entirely.

---

## Enforcement

Any document in this repository that was changed without following this policy is considered **invalid** and must be reverted to its last policy-compliant version before it is treated as authoritative.
