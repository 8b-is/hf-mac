# Reply draft — Dipankar Sarkar, round 3 (the 68-file seam)

**Where:** https://huggingface.co/posts/PeetPedro/262939583903899#6a7c212dcd82dc20448a5a42

---

You found the real one. The seam is mine to own: the ULTRA re-export was pushed
in four chunks (the first three covering m000–m099), and the fourth chunk
(m100–m167) was interrupted by a network failure on the push. My check only
confirmed the files existed on the Hub — it did not compare their contents
against the local export. So the Hub kept the prior 3.2862-era files for
m100–m167, and the repo became two checkpoints stacked with the seam through
layer 9. The byte-count mismatch you found is exactly the signal.

To your question: the push failed quietly (network), the export itself
completed all 168 locally and reported success. Re-pushing is the fix.

What I'm doing now:

1. **Re-push m100–m167** from the current (1.6998) export so the Hub is one
   checkpoint again — verified by content, not existence.
2. **Add a per-matrix sha256 to index.json** for all 168 files. You're right
   that the only integrity signal on 168 of 171 files was a byte count, and a
   byte count is what caught this. A sha256 per matrix catches it at push
   time instead. The export tooling will emit it.
3. **The benchmarks mirror.** The `kompress-ultra-bitnet-benchmarks` *model*
   mirror is stale (round-2 fixes only reached the dataset). I'll align the
   model mirror with the dataset — or drop it and add the dataset to
   `quantal-ternary`'s `datasets:` list, which is the cleaner single edit you
   suggested. The model mirror carries no weights, so dropping it loses
   nothing.
4. **A training note.** The `quantal_model.safetensors` (1.6998) is on the
   Hub, and a fresh continued-train is running right now — masked val already
   at 0.71 (from 11.34 on the old protocol). When it finishes, the re-export
   will be from *that* checkpoint, and the whole 168-matrix set lands in one
   verified commit.

The index.json now saying `export_complete: true` while the tree was
incomplete is a fair charge — that flag now means nothing until the per-matrix
hashes pass. I'll tighten it to be set only after the content check.

Thanks — this one was worth more than the first two combined.
