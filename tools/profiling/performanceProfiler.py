import string
import sys
import os
import subprocess
import datetime
import argparse

# Parser arguments defaults
absLayer = "SYCL"
branch = "master"

mgProcesses = ["ee_mumu", "gg_tt", "gg_ttg", "gg_ttgg", "gg_ttggg"]

doublePrecisionConstant = 2560
#doublePrecisionConstant = 1
iterations = 10
#iterations = 1
threadsPerBlock = [256]
#threadsPerBlock = [32]
blocksPerGrid = [16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384]
#blocksPerGrid = [32]

# Parser
parser = argparse.ArgumentParser(description='A program for profiling GPUs using MadGraph.')

parser.add_argument("-l", help="Choose which abstraction layer you want to use (CUDA/SYCL).", default=absLayer)
parser.add_argument("-b", help="Choose which branch the madgraph4gpu repo is in.", default=branch)

#Add profiler option in python and build scripts so that correct gcc toolchain can be set through makefile and still not disturb the compilation on Github machines

pyArgs = parser.parse_args()

# How many runs in total the program made
count = 0

for process in mgProcesses:
    for TPB in threadsPerBlock:
        for BPG in blocksPerGrid:
            if (TPB * BPG > doublePrecisionConstant):

                if pyArgs.l.upper() == 'SYCL':

                    if ".sa" not in process:
                        process = process + ".sa"

                    bashArgs = ["./buildSYCLProcess.sh", "-n",  process, "-i",  str(iterations), "-t",  str(TPB), "-b", str(BPG), "-r", str(pyArgs.b).lower()]

                elif pyArgs.l.upper() == 'CUDA':

                    # There is no .sa in br_golden_epochX4 so it makes sure that .sa is included in everything other than that branch
                    #if pyArgs.b != 'br_golden_epochX4':
                    if ".sa" not in process:
                        process = process + ".sa"
                    
                    bashArgs = ["./buildCUDAProcess.sh", "-n",  process, "-i",  str(iterations), "-t",  str(TPB), "-b", str(BPG), "-r", str(pyArgs.b).lower()]

                    #if len(pyArgs.b) > 0:
                    #    bashArgs.append('--branch')
                    #    bashArgs.append(str(pyArgs.b).lower())

                else: sys.exit("No abstraction layer matching the supplied string!")

                print(str(datetime.datetime.now().strftime("%H:%M:%S")) + " Started " + process + " with TPB("+ str(TPB) +") * BPG("+ str(BPG) +"): " + str(TPB * BPG) + "!")
                
                build = subprocess.run(bashArgs)#, stdout=subprocess.DEVNULL)
                if build.returncode != 0:
                    print(str(datetime.datetime.now().strftime("%H:%M:%S")) + " " + process + " FAILED!, threadsPerBlock: " + str(TPB) + ", blocksPerGrid: " + str(BPG) + ", Product: " + str(TPB * BPG))
                else:
                    print(str(datetime.datetime.now().strftime("%H:%M:%S")) + " " + process + " COMPLETED!, threadsPerBlock: " + str(TPB) + ", blocksPerGrid: " + str(BPG) + ", Product: " + str(TPB * BPG))
                count += 1

print("Builded " + str(count) + " processes!")