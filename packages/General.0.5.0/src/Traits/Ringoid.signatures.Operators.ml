module type S0 = sig
  type t

  val (~+): t -> t
  val (~-): t -> t
  val (+): t -> t -> t
  val (-): t -> t -> t
  val ( * ): t -> t -> t
  val (/): t -> t -> t

  val ( ** ): t -> int -> t
end