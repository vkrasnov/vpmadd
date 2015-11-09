## Big integer multiplication using the new Intel AVX512F and AVX512IFMA instructions

This repository contains sample code snippets of big integer multiplication using the Intel AVX512F and AVX512IFMA instuctions.

The snippets demonstrate the multiplication of 1024, 2048, 3072 and 4096 bit numbers, including conversion to and from redundnat form as described in [1].

The function were tested with Intel SDE, and are hopefully well optimized. Unfortunately there is no CPU that supports those instructions yet, and their performance is unknown. It is possible they will be further optimized when the processors become available.

The description of the extension can be found [here](https://software.intel.com/sites/default/files/managed/07/b7/319433-023.pdf). 

The code here is licensed under [GPL v.3](http://www.gnu.org/licenses/gpl-3.0.en.html), other licenses may be granted on request.

#### Rerference:

[1] S. Gueron, V. Krasnov, *"Accelerating Big Integer Arithmetic Using Intel IFMA Extensions"*, to be published.
