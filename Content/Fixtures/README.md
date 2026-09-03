# Development fixtures

Fixtures in this directory are synthetic, repository-safe inputs for validating content contracts and tooling. They are not production artwork or Museum 1 release assets.

The fixture bundle contains one Museum and one Gallery with exactly four Artworks covering every supported Repair Fragment cardinality:

```text
Artwork 1 → 1 Fragment
Artwork 2 → 2 Fragments
Artwork 3 → 3 Fragments
Artwork 4 → 4 Fragments
Total     → 10 Fragments / 10 PuzzleDefinitions
```

- `m1-g1-a01-f01/puzzle-definition.json` is the representative formal, unassisted 5×5 two-color puzzle.
- The other nine puzzles are intentionally minimal 1×1 inputs. Their purpose is relationship/cardinality validation, not difficulty calibration.
- Every PuzzleDefinition has a unique ID and exactly one owning RepairFragment. Repeated puzzle semantics may share the same semantic hash because identity fields are intentionally excluded from that hash.
- Every Artwork includes matching `bead-pattern-v1` and `blueprint-v1` fixtures. Root `production-assets.json` explicitly selects each active revision; `make validate-product` also creates a temporary second revision and verifies manifest-driven activation and rollback.

Run `make validate-fixture` from the repository root to validate the entire tree.