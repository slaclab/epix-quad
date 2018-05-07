import numpy as np

t = np.zeros(1024, dtype=int)

#generates a ramp
for i in range (0,1024):
    t[i]=i

np.savetxt("ramp.csv", t*64-1, fmt='%d')

#generates a sin
s = np.sin(t*2*3.14159265/512)*(32767/2)+32768

np.savetxt("sin2.csv", s, fmt='%d')

