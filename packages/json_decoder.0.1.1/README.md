A JSON Decoder based on Elm's Json.Decode
-----------------------------------------
Release v0.1.1

JSON Decoder is an OCaml module that enables flexible decoding of JSON values. It is based on Elm's Json.Decode module with a few tweaks.

This module allows you to do things like decode a field based on the type or content of some other field, or even the failure to decode some other field. It allows you to shape the results of a decode into a structure of your choice.

Rather than unpacking a JSON value directly into an analogous OCaml structure; this module helps you to massage data into the shape you want by describing the transformations that need to take place.

## Installation

JSON Decoder can be installed with `opam`:

    opam install json_decoder


## Documentation

Hosted auto-generated documentation can be found 
[here](https://dagoof.github.io/ocaml-json-decoder/doc/json_decoder)


## Examples

Until we work out better examples, check out the tests.

