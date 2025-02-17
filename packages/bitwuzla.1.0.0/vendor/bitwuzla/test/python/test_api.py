###
# Bitwuzla: Satisfiability Modulo Theories (SMT) solver.
#
# This file is part of Bitwuzla.
#
# Copyright (C) 2007-2021 by the authors listed in the AUTHORS file.
#
# See COPYING for more information on using this software.
##

import pytest
from pybitwuzla import *
import time

class BzlaEnv:
    def __init__(self):
        self.bzla = Bitwuzla()
        self.bv8 = self.bzla.mk_bv_sort(8)
        self.bv32 = self.bzla.mk_bv_sort(32)
        self.fp16 = self.bzla.mk_fp_sort(5, 11)
        self.fp32 = self.bzla.mk_fp_sort(8, 24)


@pytest.fixture
def bzla():
    return Bitwuzla()

@pytest.fixture
def env():
    return BzlaEnv()


def test_new():
    Bitwuzla()


def test_set_term(bzla):

    def termfunc(x):
        return time.time() - x > 1.0

    bzla.set_term(termfunc, [100])
    assert bzla.terminate()


def test_terminate(bzla):
    assert not bzla.terminate()

    def termfunc(x):
        return True

    bzla.set_term(termfunc, None)
    assert bzla.terminate()


def test_copyright(bzla):
    assert bzla.copyright()


def test_version(bzla):
    assert bzla.version()


def test_git_id(bzla):
    assert bzla.git_id()


def test_push(bzla):
    with pytest.raises(BitwuzlaException,
                       match=r"incremental usage not enabled"):
        bzla.push()
    bzla.set_option(Option.INCREMENTAL, True)
    bzla.push()
    bzla.push(3)


def test_pop(bzla):
    with pytest.raises(BitwuzlaException,
                       match=r"incremental usage not enabled"):
        bzla.pop()
    bzla.set_option(Option.INCREMENTAL, True)
    with pytest.raises(BitwuzlaException, match=r"number of levels to pop"):
        bzla.pop()
    bzla.push()
    bzla.pop()
    bzla.push(3)
    bzla.pop(3)


def test_assert_formula(bzla):
    # TODO
    pass


def test_check_sat(bzla):
    # TODO
    pass


def test_simplify(bzla):
    # TODO
    pass


def test_get_unsat_core(bzla):
    # TODO
    pass


def test_get_value(bzla):
    # TODO
    pass


def test_print_model(bzla):
    # TODO
    pass


def test_dump_formula(bzla):
    # TODO
    pass


def test_assume_formula(bzla):
    # TODO
    pass


def test_is_unsat_assumption(bzla):
    # TODO
    pass


def test_fixate_assumptions(bzla):
    # TODO
    pass


def test_reset_assumptions(bzla):
    # TODO
    pass


def test_get_unsat_assumptions(bzla):
    # TODO
    pass


def test_set_option(bzla):
    bzla.set_option(Option.PRODUCE_MODELS, 1)
    bzla.set_option(Option.INCREMENTAL, True)
    bzla.set_option(Option.SAT_ENGINE, "cadical")
    with pytest.raises(BitwuzlaException, match=r"invalid option value"):
        bzla.set_option(Option.SAT_ENGINE, "adical")


def test_get_option(bzla):
    bzla.set_option(Option.INCREMENTAL, True)
    assert bzla.get_option(Option.INCREMENTAL)
    bzla.set_option(Option.INCREMENTAL, False)
    assert not bzla.get_option(Option.INCREMENTAL)


def test_mk_bool_sort(bzla):
    bsort = bzla.mk_bool_sort()
    assert bsort.is_bv()
    assert bsort.bv_get_size() == 1


def test_mk_bv_sort(bzla):
    bsort = bzla.mk_bv_sort(32)
    assert bsort.is_bv()
    assert bsort.bv_get_size() == 32
    with pytest.raises(BitwuzlaException):
        bzla.mk_bv_sort(0)


def test_mk_fp_sort(bzla):
    fp16 = bzla.mk_fp_sort(5, 11)
    assert fp16.is_fp()
    fp32 = bzla.mk_fp_sort(8, 24)
    assert fp32.is_fp()


def test_mk_rm_sort(bzla):
    rmsort = bzla.mk_rm_sort()
    assert rmsort.is_rm()


def test_mk_array_sort(env):
    asort = env.bzla.mk_array_sort(env.bv32, env.bv8)
    assert asort.is_array()


