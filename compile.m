function compile

mex -O AmapMex.c Kmeans.c Amap.c MrfPrior.c Pve.c vollib.c

try % try OpenMP support
    if strcmp(mexext,'mexmaci64')
        mex CC='gcc-4.2' CFLAGS='-fopenmp -m64 -fPIC -O3' -O -lgomp sanlmMex.c sanlm.c
    elseif strcmp(mexext,'mexmaci')
        mex CC='gcc-4.2' CFLAGS=' -m32 -fPIC -O3' -O sanlmMex.c sanlm.c
    elseif strcmp(mexext,'mexa64')
        mex CFLAGS='-fopenmp -m64 -fPIC -O3' -O -lgomp sanlmMex.c sanlm.c
    elseif strcmp(mexext,'mexglx')
        mex CFLAGS='-fopenmp -m32 -fPIC -O3' -O -lgomp sanlmMex.c sanlm.c
    elseif strcmp(mexext,'mexw64')
        mex -O sanlmMex.c sanlm.c
    elseif strcmp(mexext,'mexw32')
        mex -O sanlmMex.c sanlm.c
    end
    disp('Compiling sanlmMex with OpenMP')
catch 
    disp('Compiling sanlmMex without OpenMP')
    mex CFLAGS='-fPIC -O3' -O sanlmMex.c sanlm.c 
end