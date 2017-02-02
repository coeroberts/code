import sys
FILE_DIRECTORY=sys.argv[1]
FILE=FILE_DIRECTORY+"/dummy.csv"
print("FILE NAME")
print(FILE)
print("i am running Matt was here")
with open(FILE,'w') as f:
    f.write("hello")
