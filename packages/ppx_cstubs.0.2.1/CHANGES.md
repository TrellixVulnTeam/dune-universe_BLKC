0.2.1 (12/08/2019)
------------------

- support OCaml 4.09.0+beta1

- bump internally used AST version from 4.06 to 4.08


0.2.0 (13/07/2019)
------------------

- ppx_cstubs now compiles with OCaml 4.08.0.

- Add support for static callbacks as an alternative to the libffi
  based `Foreign.funptr`.

- Allow to use abstract values (similar to `Ctypes.abstract`) and
  integers of unknown size and signedness.


0.1.0 (24/04/2019)
------------------

- First initial release