# Coqswitch

A small `sh` function to help manage the [Coq](https://coq.inria.fr) development
environment, especially to switch between a Coq repository and different opam
switches.

## Installation

Just download the `coqswitch.sh` file to some known location and source it in
your shell. It should work with any shell mostly POSIX compliant. **For
instance**, these two commands copy the `sh` file in a subdirectory `scripts` of
the home directory of the user and appends a line to source it at the end of the
user's `.bashrc` file.
```sh
curl -fLo ~/scripts/coqswitch.sh --create-dirs \
	https://raw.githubusercontent.com/Villetaneuse/coqswitch/master/coqswitch.sh
printf '. ~/scripts/coqswitch.sh\n' >>~/.bashrc
```
Then, for the `--dev` option to work, one has to export two environment
variables :
- COQREP containing the path of the local Coq repository
- OPAMCOQDEV containing the name of the opam switch one uses for Coq
  development

## Usage

Once sourced, the file `coqswitch.sh` provides the `coqswitch` shell function
(it has to be a function, not a script, because it modifies the environment)
with the following functionalities:
- `coqswitch` or `coqswitch --show` print information about the Coq programming
  environment, such as the `opam` switch, if `COQBIN` is set or not, ...
- `coqswitch Name_or_part_of_existing_switch` switches to the corresponding opam
  switch, sets `COQBIN` to the empty string and removes `COQBIN` and the
  corresponding `lib` from, respectively, the `PATH` and the `OCAMLPATH`
- `coqswitch --dev` sets `COQBIN`, `PATH` and `OCAMLPATH` to values
  corresponding to the `COQREP` variable and switches to the `OPAMCOQDEV`
  switch.

## Licence
GNU General Public License version 3 or later
