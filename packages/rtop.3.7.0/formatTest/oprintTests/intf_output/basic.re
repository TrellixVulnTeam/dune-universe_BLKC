let x1: unit => int;
let x2: 'a => int;
let x3: (int, 'a) => int;
let x4: (('a, 'b)) => int;
let x5: ('a, 'b) => int;
let x6: (~x: 'a, ~y: 'b) => int;
let x7: (~x: int, ~y: string) => int;
let x8:
  (~x: int=?, ~y: 'a=?, ~z: string=?, unit) =>
  int;
type a = int;
type b = float;
type c = string;
type t1 = a => b;
type t2 = (a, b) => c;
type t3 = ((a, b)) => c;
type t4 = (~x: int, ~y: string) => c;
type t5 = (~x: a=?) => b;
type tf = (int => int) => string;
type tNested2 = (int => int) => string;
type tNested3 = ((int => int) => int) => string;
type tNested4 = (int, int) => string;
type tNested5 = ((int, int)) => string;
type t6 = int;
type t7('a) = list('a);
type t8('a, 'b) = (list('a), 'b);
type t9 = t8(string, int);
class type restricted_point_type = {
  pub bump: unit;
  pub get_x: int;
};
class type t10 ('a) = {
  pub thing: 'a;
};
class type t11 ('a, 'b) = {
  pub thing: ('a, list('b));
};
module MyFirstModule: {
  let x: int;
  type i = int
  and n = string;
};
module type HasTT = {type tt;};
module SubModule: HasTT;
module type HasEmbeddedHasTT = {
  module SubModuleThatHasTT = SubModule;
};
module type HasPolyType = {type t('a);};
module type HasDoublePoly = {type m('b, 'c);};
module type HasDestructivelySubstitutedPolyType = {

};
module type HasDestructivelySubstitutedSubPolyModule = {
  module X: HasDestructivelySubstitutedPolyType;
};
module type HasSubPolyModule = {
  module X: HasPolyType;
};
module EmbedsSubPolyModule: HasSubPolyModule;
module InliningSig: {
  let x: int;
  let y: int;
};
module MyFunctor:
  (M: HasTT) =>
   {
    type reexportedTT = M.tt;
    let someValue: int;
  };
module MyFunctorResult: {
  type reexportedTT = string;
  let someValue: int;
};
module type ASig = {let a: int;};
module type BSig = {let b: int;};
module CurriedSugar:
  (A: ASig, B: BSig) => {let result: int;};
type withThreeFields = {
  name: string,
  age: int,
  occupation: string,
};
let testRecord: withThreeFields;
let makeRecordBase: unit => withThreeFields;
type t =
  | A
  | B(int)
  | C(int, int)
  | D((int, int));
type foo = {x: int};
let result: option(foo);
type tt1 =
  | A(int)
  | B(bool, string);
type tt2 =
  | A(int)
  | B((bool, string));
type tt3 = [
  | `A(int)
  | `B(bool, string)
  | `C
];
type tt4 = [
  | `A(int)
  | `B(bool, string)
  | `C
];
let (==): int;
let (===): int;
let (!=): int;
let (!==): int;
type foobar(_) =
  | Foo('a): foobar(unit);
