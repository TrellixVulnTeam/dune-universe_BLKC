(** Test cases for [Comonad] *)

module Cases
    (F : Preface_specs.COMONAD)
    (A : Preface_qcheck.Model.T1 with type 'a t = 'a F.t)
    (T : Preface_qcheck.Sample.PACKAGE) : sig
  val cases : int -> unit Alcotest.test_case list
end
