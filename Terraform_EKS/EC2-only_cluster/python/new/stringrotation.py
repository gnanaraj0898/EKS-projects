def rotate(s: str, k: int):
    n = len(s)
    k_mod = k % n
    rotated = s[k_mod:] + s[:k_mod]
    return rotated

rotated_key = rotate("Highlight@123", 4) #takes the first four letter of the string and put(rotate) it in the last
print(f"rotated string is {rotated_key}")
