a = - 41
################################################
#positive or Negative
################################################
if a > 0:
    print(f"its positive number")
elif a==0:
    print(f"its zero")
else:
    print(f"its negative number")
################################################
    #odd or even
################################################
if a%2 == 0:
    print(f"its even number")
else:
    print(f"its odd number")
################################################
# prime number ?
################################################
flag=False
if a == 1:
    print(f"{a} is a equal to one")
elif a > 1:
    for i in range(2, a):
        if (a%i) == 0:
            flag=True
            break
if flag:
    print(f"given number is not prime number")
else:
    print(f"given number is a prime number")

################################################
# prime number in a range ?
################################################
start = 1
end = 10
print(f"prime numbers between {start} and {end} are displayed")
for i in range (start, end +1):
    if i > 1:
        for num in range(2, i):
            if (i % num)==0:
                break
        else:
            print(i)
#  i = 7
# test num = 2: 7 % 2 = 1  → not a divisor
# test num = 3: 7 % 3 = 1  → not a divisor
# test num = 4: 7 % 4 = 3  → not a divisor
# test num = 5: 7 % 5 = 2  → not a divisor
# test num = 6: 7 % 6 = 1  → not a divisor
#   for-else: inner loop completed without break → print(i)
#   OUTPUT: 7
            
################################################
#display armstrong number in a range
################################################
start = 1
end = 500
print(f"displaying armstrong number between {start} to {end}")
for num in range(start, end+1):
    order=len(str(num))
    temp=num
    sum=0
    while temp > 0:
        digit=temp%10
        sum += digit**order
        temp //=10

    if num == sum:
        print(num)
