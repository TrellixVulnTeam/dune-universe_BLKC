#include <caml/mlvalues.h>
#include <caml/alloc.h>
#include <caml/memory.h>
#include <caml/fail.h>
#include <caml/custom.h>
#include <caml/bigarray.h>

#include <string.h>
#include <secp256k1.h>
#include <secp256k1_recovery.h>

/* Accessing the secp256k1_context * part of an OCaml custom block */
#define Context_val(v) (*((secp256k1_context **) Data_custom_val(v)))

CAMLprim void
ml_secp256k1_context_destroy (value ml_ctx)
{
    secp256k1_context_destroy (Context_val (ml_ctx));
}

static struct custom_operations secp256k1_context_ops = {
    .identifier = "secp256k1_context",
    .finalize = ml_secp256k1_context_destroy,
    .compare = custom_compare_default,
    .compare_ext = custom_compare_ext_default,
    .hash = custom_hash_default,
    .serialize = custom_serialize_default,
    .deserialize = custom_deserialize_default
};

static value alloc_context (secp256k1_context *ctx) {
    value ml_ctx = alloc_custom (&secp256k1_context_ops, sizeof(secp256k1_context *),0, 1);
    Context_val(ml_ctx) = ctx;
    return ml_ctx;
}

/* Create a new secp256k1 context */
CAMLprim value
ml_secp256k1_context_create (value ml_flags)
{
    CAMLparam1 (ml_flags);

    /* Parse context flag */
    int flags = SECP256K1_CONTEXT_NONE;
    switch (Int_val (ml_flags)) {
    case 1:
        flags = SECP256K1_CONTEXT_VERIFY;
        break;
    case 2:
        flags = SECP256K1_CONTEXT_SIGN;
        break;
    case 3:
        flags = SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY;
        break;
    };

    /* Create and return context */
    secp256k1_context *ctx = secp256k1_context_create (flags);

    if (!ctx)
        caml_failwith ("ml_secp256k1_context_create");

    CAMLreturn (alloc_context(ctx));
}

/* Randomize the context */
CAMLprim value
ml_secp256k1_context_randomize (value ml_context, value ml_seed)
{
    CAMLparam2 (ml_context, ml_seed);
    CAMLreturn(Val_bool(secp256k1_context_randomize(Context_val (ml_context),
                                                    (const unsigned char*) String_val(ml_seed))));
}


/* Clone the context */
CAMLprim value
ml_secp256k1_context_clone (value ml_context)
{
    CAMLparam1 (ml_context);
    secp256k1_context *ctx = secp256k1_context_clone (Context_val (ml_context));

    if (!ctx)
        caml_failwith ("ml_secp256k1_context_clone");

    CAMLreturn (alloc_context(ctx));
}

CAMLprim value
ml_secp256k1_ec_seckey_verify (value ml_context, value ml_seckey) {
    CAMLparam2(ml_context, ml_seckey);
    CAMLreturn(Val_bool(secp256k1_ec_seckey_verify(Context_val (ml_context),
                                                   Caml_ba_data_val(ml_seckey))));
}

CAMLprim value
ml_secp256k1_ec_privkey_negate(value ml_context, value ml_sk) {
    CAMLparam2 (ml_context, ml_sk);
    int ret = secp256k1_ec_privkey_negate(Context_val (ml_context),
                                          Caml_ba_data_val(ml_sk));
    CAMLreturn(Val_unit);
}

CAMLprim value
ml_secp256k1_ec_privkey_tweak_add(value ml_context, value ml_sk, value ml_tweak) {
    CAMLparam3 (ml_context, ml_sk, ml_tweak);

    CAMLreturn(Val_bool(secp256k1_ec_privkey_tweak_add(Context_val (ml_context),
                                                       Caml_ba_data_val(ml_sk),
                                                       Caml_ba_data_val(ml_tweak))));
}

CAMLprim value
ml_secp256k1_ec_privkey_tweak_mul(value ml_context, value ml_sk, value ml_tweak) {
    CAMLparam3 (ml_context, ml_sk, ml_tweak);

    CAMLreturn(Val_bool(secp256k1_ec_privkey_tweak_mul(Context_val (ml_context),
                                                       Caml_ba_data_val(ml_sk),
                                                       Caml_ba_data_val(ml_tweak))));
}

