# PROJECT 1: NAND Gates
This project is an implementation of dynamically loadable C library for creating and managing Boolean circuits composed of NAND gates.

## Overview

- The library interface is defined in the provided `nand.h` file.
- The implementation of this library can be found in the `nand.c` file.
- Check the `nand_example.c` file for detailed usage examples and further specifications.

## Testing
To run example tests:
```bash
export LD_LIBRARY_PATH=./
make
./test.sh
make clean
