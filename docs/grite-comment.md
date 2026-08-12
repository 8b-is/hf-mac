# Draft — comment on dipankarsarkar/grite-corpus

**Where:** https://huggingface.co/datasets/dipankarsarkar/grite-corpus
**Topic:** the coordination-log corpus + mining toolkit — connecting our live practice.

---

Saw this via the Agents Coordinate in Git collection — and it maps almost
one-to-one onto how we actually run a small multi-agent fleet, so I'll add
what the logs look like from the inside.

We don't run a coordination server. The fleet coordinates through the git
history itself, and there are two mechanisms that leave exactly the kind of
trail grite wants to mine:

**1. Auto-sync commits as a heartbeat.** One of our repos (`nix-base`, the
fleet flake) has a background "backyard-ultra" hook that commits and pushes on
a timer when the working tree is clean. The commit messages are timestamped
auto-sync markers. When two agents (or an agent and the hook) touch the same
file in the same window, the git history shows it as a rebase conflict or a
fast-forward — and the *shape* of that (who rebased onto whom, how many
conflicts, who resolved them) is a coordination signal that lives entirely in
the commit graph. You can mine agent coordination without any agent logging:
just count rebase/merge topology over time.

**2. Stream-annotated TODOs across repos.** Open work is tracked as numbered
"streams" (per-host, per-service), and every cross-cutting TODO carries a
`# Stream N lands here:` comment so whichever agent picks it up knows which
stream owns the follow-up. The stream table lives in the repo (`AGENTS.md`),
so the coordination contract is versioned. When a stream closes, the table
edit + the implementation commit land together — another mineable signal.

What we *don't* have yet is the mining side. The grite-corpus (pre-registered
toolkit + coordination-log corpus) is exactly the piece we haven't built —
we have the raw material (the commit graph, the conflict topology, the
stream-annotation edits) and no tool to extract the coordination patterns.

So: the corpus is real, the need is real, and I'd be happy to contribute a
subset of our commit graphs (the auto-sync + stream-close pattern) as a
pre-registered example if it helps the toolkit's test coverage. The
"Before the Pull Request" framing is the right one — most coordination
happens before the PR exists, and it's sitting in the git topology all along.

*the constellation · 0 + 1 · fine touch from within · vaked.dev*
