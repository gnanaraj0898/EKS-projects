arr = [1, 2, 5, 46, 5, 2]
####################################################################
#sum of the array
####################################################################
total = 0
for element in arr:
    total+=element
total2 = sum(arr)
print(f"sum of the array is {total}")
print(f"sum of the array by inbuilt is {total2}")
####################################################################
#largest element in an array
####################################################################

largest = arr[0]
for element in arr:
    if element > largest:
        largest= element
print(f"largest element in the array is {largest}")

####################################################################
#array rotation
####################################################################
def array_rotation(arr, d):
    n = len(arr)
    new_array=[0]*n
    for i in range(n):
        new_array[i] = arr[(i + d) % n] # arr[(0+2)%6] > arr[2], arr[(1+2)%6] > arr[3]
    return new_array
result = array_rotation(arr, 2)
print(f"original array is {arr}")
print(f"rotated array is {result}")
####################################################################
#array split and add
####################################################################
def split_and_add(arr, k):
    new_splited_array = arr[k:] + arr[:k]
    return new_splited_array
splited_array = split_and_add(arr, 4)
print(f"splitted and added array is {splited_array}")
####################################################################
#array monotonic or not / increasing or decreasing but not random
####################################################################
def is_mono(arr):
    increasing=decreasing=True
    for i in range(1, len(arr)):
        if arr[i] > arr[i-1]:
            decreasing=False
        elif arr[i] < arr[i-1]:
            increasing = False
    return increasing or decreasing
print(f"is {arr} monotonic:", is_mono(arr))
####################################################################
#sum of the array
####################################################################
sum_of_array = 0
for i in arr:
    sum_of_array += i
print(f"sum of the array is {sum_of_array}")
####################################################################
#second largest number in array
####################################################################
arr.sort(reverse=True) #sorting in to decending and finding the second largest number
if len(arr) >= 2:
    second_largest = arr[1]
print(f"second largest number in the array is {second_largest}")
####################################################################
#second largest number in array
####################################################################