def test_mk_fun_sort(env):
    fsort = env.bzla.mk_fun_sort([env.bv8, env.bv32, env.fp32], env.fp16)
    assert fsort.is_fun()


def test_mk_bv_value(bzla):
    bv_sort = bzla.mk_bv_sort(32)
    bzla.mk_bv_value(bv_sort, 123)
    bzla.mk_bv_value(bv_sort, "-123")
    bzla.mk_bv_value(bv_sort, "0x123")
    bzla.mk_bv_value(bv_sort, "#x1213")
    bzla.mk_bv_value(bv_sort, "0b101")
    bzla.mk_bv_value(bv_sort, "#b101")
    bzla.mk_bv_value(bv_sort, bin(123))
    bzla.mk_bv_value(bv_sort, hex(123))


def test_mk_bv_ones(bzla):
    bv_sort = bzla.mk_bv_sort(3)
    ones1 = bzla.mk_bv_ones(bv_sort)
    ones2 = bzla.mk_bv_value(bv_sort, -1)
    ones3 = bzla.mk_bv_value(bv_sort, "-1")
    ones4 = bzla.mk_bv_value(bv_sort, 7)
    ones5 = bzla.mk_bv_value(bv_sort, "7")
    ones6 = bzla.mk_bv_value(bv_sort, "0b111")
    ones7 = bzla.mk_bv_value(bv_sort, "#b111")
    ones8 = bzla.mk_bv_value(bv_sort, bin(7))
    assert ones1 == ones2
    assert ones2 == ones3
    assert ones3 == ones4
    assert ones4 == ones5
    assert ones5 == ones6
    assert ones6 == ones7
    assert ones7 == ones8


def test_mk_bv_min_signed(bzla):
    for i in range(16):
        bv_sort = bzla.mk_bv_sort(i+1)
        bvmin = bzla.mk_bv_min_signed(bv_sort)
        assert bvmin == bzla.mk_bv_value(bv_sort, "0b1" + "0" * i)


def test_mk_bv_max_signed(bzla):
    for i in range(16):
        bv_sort = bzla.mk_bv_sort(i+1)
        bvmax = bzla.mk_bv_max_signed(bv_sort)
        assert bvmax == bzla.mk_bv_value(bv_sort, "0b0" + "1" * i)


def test_mk_fp_value(bzla):
    try:
        rne = bzla.mk_rm_value(RoundingMode.RNE)
        fp16 = bzla.mk_fp_sort(5, 16)
        bzla.mk_fp_value(fp16, 0, 15, 1234)
        bzla.mk_fp_value(fp16, "1", 0b1100, "#b1110010010")
        bzla.mk_fp_value_from(fp16, rne, 0.31213)
        bzla.mk_fp_value_from(fp16, rne, 1/3)
        bzla.mk_fp_value_from(fp16, rne, "1/3")
        bzla.mk_fp_value_from(fp16, rne, "1.2/-3.03")
        bzla.mk_fp_value_from(fp16, rne, "-.123")

        with pytest.raises(BitwuzlaException, match=r"invalid value"):
            bzla.mk_fp_value_from(fp16, rne, "0..1")

    except BitwuzlaException as e:
        assert "SymFPU not configured" in e.msg


def test_mk_fp_pos_zero(bzla):
    try:
        fp32 = bzla.mk_fp_sort(8, 24)
        v = bzla.mk_fp_pos_zero(fp32)
        assert v.is_fp_value_pos_zero()
    except BitwuzlaException as e:
        assert "SymFPU not configured" in e.msg


def test_mk_fp_neg_zero(bzla):
    try:
        fp32 = bzla.mk_fp_sort(8, 24)
        v = bzla.mk_fp_neg_zero(fp32)
        assert v.is_fp_value_neg_zero()
    except BitwuzlaException as e:
        assert "SymFPU not configured" in e.msg


def test_mk_fp_pos_inf(bzla):
    try:
        fp32 = bzla.mk_fp_sort(8, 24)
        v = bzla.mk_fp_pos_inf(fp32)
        assert v.is_fp_value_pos_inf()
    except BitwuzlaException as e:
        assert "SymFPU not configured" in e.msg


def test_mk_fp_neg_inf(bzla):
    try:
        fp32 = bzla.mk_fp_sort(8, 24)
        v = bzla.mk_fp_neg_inf(fp32)
        assert v.is_fp_value_neg_inf()
    except BitwuzlaException as e:
        assert "SymFPU not configured" in e.msg


