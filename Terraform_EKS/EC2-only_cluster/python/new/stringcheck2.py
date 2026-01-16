
def occurance(s):
    counts = {}
    duplicates = []
    
    for ch in s: #################checking the occurance
        if ch in counts:
            counts[ch] += 1
        else:
            counts[ch] = 1

    for i, count in counts.items(): #################counting the occurance to check duplicates
        if count > 1:
            duplicates.append(i)
    return duplicates

s = "P@ssw00rd 123!!"
occ = occurance(s)

print("Input:", s)
print(f"duplicates: {occ}")


