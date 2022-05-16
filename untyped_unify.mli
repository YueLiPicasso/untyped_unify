(**  We propose a perspective to view OCaml runtime values as first-order terms, and provide an algorithm for their unification. There are also pretty-printers for inspecting the values and the results of unification.  
      @author   LI YUE 
     @version v1.0.0 *)
(**
    {2 Introduction } 

   A term in first-order logic is built from constants (a, b, ...), 
   variables (x, y, ...) and functions (f, g, ...) by 
   application.  Examples of first-order terms are: x, a, f(x) and
   g(f(x), g(b)).

   An OCaml runtime value ({i value} for short) is either an {i integer} or 
   a {i block}. Integers are runtime
   memory representations of integer numbers (0, -1, 1, etc.), constant 
   constructors ([[]], [()], [None], [true], [false], etc.) and 
   characters (['a'], ['A'], etc.). Blocks are runtime memory representations
   of floating-point numbers, character strings, tuples, records, arrays, 
   constructed variant values ([Some 1], [[1]], etc.), polymorphic variants, 
   functions and objects, etc. An interger is a single machine word, while
   a block is a contiguous section of machine words, starting with a word 
   known as the {i header} which specifies the {i tag} and {i size} of the
   block. The size says how many words are there in the block excluding the 
   header, and the tag indicates the structure of the block.

   A tag is an integer within the range 0 to 255 inclusive. 
   The majority of the tags (0~245) are 
   {i non-constant constructor (NCC) tags} . A block with an NCC tag 
   is called an {i algebraic block} because of its connection with algebraic types (tuple, record and variant). All algebraic blocks share a common organization, 
   viz. all the words (except the header) in the block, aka. the {i fields},
   are guaranteed to be values.  For blocks with other tags, such as 
    closure tag (247),  infix tag (249),  string tag (252), etc., they have unique
   organization so that there are fields that shall not be regarded as values.
   For instance, the fields of a string-tag block are to be examined bytewise 
   for the string characers; the fields of a closure-tag block inevitablly contain 
   pointers to machine instructions that perform the closure's functionality; 
   in both cases such fields conceptually are not values.  

   Values can be viewed as first-order terms. We first designate certain values as variables  --- we can have an abundant supply of them. Then, we can allow variables to occur in a value as sub-structures in the same way as variables occuring in a first-order term.  We notice that it is convenient and conceptually clear to allow fields of algebraic blocks to be variables; but for other kinds of blocks as well as integers, it is impossible, inconvenient or conceptually challenging for them to contain variables, so they can be regarded as constants.  Precisely, all integers, as well as blocks with the ten tags 246 ~ 255 are defined to be {i non-analytic}. Non-analytic values correspond to constants of first-order terms. Two non-analytic values are considered to be identical by the unification algorithm {!val:unify} if they are physically equal (for closure tag and infix tag) or structurally equal (for integers and blocks with the other eight tags).  See [Stdlib.(=)] for structural equality and [Stdlib.(==)] for physical equality. 
   
We have now completed our partition of values into algebraic blocks and non-analytic values following an exhaustive examination of all possible values. The correspondence between values and first-order terms is summarized as follows:

- {e first-order term entities -  values} 
- variables - certain designated values
- constants - non-analytic values
- function applications - algebraic blocks 
*)

(** {2 Variables} *)

(** @return a unique variable that can be used anywhere. Each variable 
    is assigned an integer number called its {i identifier}. *)
val v : unit -> 'a
  
(** For example, we construct a list of integers where the second element is an unknown 
integer (a variable), and use the {!val:show} function to get a string describing 
the structure of the datum as it resides on memory: {v # show [1;v();2];;
- : string = "C0((1)(C0((<v1>)(C0((2)(0))))))" v} The string says that the value is an algebraic bock with tag 0, indicated by the toplevel [C0(...)]; it has two fields, the first of which is integer 1, indicated by [(1)]; the second field is again an algebraic block with tag 0, whose first field is a variable with identifier 1, indicated by [(<v1>)]; the rest of the string is interpreted similarly. *)

(** @return [true] if the argument is a variable; [false] otherwise. *)
val check : 'a -> bool