/* Create public key */
CAMLprim value
ml_secp256k1_ec_pubkey_create (value ml_context, value ml_buf, value ml_seckey) {
    CAMLparam3 (ml_context, ml_buf, ml_seckey);

    CAMLreturn(Val_bool(secp256k1_ec_pubkey_create (Context_val (ml_context),
                                                   Caml_ba_data_val(ml_buf),
                                                   Caml_ba_data_val(ml_seckey))));
}

CAMLprim value
ml_secp256k1_ec_pubkey_serialize (value ml_context, value ml_buf, value ml_pubkey) {
    CAMLparam3 (ml_context, ml_buf, ml_pubkey);

    size_t size = Caml_ba_array_val(ml_buf)->dim[0];
    unsigned int flags =
        size == 33 ? SECP256K1_EC_COMPRESSED : SECP256K1_EC_UNCOMPRESSED;

    secp256k1_ec_pubkey_serialize(Context_val (ml_context),
                                  Caml_ba_data_val(ml_buf),
                                  &size,
                                  Caml_ba_data_val(ml_pubkey),
                                  flags);

    CAMLreturn(Val_int(size));
}

CAMLprim value
ml_secp256k1_ec_pubkey_parse(value ml_context, value ml_buf, value ml_pk) {
    CAMLparam3 (ml_context, ml_buf, ml_pk);

    CAMLreturn(Val_bool(secp256k1_ec_pubkey_parse(Context_val (ml_context),
                                                 Caml_ba_data_val(ml_buf),
                                                 Caml_ba_data_val(ml_pk),
                                                 Caml_ba_array_val(ml_pk)->dim[0])));
}

CAMLprim value
ml_secp256k1_ec_pubkey_negate(value ml_context, value ml_pk) {
    CAMLparam2 (ml_context, ml_pk);
    int ret = secp256k1_ec_pubkey_negate(Context_val (ml_context),
                                         Caml_ba_data_val(ml_pk));
    CAMLreturn(Val_unit);
}

CAMLprim value
ml_secp256k1_ec_pubkey_tweak_add(value ml_context, value ml_pk, value ml_tweak) {
    CAMLparam3 (ml_context, ml_pk, ml_tweak);

    CAMLreturn(Val_bool(secp256k1_ec_pubkey_tweak_add(Context_val (ml_context),
                                                      Caml_ba_data_val(ml_pk),
                                                      Caml_ba_data_val(ml_tweak))));
}

CAMLprim value
ml_secp256k1_ec_pubkey_tweak_mul(value ml_context, value ml_pk, value ml_tweak) {
    CAMLparam3 (ml_context, ml_pk, ml_tweak);

    CAMLreturn(Val_bool(secp256k1_ec_pubkey_tweak_mul(Context_val (ml_context),
                                                      Caml_ba_data_val(ml_pk),
                                                      Caml_ba_data_val(ml_tweak))));
}

CAMLprim value
ml_secp256k1_ec_pubkey_combine(value ml_context, value ml_out, value ml_pks) {
    CAMLparam3 (ml_context, ml_out, ml_pks);

    int size = 0;
    const secp256k1_pubkey* pks[1024] = {0};

    while(Field(ml_pks, 1) != Val_unit) {
        pks[size] = Caml_ba_data_val(Field(ml_pks, 0));
        size++;
        ml_pks = Field(ml_pks, 1);
    }

    CAMLreturn(Val_int(secp256k1_ec_pubkey_combine(Context_val (ml_context),
                                                   Caml_ba_data_val(ml_out),
                                                   pks,
                                                   size)));
}

CAMLprim value
ml_secp256k1_ecdsa_signature_parse_compact (value ml_context, value ml_buf, value ml_sig) {
    CAMLparam3 (ml_context, ml_buf, ml_sig);
    CAMLreturn(Val_bool(secp256k1_ecdsa_signature_parse_compact (Context_val (ml_context),
                                                                Caml_ba_data_val(ml_buf),
                                                                Caml_ba_data_val(ml_sig))));
}

CAMLprim value
ml_secp256k1_ecdsa_signature_parse_der (value ml_context, value ml_buf, value ml_sig) {
    CAMLparam3 (ml_context, ml_buf, ml_sig);
    CAMLreturn(Val_bool(secp256k1_ecdsa_signature_parse_der (Context_val (ml_context),
                                                            Caml_ba_data_val(ml_buf),
                                                            Caml_ba_data_val(ml_sig),
                                                            Caml_ba_array_val(ml_sig)->dim[0])));
}

