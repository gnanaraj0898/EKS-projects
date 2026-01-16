
def count_occurrences(s: str):
    counts = {}
    trace = []
    for ch in s:
        before = counts.get(ch, 0)
        counts[ch] = before + 1
        trace.append(f"Processing '{ch}': {before} -> {counts[ch]}")
    return counts, trace

s = "P@ssw0rd 123!!"
print("Input:", s)

occ, occ_trace = count_occurrences(s)
print("\n1) Occurrences:")
for line in occ_trace:
    print("   ", line)
print("   Final counts:", occ)
