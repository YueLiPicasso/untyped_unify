(* A variable is implemented as a record value 
   posessing a secret key that is used to distinguish 
   variables from records that are not variables.
*)
type t_impl = { key : int array ; id : int }
           
(* the serect key is the unique address of the allocated array 
*)
let key = [|1;2|]

(* variable id counter 
*)
let id = ref (-1)

(* allow variables to be used in any typing context *)
let v () = Obj.magic { key; id = (incr id; !id) } 

(* make [f] polymorphic for the type system 
*)
let polify1 : (Obj.t -> 'a) -> 'b -> 'a = fun f v ->
  f (Obj.repr v)

let polify2 : (Obj.t -> Obj.t -> 'a) -> 'b -> 'c -> 'a =  fun f v1 v2 ->
  f (Obj.repr v1) (Obj.repr v2)

let check : Obj.t -> bool = fun o ->
  (* is a block with at least two fields, the first of which is the key 
  *)
  Obj.is_block o && Obj.size o >= 2 && Obj.field o 0 == Obj.repr key

let check x = polify1 check x
    
let get_id : Obj.t -> int = fun o ->
  if check o then ((Obj.obj o) : t_impl).id
  else raise (Invalid_argument "Not a variable")

let get_id x = polify1 get_id x

let compare : Obj.t -> Obj.t -> int option = fun a b ->
  try Some (get_id a - get_id b) with
    Invalid_argument _ -> None

let compare x y = polify2 compare x y

(* To walk an object A through an association list is 
   to find the object B such that there exist pairs 
   (A, X1),(X1, X2),...,(Xn, B) in the association 
   list such that all X's and A are variables but B 
   non-variable, or all X's, A and B are variables but 
   there is no (B, Xn+1). B is just A if A non-variable
   , or A is a variable but there is no (A, X1). In 
   other words, it is  "variable collapsing". Structural
   equality is used in comparision. 
*)
let rec walk : Obj.t -> (Obj.t * Obj.t) list -> Obj.t = fun u s ->
  if check u then
    match List.assoc_opt u s with
    | None -> u
    | Some b -> walk b s
  else u

(* true if tg is non-const-constr tag 
*)
let ncc : int -> bool = fun tg ->
  tg >= Obj.first_non_constant_constructor_tag &&
  tg <= Obj.last_non_constant_constructor_tag

(* Variable substitutions are implemented as association
   lists for clarity, instead of using complicated but
   perhap mores efficient data structures such as a binary
   search tree or a hash table.
*)
type subst = (Obj.t * Obj.t) list
                
(* substitution register used internally by the 
   unification algorithm
*)
let subst : subst ref = ref [] 

(* exception raised by [unify] *)
let excp = Failure "non-analytic value mismatch"
let excp_fun = Failure "function physical disequality"
let excp_sz = Failure "block size/tag mismatch"
    
(* Cases for [unify]: 
 1 u, v are vars with the same id;
 2 u, v are vars with diff. id, or at least one of u, v is not a var;
     2.1 u is a var. Then v is var with diff. id, or v is not a var
     2.2 u is not a var. Then v is or is not a var.
         2.2.1 v is a var
         2.2.2 v is not a var
               2.2.2.1 u, v are blocks
                       2.2.2.1.1 of the same tag and size
                       2.2.2.1.2 otherwise
               2.2.2.2 At lease one of u, v is not a block
                       2.2.2.2.1 u, v are the same integer
                       2.2.2.2.2 u, v are diff. int, or one int one block 
 *)
let rec unify : Obj.t -> Obj.t -> unit = fun u v ->
  let u = walk u !subst and v = walk v !subst in
  if compare u v = Some 0 then ()                 (* 1 *)
  else if check u then subst := (u, v) :: !subst  (* 2.1 *)
  else if check v then subst := (v, u) :: !subst  (* 2.2.1 *)
  else if Obj.is_block u && Obj.is_block v then   (* 2.2.2.1 *)
    begin
      let u_tag  = Obj.tag u and u_size = Obj.size u in
      if u_tag = Obj.tag v && u_size = Obj.size v
      then (* 2.2.2.1.1 *)
        match u_tag with 
        (* analytic/algebraic blocks *)
        | tg when ncc tg 
          -> for i = 0 to u_size - 1 do unify (Obj.field u i) (Obj.field v i) done
        (* physically comparable non-analytic blocks *)
        | tg when tg = Obj.closure_tag || tg = Obj.infix_tag
          -> if u == v then () else raise excp_fun
        (* structurally comparable non-analytic blocks *)
        | _ -> if u = v then () else raise excp
      else (* 2.2.2.1.2 *)
        raise excp_sz
    end
  else if Obj.is_int u && Obj.is_int v && u = v then () (* 2.2.2.2.1 *)
  else raise  excp (* 2.2.2.2.2 *)

(* wrapper for the side-effecting unification algorithm *)
let unify u v = subst := []; unify (Obj.repr u) (Obj.repr v); !subst 


let rec show : Obj.t -> string = fun o ->  
  if Obj.is_int o then string_of_int @@ Obj.obj o
  else if Obj.is_block o then
    let tg = Obj.tag o and sz = Obj.size o in
    if tg = Obj.closure_tag || tg = Obj.infix_tag then "<fun>"
    else if tg = Obj.lazy_tag  || tg = Obj.forward_tag then "<lazy>"
    else if tg = Obj.abstract_tag then "<abs>"
    else if tg = Obj.object_tag then "<obj>"
    else if tg = Obj.string_tag then
      let str = Obj.obj o in
      if String.length str = 0 then "<empty-str>"
      else "str:<" ^ str ^ ">"
    else if tg = Obj.double_tag then string_of_float @@ Obj.obj o
    else if tg = Obj.custom_tag then "int64<" ^ (Int64.to_string @@ Obj.obj o) ^ ">"
    else if tg = Obj.double_array_tag then let str = ref "" in 
      for i = 0 to sz - 1 do
        str := !str ^ (string_of_float @@ Obj.double_field o i) ^ "; " 
      done ;
      "[|" ^ !str ^ "|]"
    else if ncc tg then
      try "<v" ^ (string_of_int @@ get_id o) ^ ">" with Invalid_argument _ ->  
        let str = ref "" in 
        for i = 0 to sz - 1 do
          str := !str ^ "(" ^ (show @@ Obj.field o i) ^ ")" 
        done ;
        "C" ^ string_of_int tg ^ "(" ^  !str ^ ")"
    else raise (Invalid_argument "impossible tag") 
  else raise (Invalid_argument "impossible value") 
   

let show v = show @@ Obj.repr v
    
let rec shows = function [] -> ""
                       | (v, u) :: [] -> show v ^ " / " ^ show u 
                       | (v, u) :: s  -> show v ^ " / " ^ show u ^ " , " ^ shows s
