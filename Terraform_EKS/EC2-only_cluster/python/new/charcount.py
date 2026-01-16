
def char_frequency(s: str, *, case_sensitive: bool = False, include_spaces: bool = True):
    """
    Returns a dict mapping each character to its occurrence count.

    Args:
        s (str): Input string.
        case_sensitive (bool): If False, counts are case-insensitive.
        include_spaces (bool): If False, spaces are ignored.

    Returns:
        dict: {character: count}
    """
    if s is None:
        s = ""
    if not isinstance(s, str):
        s = str(s)

    # Normalize case if needed
    if not case_sensitive:
        s = s.lower()

    freq = {}
    for ch in s:
        if not include_spaces and ch.isspace():
            continue
        # increment count without libraries
        if ch in freq:
            freq[ch] += 1
        else:
            freq[ch] = 1

    return freq


# -------- Usage Examples --------
var1 = "Hello world"

# 1) Case-insensitive, include spaces (default)
result1 = char_frequency(var1)
print("Case-insensitive, include spaces:", result1)

# 2) Case-sensitive, include spaces
result2 = char_frequency(var1, case_sensitive=True)
print("Case-sensitive, include spaces:", result2)

# 3) Case-insensitive, ignore spaces
result3 = char_frequency(var1, include_spaces=False)
print("Case-insensitive, ignore spaces:", result3)

# 4) Pretty-print sorted by character (optional)
def pretty_print(freq: dict):
    for ch in sorted(freq.keys()):
        display = ch if ch != " " else "<space>"
        print(f"'{display}': {freq[ch]}")

print("\nPretty print (case-insensitive, include spaces):")
pretty_print(result1)

from collections import Counter

# Dynamic input
var1 = "Hello world"

# Normalize case (optional, based on requirement)
normalized_str = var1.lower()

# Count occurrences of each character
char_count = Counter(normalized_str)

# Display results
print("Character occurrences:")
for char, count in char_count.items():
    print(f"'{char}': {count}")

print(char_count)
print(normalized_str)

