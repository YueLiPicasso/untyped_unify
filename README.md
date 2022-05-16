# Untyped Unification of OCaml Runtime Values

We propose a perspective to view OCaml runtime values as first-order terms, and provide an algorithm for their unification. There are also pretty-printers for inspecting the values and the results of unification.

[Online doc/tutorial](https://yuelipicasso.github.io/untyped_unify_doc/Untyped_unify.html).

Build documentation:
```
make doc
```
Build bytecode object file:
```
make
```
Test the module (in OCaml REPL)
```ocaml
# #load "untyped_unify.cmo";;
# open Untyped_unify;;
# shows @@ unify [1;v()] [v();2];; 
- : string = "<v1> / 2 , <v0> / 1"
```