(** @return the identifier if the argument is a variable. 
    @raise Invalid_argument ["Not a variable"] if the argument 
    is not a variable. *)
val get_id : 'a -> int


(** @return the result of variable identifier comparison wrapped in [Some] when
    both arguments are variables; otherwise  [None]. *)
val compare : 'a -> 'b -> int option

(** Type for substitution of variables. Conceptutally a substitution is an 
association list relating variables to values. *)
type subst


(** {2 Pretty-printers }*)
(**  A  printer for values that may contain variables.  *)
val show : 'a -> string
(** @return  a string that describes the structure of the argument as it resides on memory. An algebraic block with tag x and n+1 fields is shown as "Cx((f{_0})...(f{_n}))" where f{_0}...f{_n} are sub-strings describing the fields. An integer is shown by its decimal notation. A variable with identifier x is shown as "<vx>".  *)

(**
Some examples of interpreting the results of {!val:show} :  
     - ["C6((1)(<fun>)(<obj>))"] : an algebraic block with tag 6 and three fields; the first field  is the integer 1; the second field (shown by sub-string ["<fun>"]) is  a block with the closure or infix tag; the third field (["<obj>"]) is  a block with the object tag. 
     - ["<lazy>"] : a block with the lazy or forward tag.
     - ["<abs>"] : a block with the abstract tag.
     - ["str:<hello>"] (resp.  ["<empty-str>"] ): a block with the string tag holding the string ["hello"] (resp. the empty string [""]) .
     - ["C0((5.4)(int64<-7>))"] : an algebraic block with tag 0 and two fields; the first field is a block with the double tag holding the floating point number 5.4; the second field is a block with the custom tag holding the 32 or 64 bit signed integer -7. 
     - ["\[|1.0;1.1|\]"] : a block with the double array tag holding the floating point numbers 1.0 and 1.1.
     - ["<v4>"] : a variable with identifier 4.
     - ["10"]: the integer 10. 
*)


(** A printer for substitutions. @return a string of the form "<v1> / value, <v2> / value, ...". *)
val shows : subst -> string 


(** {2 Unification} *)
    
(** Unification is the operation of comparing two values (each may contain variables) and deciding if there is a way to make them {i equal } (the sense of equality is to be explained next)  by substituting values for variables; if so,  a substitution shall be given; otherwise there shall be an exception explaining the impossibility. The sense of equality here is a matter of definition and is specified by the unification algorithm itself: two variables are equal if they have the same identifier; two functions are equal if they are physically equal; two non-analytic values (not both functions) are equal if they are structurally  equal; two algebraic blocks are equal if they have the same tag and size, and all their fields are correspondingly equal by a recursive invocation of this sense of equality. A variable can always be unified with (viz. be made equal to) a value by a straightforward substitution (It is allowed that the variable occurs in the value. In terms of logic programming, we do not perform occurs check; this permits circular values and is again a matter of definition). Unification of two equal values produces the empty substitution. *)



(**  @raise Failure ["block size/tag mismatch"] if and only if there are two blocks of different sizes or tags.  @raise Failure ["function physical disequality"] only if there are two physically distinct functions.
@raise Failure ["non-analytic value mismatch"] only if there are two non-analytic values (not both functions) that are {i not } structurally equal.  
 *)
val unify : 'a -> 'b -> subst 

(** {b Examples} {v
# shows @@ unify (v()) 1;;
- : string = "<v0> / 1"
# shows @@ unify false '\000';;
- : string = ""
# shows @@ unify (1, v()) [1;2;3];;
- : string = "<v1> / C0((2)(C0((3)(0))))"
# shows @@ unify (Some (object val name : string = "Foo" end)) (Some (v()));;
- : string = "<v2> / <obj>"
# unify (+) (+);;
Exception: Failure "function physical disequality".
# let f = (+) 1 in unify f incr;;
Exception: Failure "block size/tag mismatch".
v}

The boolean [false] and the NULL character ['\000'] unify because they are both represented by the integer 0 at runtime. The tuple [(1, v())] and the list [[1;2;3]] unify (with a substitution) because they are both blocks with tag 0 and two fields, with the first fields equal and the second fields equitable by a variable substitution. *)

