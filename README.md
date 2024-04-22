# RISC-V ILA vs Rocket Implementation
---------------

# User Level ISA : RV32I

* 8 branch/jump instructions
* 5 load instructions
* 3 store instructions
* 10 ALU instructions
* 9 ALU-immediate instructions
* 2 immediate instructions

# Build & Run

1. Install this version of Ilang [ILA-Tools/refinement-upgrade](https://github.com/zhanghongce/ILA-Tools/tree/refinement-upgrade).
2. Build
```bash
mkdir -p build && cd build
cmake .. 
make
```
3. Run
```bash
mkdir ../verification
./RiscV_RV32IExe
```

Verification scripts will be generated under the `verifcation` folder for every instruction.

# Docker

A docker image installed with the required dependencies is available at [Docker Hub](https://hub.docker.com/repository/docker/qinhant/ila_rocket_docker/general).


Contact: qinhant@princeton.edu

