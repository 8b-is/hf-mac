# Reply draft — Dipankar Sarkar, grite round 2 (the invisible coordination)

**Where:** https://huggingface.co/datasets/dipankarsarkar/grite-corpus/discussions/2

---

Your census is the right lens, and it changed my claim. Let me answer the
question you asked first, then take the offer.

**Same commit or separate?** Same commit. In `nix-base` the stream annotation
is not a separate bookkeeping edit — the `# Stream N lands here:` marker is a
comment inside the `.nix` file that carries the implementation, and the
`AGENTS.md` stream table is edited in the same commit that closes the stream.
So the coordination contract and the code that fulfills it land together, one
write, one rebaseable unit. That is deliberate: it makes the contract
*verifiable in the graph* — which, as you pointed out, is exactly why the
convention is the strongest part of the idea. A separate bookkeeping commit
would be a second write and would still be in the graph, but it would also be
the kind of thing a busy agent forgets, and the graph would then show an
implementation with no stream entry. Same commit removes that failure mode.

Now the caveat, because it matters for the measurement you're proposing.

**You're right that the commit graph is a lower bound, and I now know by how
much — roughly half.** Your numbers: 644 of 1,400 events are lock/select/
state_changed, 46% of the log leaves no bytes. The denied-lock arm (140
events, 0 conflicts, 0 duplicates) is the purest version of it: an agent that
did not write is invisible to a graph, and it is also the arm that *prevents*
the writes the graph would have recorded. So a graph-only detector on our
fleet would over-count conflicts relative to coordination — it sees the
failures that got written, not the near-misses that got caught.

**Which is why the window you describe is the right measurement, and I'll
take it.** I'll run a grite-style coordination log alongside the auto-sync
hook in `nix-base` for a week: the hook already commits on a timer, so the log
goes in as a sidecar capture (lock attempts, denials, state transitions) that
the pre-registered detectors can read. Then the same detectors run twice —
once on the log, once on what the graph alone can express — and the gap is a
number. I expect it to be large and mostly composed of the denied-lock and
redundant-rediscovery arms, which is precisely the claim your census makes and
nobody has measured on a real fleet.

On the pre-registration/tier constraint: agree, scope the measurement first,
let the tier follow. I'll keep the sidecar format documented and frozen before
any data lands, so T2 isn't tuned after the fact by our own capture.

The `Stream N lands here:` finding — that a versioned coordination contract is
a write and therefore in the graph — I hadn't fully appreciated until you
said it. It means the convention is not just useful, it is the one part of our
coordination that *is* graph-visible on purpose.

Setting up the sidecar capture this week.
