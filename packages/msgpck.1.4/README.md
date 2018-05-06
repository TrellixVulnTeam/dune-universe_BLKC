msgpck — msgpack library for OCaml
-------------------------------------------------------------------------------
%%VERSION%%

msgpck is TODO

msgpck is distributed under the ISC license.

Homepage: https://github.com/vbmithr/ocaml-msgpck 
Contact: Vincent Bernardoff `<vb@luminar.eu.org>`

## Installation

msgpck can be installed with `opam`:

    opam install msgpck

If you don't use `opam` consult the [`opam`](opam) file for build
instructions.

## Documentation

The documentation and API reference is automatically generated by
`ocamldoc` from the interfaces. It can be consulted [online][doc]
and there is a generated version in the `doc` directory of the
distribution.

[doc]: https://vbmithr.github.io/msgpck/doc

## Sample programs

If you installed msgpck with `opam` sample programs are located in
the directory `opam config var msgpck:doc`.

In the distribution sample programs and tests are located in the
[`test`](test) directory of the distribution. They can be built with:

    ocamlbuild -use-ocamlfind test/tests.otarget

The resulting binaries are in `_build/test`.

- `test.native` tests the library, nothing should fail.