/* Verify an ecdsa signature */
CAMLprim value
ml_secp256k1_ecdsa_verify (value ml_context, value ml_pubkey, value ml_msg, value ml_signature) {
    CAMLparam4 (ml_context, ml_signature, ml_msg, ml_pubkey);

    CAMLreturn(Val_bool(secp256k1_ecdsa_verify (Context_val (ml_context),
                                                Caml_ba_data_val(ml_signature),
                                                Caml_ba_data_val(ml_msg),
                                                Caml_ba_data_val(ml_pubkey))));
}


/* Sign a message with ECDSA */
CAMLprim value
ml_secp256k1_ecdsa_sign (value ml_context, value ml_buf, value ml_seckey, value ml_msg) {
    CAMLparam4(ml_context, ml_buf, ml_seckey, ml_msg);

    CAMLreturn(Val_bool(secp256k1_ecdsa_sign (Context_val (ml_context),
                                              Caml_ba_data_val(ml_buf),
                                              Caml_ba_data_val(ml_msg),
                                              Caml_ba_data_val(ml_seckey),
                                              NULL, NULL)));
}

CAMLprim value
ml_secp256k1_ecdsa_signature_serialize_der(value ml_context, value ml_buf, value ml_signature) {
    CAMLparam3 (ml_context, ml_buf, ml_signature);

    size_t size = Caml_ba_array_val(ml_buf)->dim[0];
    int ret = secp256k1_ecdsa_signature_serialize_der(Context_val (ml_context),
                                                      Caml_ba_data_val(ml_buf),
                                                      &size,
                                                      Caml_ba_data_val(ml_signature));

    CAMLreturn(ret == 0 ? Val_int(ret) : Val_int(size));
}

CAMLprim value
ml_secp256k1_ecdsa_signature_serialize_compact(value ml_context, value ml_buf, value ml_signature) {
    CAMLparam3 (ml_context, ml_buf, ml_signature);

    secp256k1_ecdsa_signature_serialize_compact(Context_val (ml_context),
                                                Caml_ba_data_val(ml_buf),
                                                Caml_ba_data_val(ml_signature));
    CAMLreturn (Val_unit);
}

CAMLprim value
ml_secp256k1_ecdsa_recoverable_signature_parse_compact (value ml_context, value ml_buf, value ml_signature, value ml_recid) {
    CAMLparam4 (ml_context, ml_buf, ml_signature, ml_recid);

    CAMLreturn(Val_bool(secp256k1_ecdsa_recoverable_signature_parse_compact (Context_val (ml_context),
                                                                             Caml_ba_data_val(ml_buf),
                                                                             Caml_ba_data_val(ml_signature),
                                                                             Int_val(ml_recid))));
}

CAMLprim value
ml_secp256k1_ecdsa_sign_recoverable (value ml_context, value ml_buf, value ml_seckey, value ml_msg) {
    CAMLparam4(ml_context, ml_buf, ml_seckey, ml_msg);

    CAMLreturn(Val_bool(secp256k1_ecdsa_sign_recoverable (Context_val (ml_context),
                                                          Caml_ba_data_val(ml_buf),
                                                          Caml_ba_data_val(ml_msg),
                                                          Caml_ba_data_val(ml_seckey),
                                                          NULL, NULL)));
}

CAMLprim value
ml_secp256k1_ecdsa_recoverable_signature_serialize_compact(value ml_context, value ml_buf, value ml_signature) {
    CAMLparam3 (ml_context, ml_buf, ml_signature);
    int recid;

    secp256k1_ecdsa_recoverable_signature_serialize_compact(Context_val (ml_context),
                                                            Caml_ba_data_val(ml_buf),
                                                            &recid,
                                                            Caml_ba_data_val(ml_signature));
    CAMLreturn(Val_int(recid));
}

CAMLprim value
ml_secp256k1_ecdsa_recoverable_signature_convert(value ml_context, value ml_buf, value ml_signature) {
    CAMLparam3 (ml_context, ml_buf, ml_signature);
    secp256k1_ecdsa_recoverable_signature_convert (Context_val (ml_context),
                                                   Caml_ba_data_val(ml_buf),
                                                   Caml_ba_data_val(ml_signature));
    CAMLreturn(Val_unit);
}

CAMLprim value
ml_secp256k1_ecdsa_recover(value ml_context, value ml_buf, value ml_signature, value ml_msg) {
    CAMLparam4 (ml_context, ml_buf, ml_signature, ml_msg);
    CAMLreturn(Val_bool(secp256k1_ecdsa_recover(Context_val (ml_context),
                                                Caml_ba_data_val(ml_buf),
                                                Caml_ba_data_val(ml_signature),
                                                Caml_ba_data_val(ml_msg))));
}