def test_mk_fp_nan(bzla):
    try:
        fp32 = bzla.mk_fp_sort(8, 24)
        v = bzla.mk_fp_nan(fp32)
        assert v.is_fp_value_nan()
    except BitwuzlaException as e:
        assert "SymFPU not configured" in e.msg

def test_mk_rm_value(bzla):
    try:
        rne = bzla.mk_rm_value(RoundingMode.RNE)
        assert rne.is_rm_value()
        rna = bzla.mk_rm_value(RoundingMode.RNA)
        assert rna.is_rm_value()
        rtn = bzla.mk_rm_value(RoundingMode.RTN)
        assert rtn.is_rm_value()
        rtp = bzla.mk_rm_value(RoundingMode.RTP)
        assert rtp.is_rm_value()
        rtz = bzla.mk_rm_value(RoundingMode.RTZ)
        assert rtz.is_rm_value()
    except BitwuzlaException as e:
        assert "SymFPU not configured" in e.msg


def test_mk_const(env):
    c1 = env.bzla.mk_const(env.bv8)
    c2 = env.bzla.mk_const(env.bv32)
    assert c1.is_const()
    assert c2.is_const()
    try:
        c3 = env.bzla.mk_const(env.fp32)
        assert c3.is_const()
    except BitwuzlaException as e:
        assert "SymFPU not configured" in e.msg


def test_mk_const_array(env):
    asort = env.bzla.mk_array_sort(env.bv32, env.bv8)
    val = env.bzla.mk_bv_value(env.bv8, 0)
    a = env.bzla.mk_const_array(asort, val)
    assert a.is_const_array()
    try:
        asort = env.bzla.mk_array_sort(env.fp32, env.fp16)
        val = env.bzla.mk_fp_pos_zero(env.fp16)
        a = env.bzla.mk_const_array(asort, val)
        assert a.is_const_array()
    except BitwuzlaException as e:
        assert "SymFPU not configured" in e.msg


def test_mk_var(env):
    v1 = env.bzla.mk_var(env.bv8)
    v2 = env.bzla.mk_var(env.bv32)
    assert v1.is_var()
    assert v2.is_var()
    try:
        v3 = env.bzla.mk_var(env.fp32)
        assert v3.is_var()
    except BitwuzlaException as e:
        assert "SymFPU not configured" in e.msg


def test_mk_term(env):
    c1 = env.bzla.mk_const(env.bv32)
    c2 = env.bzla.mk_const(env.bv32)
    t1 = env.bzla.mk_term(Kind.DISTINCT, [c1, c2])
    t2 = env.bzla.mk_term(Kind.BV_NEG, [c1])
    t3 = env.bzla.mk_term(Kind.BV_ADD, (t2,c1,t2))
    t4 = env.bzla.mk_term(Kind.BV_EXTRACT, [t3], [15, 0])
    try:
        rne = env.bzla.mk_rm_value(RoundingMode.RNE)
        t5 = env.bzla.mk_term(Kind.FP_TO_FP_FROM_BV, [t3], [8, 24])
        t6 = env.bzla.mk_term(Kind.FP_TO_SBV, [rne, t5], [32])
        t7 = env.bzla.mk_term(Kind.FP_TO_UBV, [rne, t5], [32])
    except BitwuzlaException as e:
        assert "SymFPU not configured" in e.msg


def test_substitute(env):
    x = env.bzla.mk_var(env.bv32)
    y = env.bzla.mk_var(env.bv32)
    a = env.bzla.mk_const(env.bv32)
    b = env.bzla.mk_const(env.bv32)

    fsort = env.bzla.mk_fun_sort([env.bv32], env.bzla.mk_bool_sort())
    P = env.bzla.mk_const(fsort)
    P_x = env.bzla.mk_term(Kind.APPLY, [P, x])
    P_y = env.bzla.mk_term(Kind.APPLY, [P, y])
    P_a = env.bzla.mk_term(Kind.APPLY, [P, a])
    P_b = env.bzla.mk_term(Kind.APPLY, [P, b])
    t = env.bzla.substitute(P_x, {x: a})
    assert t == P_a

    terms = env.bzla.substitute([P_x, P_y], {x: a, y: b})
    assert terms == [P_a, P_b]



# BitwuzlaSort tests
# TODO

# BitwuzlaTerm tests
# TODO
