/***
 * Bitwuzla: Satisfiability Modulo Theories (SMT) solver.
 *
 * This file is part of Bitwuzla.
 *
 * Copyright (C) 2007-2021 by the authors listed in the AUTHORS file.
 *
 * See COPYING for more information on using this software.
 */
#include <type_traits>

#include "test.h"

extern "C" {
#include "bzlabv.h"
#include "bzlaclone.h"
#include "bzlacore.h"
#include "bzlaexp.h"
#include "bzlaproputils.h"
#include "bzlaslvprop.h"
}

#define TEST_PROPCONS_BW 3

using BzlaBinFun =
    std::add_pointer<BzlaNode *(Bzla *, BzlaNode *, BzlaNode *)>::type;

class TestPropCons : public TestPropCommon
{
 protected:
  void test_binary(BzlaBinFun expr_fun,
                   BzlaPropComputeValueFun cons_fun,
                   uint32_t pos_x,
                   bool fixed_bits)
  {
    uint32_t expected_result;
    Bzla *bzla;
    BzlaSortId sort_x, sort_s;
    BzlaBvDomain *d_x;
    BzlaBitVector *bv_s, *bv_t, *bv_x, *bv_cur_x;
    BzlaBvDomainGenerator gen;
    BzlaRNG *rng;
    BzlaSolver *slv_sat = nullptr, *slv_prop;
    BzlaMemMgr *mm;
    BzlaNode *x, *s, *expr, *eq_t, *c_x, *c_s, *c_t, *eq_x;
    BzlaNode *x_lo, *x_hi, *and_x, *or_x, *eq_x1, *eq_x2;
    std::vector<std::string> values_x, values_s, values_t;

    bzla = bzla_new();
    mm   = bzla->mm;

    slv_prop       = bzla_new_prop_solver(bzla);
    slv_prop->bzla = bzla;

    bzla_opt_set(bzla, BZLA_OPT_INCREMENTAL, 1);
    bzla_opt_set(bzla, BZLA_OPT_CHECK_MODEL, 0);

    if (expr_fun == bzla_exp_bv_slt)
    {
      bzla_opt_set(bzla, BZLA_OPT_RW_SLT, 0);
    }

    if (expr_fun == bzla_exp_bv_concat)
    {
      sort_x = bzla_sort_bv(bzla, TEST_PROPCONS_BW);
      sort_s = bzla_sort_bv(bzla, TEST_PROPCONS_BW - 1);
    }
    else
    {
      sort_x = bzla_sort_bv(bzla, TEST_PROPCONS_BW);
      sort_s = bzla_sort_copy(bzla, sort_x);
    }

    rng = bzla_rng_new(mm, 0);

    if (pos_x == 0)
    {
      x    = bzla_exp_var(bzla, sort_x, "x");
      s    = bzla_exp_var(bzla, sort_s, "s");
      expr = expr_fun(bzla, x, s);
    }
    else
    {
      s    = bzla_exp_var(bzla, sort_s, "s");
      x    = bzla_exp_var(bzla, sort_x, "x");
      expr = expr_fun(bzla, s, x);
    }

    bzla_sort_release(bzla, sort_x);
    bzla_sort_release(bzla, sort_s);

    gen_xvalues(bzla_node_bv_get_width(bzla, x), values_x);
    gen_values(bzla_node_bv_get_width(bzla, s), values_s);
    gen_values(bzla_node_bv_get_width(bzla, expr), values_t);

    uint64_t num_tests = 0;
    for (const std::string &xval : values_x)
    {
      d_x = bzla_bvdomain_new_from_char(mm, xval.c_str());

      if (!fixed_bits && bzla_bvdomain_has_fixed_bits(mm, d_x))
      {
        bzla_bvdomain_free(mm, d_x);
        continue;
      }

      x_lo  = bzla_exp_bv_const(bzla, d_x->lo);
      x_hi  = bzla_exp_bv_const(bzla, d_x->hi);
      and_x = bzla_exp_bv_and(bzla, x_hi, x);
      or_x  = bzla_exp_bv_or(bzla, x_lo, x);
      eq_x1 = bzla_exp_eq(bzla, and_x, x);
      eq_x2 = bzla_exp_eq(bzla, or_x, x);

      for (const std::string &sval : values_s)
      {
        bv_s = bzla_bv_char_to_bv(mm, sval.c_str());
        c_s  = bzla_exp_bv_const(bzla, bv_s);

        for (const std::string &tval : values_t)
        {
          bv_t = bzla_bv_char_to_bv(mm, tval.c_str());
          c_t  = bzla_exp_bv_const(bzla, bv_t);

          bzla_bvdomain_gen_init(mm, rng, &gen, d_x);
          while (bzla_bvdomain_gen_has_next(&gen))
          {
            ++num_tests;
            bv_cur_x = bzla_bvdomain_gen_next(&gen);

            BzlaPropInfo pi;
            memset(&pi, 0, sizeof(BzlaPropInfo));
            pi.pos_x         = pos_x;
            pi.exp           = expr;
            pi.bv[pos_x]     = bv_cur_x;
            pi.bv[1 - pos_x] = bv_s;
            pi.bvd[pos_x]    = d_x;
            pi.target_value  = bv_t;
            pi.res_x         = 0;

            bzla->slv = slv_prop;
            bv_x      = cons_fun(bzla, &pi);
            if (pi.res_x) bzla_bvdomain_free(mm, pi.res_x);

            expected_result = bv_x ? BZLA_RESULT_SAT : BZLA_RESULT_UNSAT;

            c_x = eq_x = 0;
            if (bv_x)
            {
              c_x  = bzla_exp_bv_const(bzla, bv_x);
              eq_x = bzla_exp_eq(bzla, x, c_x);
              bzla_assume_exp(bzla, eq_x);
            }

            eq_t = bzla_exp_eq(bzla, expr, c_t);

            bzla_assume_exp(bzla, eq_x1);
            bzla_assume_exp(bzla, eq_x2);
            bzla_assume_exp(bzla, eq_t);

            bzla->slv    = slv_sat;
            uint32_t res = bzla_check_sat(bzla, -1, -1);

            if (res != expected_result)
            {
              std::cout << "d_x:    ";
              bzla_bvdomain_print(mm, d_x, true);
              std::cout << "cur_x:  ";
              bzla_bv_print(bv_cur_x);
              std::cout << "s:      ";
              bzla_bv_print(bv_s);
              std::cout << "t:      ";
              bzla_bv_print(bv_t);
              std::cout << "pos_x:  " << pos_x << std::endl;
              std::cout << "cons_x: ";
              if (bv_x)
              {
                bzla_bv_print(bv_x);
              }
              else
              {
                std::cout << "none" << std::endl;
              }
            }

            assert(res == expected_result);
            ASSERT_EQ(res, expected_result);

            if (!slv_sat)
            {
              slv_sat = bzla->slv;
            }

            if (bv_x)
            {
              bzla_node_release(bzla, c_x);
              bzla_bv_free(mm, bv_x);
              bzla_node_release(bzla, eq_x);
            }

            bzla_node_release(bzla, eq_t);
          }
          bzla_bvdomain_gen_delete(&gen);
          bzla_bv_free(mm, bv_t);
          bzla_node_release(bzla, c_t);
        }

        bzla_bv_free(mm, bv_s);
        bzla_node_release(bzla, c_s);
      }

      bzla_node_release(bzla, x_lo);
      bzla_node_release(bzla, x_hi);
      bzla_node_release(bzla, and_x);
      bzla_node_release(bzla, or_x);
      bzla_node_release(bzla, eq_x1);
      bzla_node_release(bzla, eq_x2);

      bzla_bvdomain_free(mm, d_x);
    }

    bzla_node_release(bzla, x);
    bzla_node_release(bzla, s);
    bzla_node_release(bzla, expr);
    bzla->slv = slv_prop;
    slv_prop->api.delet(slv_prop);
    bzla->slv = slv_sat;
    bzla_rng_delete(rng);
    bzla_delete(bzla);
    std::stringstream ss;
    ss << "Number of tests (pos_x: " << pos_x << "): " << num_tests;
    log(ss.str());
  }

  void test_slice(BzlaPropComputeValueFun cons_fun, bool fixed_bits)
  {
    uint32_t expected_result;
    Bzla *bzla;
    BzlaSortId sort_x;
    BzlaBvDomain *d_x;
    BzlaBitVector *bv_t, *bv_x, *bv_cur_x;
    BzlaBvDomainGenerator gen;
    BzlaRNG *rng;
    BzlaSolver *slv_sat = nullptr, *slv_prop;
    BzlaMemMgr *mm;
    BzlaNode *x, *expr, *eq_t, *c_x, *c_t, *eq_x;
    BzlaNode *x_lo, *x_hi, *and_x, *or_x, *eq_x1, *eq_x2;
    std::vector<std::string> values_x;

    bzla = bzla_new();
    mm   = bzla->mm;

    slv_prop       = bzla_new_prop_solver(bzla);
    slv_prop->bzla = bzla;

    bzla_opt_set(bzla, BZLA_OPT_INCREMENTAL, 1);
    bzla_opt_set(bzla, BZLA_OPT_CHECK_MODEL, 0);

    sort_x = bzla_sort_bv(bzla, TEST_PROPCONS_BW);

    rng = bzla_rng_new(mm, 0);

    x = bzla_exp_var(bzla, sort_x, "x");
    bzla_sort_release(bzla, sort_x);

    gen_xvalues(bzla_node_bv_get_width(bzla, x), values_x);

    uint64_t num_tests = 0;
    for (const std::string &xval : values_x)
    {
      d_x = bzla_bvdomain_new_from_char(mm, xval.c_str());

      if (!fixed_bits && bzla_bvdomain_has_fixed_bits(mm, d_x))
      {
        bzla_bvdomain_free(mm, d_x);
        continue;
      }

      x_lo  = bzla_exp_bv_const(bzla, d_x->lo);
      x_hi  = bzla_exp_bv_const(bzla, d_x->hi);
      and_x = bzla_exp_bv_and(bzla, x_hi, x);
      or_x  = bzla_exp_bv_or(bzla, x_lo, x);
      eq_x1 = bzla_exp_eq(bzla, and_x, x);
      eq_x2 = bzla_exp_eq(bzla, or_x, x);

      uint32_t bw = bzla_node_bv_get_width(bzla, x);
      for (uint32_t i = 0; i < bw; ++i)
      {
        uint32_t upper = bw - i - 1;
        for (uint32_t lower = 0; lower <= upper; ++lower)
        {
          expr = bzla_exp_bv_slice(bzla, x, upper, lower);

          /* This can happen on a full slice (rewriting). */
          if (!bzla_node_is_bv_slice(expr))
          {
            bzla_node_release(bzla, expr);
            continue;
          }

          std::vector<std::string> values_t;
          gen_values(bzla_node_bv_get_width(bzla, expr), values_t);
          for (const std::string &tval : values_t)
          {
            bv_t = bzla_bv_char_to_bv(mm, tval.c_str());
            c_t  = bzla_exp_bv_const(bzla, bv_t);

            bzla_bvdomain_gen_init(mm, rng, &gen, d_x);
            while (bzla_bvdomain_gen_has_next(&gen))
            {
              ++num_tests;
              bv_cur_x = bzla_bvdomain_gen_next(&gen);

              BzlaPropInfo pi;
              memset(&pi, 0, sizeof(BzlaPropInfo));
              pi.exp          = expr;
              pi.bv[0]        = bv_cur_x;
              pi.bvd[0]       = d_x;
              pi.target_value = bv_t;

              bzla->slv = slv_prop;
              bv_x      = cons_fun(bzla, &pi);

              expected_result = bv_x ? BZLA_RESULT_SAT : BZLA_RESULT_UNSAT;

              eq_x = c_x = 0;
              if (bv_x)
              {
                c_x  = bzla_exp_bv_const(bzla, bv_x);
                eq_x = bzla_exp_eq(bzla, x, c_x);
                bzla_assume_exp(bzla, eq_x);
              }

              eq_t = bzla_exp_eq(bzla, expr, c_t);

              bzla_assume_exp(bzla, eq_x1);
              bzla_assume_exp(bzla, eq_x2);
              bzla_assume_exp(bzla, eq_t);

              bzla->slv    = slv_sat;
              uint32_t res = bzla_check_sat(bzla, -1, -1);

              if (res != expected_result)
              {
                std::cout << "d_x:    ";
                bzla_bvdomain_print(mm, d_x, true);
                std::cout << "cur_x:  ";
                bzla_bv_print(bv_cur_x);
                std::cout << "upper: " << upper << std::endl;
                std::cout << "lower: " << lower << std::endl;
                std::cout << "t:      ";
                bzla_bv_print(bv_t);
                std::cout << "pos_x:  0" << std::endl;
                std::cout << "cons_x: ";
                if (bv_x)
                {
                  bzla_bv_print(bv_x);
                }
                else
                {
                  std::cout << "none" << std::endl;
                }
              }

              ASSERT_EQ(res, expected_result);

              if (!slv_sat)
              {
                slv_sat = bzla->slv;
              }

              if (bv_x)
              {
                bzla_node_release(bzla, c_x);
                bzla_bv_free(mm, bv_x);
                bzla_node_release(bzla, eq_x);
              }

              bzla_node_release(bzla, eq_t);
            }
            bzla_bvdomain_gen_delete(&gen);
            bzla_bv_free(mm, bv_t);
            bzla_node_release(bzla, c_t);
          }
          bzla_node_release(bzla, expr);
        }
      }

      bzla_node_release(bzla, x_lo);
      bzla_node_release(bzla, x_hi);
      bzla_node_release(bzla, and_x);
      bzla_node_release(bzla, or_x);
      bzla_node_release(bzla, eq_x1);
      bzla_node_release(bzla, eq_x2);

      bzla_bvdomain_free(mm, d_x);
    }

    bzla_node_release(bzla, x);
    bzla->slv = slv_prop;
    slv_prop->api.delet(slv_prop);
    bzla->slv = slv_sat;
    bzla_rng_delete(rng);
    bzla_delete(bzla);
    std::stringstream ss;
    ss << "Number of tests (pos_x: 0): " << num_tests;
    log(ss.str());
  }

  void test_cond(BzlaPropComputeValueFun cons_fun,
                 uint32_t pos_x,
                 bool fixed_bits)
  {
    uint32_t expected_result;
    Bzla *bzla;
    BzlaSortId sort_bool, sort_bv;
    BzlaBvDomain *d_x;
    BzlaBitVector *bv_s1, *bv_t, *bv_s2, *bv_x, *bv_cur_x;
    BzlaIntHashTable *domains;
    BzlaBvDomainGenerator gen;
    BzlaRNG *rng;
    BzlaSolver *slv_sat = nullptr, *slv_prop;
    BzlaMemMgr *mm;
    BzlaNode *x, *s1, *s2, *expr, *eq_t, *c_x, *c_s1, *c_s2, *c_t, *eq_x;
    BzlaNode *x_lo, *x_hi, *and_x, *or_x, *eq_x1, *eq_x2;
    std::vector<std::string> values_x, values_s1, values_t, values_s2;

    bzla = bzla_new();
    mm   = bzla->mm;

    slv_prop       = bzla_new_prop_solver(bzla);
    slv_prop->bzla = bzla;

    bzla_opt_set(bzla, BZLA_OPT_INCREMENTAL, 1);
    bzla_opt_set(bzla, BZLA_OPT_CHECK_MODEL, 0);

    sort_bool = bzla_sort_bool(bzla);
    sort_bv   = bzla_sort_bv(bzla, TEST_PROPCONS_BW);

    rng = bzla_rng_new(mm, 0);

    if (pos_x == 0)
    {
      x    = bzla_exp_var(bzla, sort_bool, "x");
      s1   = bzla_exp_var(bzla, sort_bv, "s1");
      s2   = bzla_exp_var(bzla, sort_bv, "s2");
      expr = bzla_exp_cond(bzla, x, s1, s2);
    }
    else if (pos_x == 1)
    {
      s1   = bzla_exp_var(bzla, sort_bool, "s1");
      x    = bzla_exp_var(bzla, sort_bv, "x");
      s2   = bzla_exp_var(bzla, sort_bv, "s2");
      expr = bzla_exp_cond(bzla, s1, x, s2);
    }
    else
    {
      s1   = bzla_exp_var(bzla, sort_bool, "s1");
      s2   = bzla_exp_var(bzla, sort_bv, "s2");
      x    = bzla_exp_var(bzla, sort_bv, "x");
      expr = bzla_exp_cond(bzla, s1, s2, x);
    }

    bzla_sort_release(bzla, sort_bool);
    bzla_sort_release(bzla, sort_bv);

    gen_xvalues(bzla_node_bv_get_width(bzla, x), values_x);
    gen_values(bzla_node_bv_get_width(bzla, s1), values_s1);
    gen_values(bzla_node_bv_get_width(bzla, s2), values_s2);
    gen_values(bzla_node_bv_get_width(bzla, expr), values_t);

    uint64_t num_tests = 0;
    for (const std::string &xval : values_x)
    {
      d_x = bzla_bvdomain_new_from_char(mm, xval.c_str());

      if (!fixed_bits && bzla_bvdomain_has_fixed_bits(mm, d_x))
      {
        bzla_bvdomain_free(mm, d_x);
        continue;
      }

      domains = bzla_hashint_map_new(mm);
      bzla_hashint_map_add(domains, bzla_node_get_id(x))->as_ptr = d_x;

      x_lo  = bzla_exp_bv_const(bzla, d_x->lo);
      x_hi  = bzla_exp_bv_const(bzla, d_x->hi);
      and_x = bzla_exp_bv_and(bzla, x_hi, x);
      or_x  = bzla_exp_bv_or(bzla, x_lo, x);
      eq_x1 = bzla_exp_eq(bzla, and_x, x);
      eq_x2 = bzla_exp_eq(bzla, or_x, x);

      for (const std::string &s1val : values_s1)
      {
        bv_s1 = bzla_bv_char_to_bv(mm, s1val.c_str());
        c_s1  = bzla_exp_bv_const(bzla, bv_s1);

        for (const std::string &s2val : values_s2)
        {
          bv_s2 = bzla_bv_char_to_bv(mm, s2val.c_str());
          c_s2  = bzla_exp_bv_const(bzla, bv_s2);

          for (const std::string &tval : values_t)
          {
            bv_t = bzla_bv_char_to_bv(mm, tval.c_str());
            c_t  = bzla_exp_bv_const(bzla, bv_t);

            bzla_bvdomain_gen_init(mm, rng, &gen, d_x);
            while (bzla_bvdomain_gen_has_next(&gen))
            {
              ++num_tests;
              bv_cur_x = bzla_bvdomain_gen_next(&gen);

              BzlaPropInfo pi;
              memset(&pi, 0, sizeof(BzlaPropInfo));
              pi.pos_x     = pos_x;
              pi.exp       = expr;
              pi.bv[pos_x] = bv_cur_x;
              if (pos_x == 0)
              {
                pi.bv[1] = bv_s1;
                pi.bv[2] = bv_s2;
              }
              else if (pos_x == 1)
              {
                pi.bv[0] = bv_s1;
                pi.bv[2] = bv_s2;
              }
              else
              {
                pi.bv[0] = bv_s1;
                pi.bv[1] = bv_s2;
              }
              pi.bvd[pos_x]   = d_x;
              pi.target_value = bv_t;

              bzla->slv = slv_prop;
              bv_x      = cons_fun(bzla, &pi);

              expected_result = bv_x ? BZLA_RESULT_SAT : BZLA_RESULT_UNSAT;

              if (bv_x)
              {
                c_x  = bzla_exp_bv_const(bzla, bv_x);
                eq_x = bzla_exp_eq(bzla, x, c_x);
                bzla_assume_exp(bzla, eq_x);
                bzla_node_release(bzla, c_x);
                bzla_node_release(bzla, eq_x);
              }

              eq_t = bzla_exp_eq(bzla, expr, c_t);

              bzla_assume_exp(bzla, eq_x1);
              bzla_assume_exp(bzla, eq_x2);
              bzla_assume_exp(bzla, eq_t);

              bzla->slv    = slv_sat;
              uint32_t res = bzla_check_sat(bzla, -1, -1);

              if (res != expected_result)
              {
                std::cout << "d_x:    ";
                bzla_bvdomain_print(mm, d_x, true);
                std::cout << "cur_x:  ";
                bzla_bv_print(bv_cur_x);
                std::cout << "s1:     ";
                bzla_bv_print(bv_s1);
                std::cout << "s2:     ";
                bzla_bv_print(bv_s2);
                std::cout << "t:      ";
                bzla_bv_print(bv_t);
                std::cout << "pos_x:  " << pos_x << std::endl;
                std::cout << "cons_x: ";
                if (bv_x)
                {
                  bzla_bv_print(bv_x);
                }
                else
                {
                  std::cout << "none" << std::endl;
                }
              }

              assert(res == expected_result);
              ASSERT_EQ(res, expected_result);

              if (!slv_sat)
              {
                slv_sat = bzla->slv;
              }

              if (bv_x)
              {
                bzla_bv_free(mm, bv_x);
              }

              bzla_node_release(bzla, eq_t);
            }
            bzla_bvdomain_gen_delete(&gen);
            bzla_bv_free(mm, bv_t);
            bzla_node_release(bzla, c_t);
          }

          bzla_bv_free(mm, bv_s2);
          bzla_node_release(bzla, c_s2);
        }

        bzla_bv_free(mm, bv_s1);
        bzla_node_release(bzla, c_s1);
      }

      bzla_node_release(bzla, x_lo);
      bzla_node_release(bzla, x_hi);
      bzla_node_release(bzla, and_x);
      bzla_node_release(bzla, or_x);
      bzla_node_release(bzla, eq_x1);
      bzla_node_release(bzla, eq_x2);

      bzla_bvdomain_free(mm, d_x);
      bzla_hashint_map_delete(domains);
    }

    bzla_node_release(bzla, x);
    bzla_node_release(bzla, s1);
    bzla_node_release(bzla, s2);
    bzla_node_release(bzla, expr);
    bzla->slv = slv_prop;
    slv_prop->api.delet(slv_prop);
    bzla->slv = slv_sat;
    bzla_rng_delete(rng);
    bzla_delete(bzla);
    std::stringstream ss;
    ss << "Number of tests (pos_x: " << pos_x << "): " << num_tests;
    log(ss.str());
  }
};

TEST_F(TestPropCons, cons_add)
{
  test_binary(bzla_exp_bv_add, bzla_proputils_cons_add, 0, false);
  test_binary(bzla_exp_bv_add, bzla_proputils_cons_add, 1, false);
}

TEST_F(TestPropCons, cons_and)
{
  test_binary(bzla_exp_bv_and, bzla_proputils_cons_and, 0, false);
  test_binary(bzla_exp_bv_and, bzla_proputils_cons_and, 1, false);
}

TEST_F(TestPropCons, cons_eq)
{
  test_binary(bzla_exp_eq, bzla_proputils_cons_eq, 0, false);
  test_binary(bzla_exp_eq, bzla_proputils_cons_eq, 1, false);
}

TEST_F(TestPropCons, cons_concat)
{
  test_binary(bzla_exp_bv_concat, bzla_proputils_cons_concat, 0, false);
  test_binary(bzla_exp_bv_concat, bzla_proputils_cons_concat, 1, false);
}

TEST_F(TestPropCons, cons_mul)
{
  test_binary(bzla_exp_bv_mul, bzla_proputils_cons_mul, 0, false);
  test_binary(bzla_exp_bv_mul, bzla_proputils_cons_mul, 1, false);
}

TEST_F(TestPropCons, cons_sll)
{
  test_binary(bzla_exp_bv_sll, bzla_proputils_cons_sll, 0, false);
  test_binary(bzla_exp_bv_sll, bzla_proputils_cons_sll, 1, false);
}

TEST_F(TestPropCons, cons_srl)
{
  test_binary(bzla_exp_bv_srl, bzla_proputils_cons_srl, 0, false);
  test_binary(bzla_exp_bv_srl, bzla_proputils_cons_srl, 1, false);
}

TEST_F(TestPropCons, cons_sra)
{
  test_binary(bzla_exp_bv_sra, bzla_proputils_cons_sra, 0, false);
  test_binary(bzla_exp_bv_sra, bzla_proputils_cons_sra, 1, false);
}

TEST_F(TestPropCons, cons_udiv)
{
  test_binary(bzla_exp_bv_udiv, bzla_proputils_cons_udiv, 0, false);
  test_binary(bzla_exp_bv_udiv, bzla_proputils_cons_udiv, 1, false);
}

TEST_F(TestPropCons, cons_ult)
{
  test_binary(bzla_exp_bv_ult, bzla_proputils_cons_ult, 0, false);
  test_binary(bzla_exp_bv_ult, bzla_proputils_cons_ult, 1, false);
}

TEST_F(TestPropCons, cons_slt)
{
  test_binary(bzla_exp_bv_slt, bzla_proputils_cons_slt, 0, false);
  test_binary(bzla_exp_bv_slt, bzla_proputils_cons_slt, 1, false);
}

TEST_F(TestPropCons, cons_urem)
{
  test_binary(bzla_exp_bv_urem, bzla_proputils_cons_urem, 0, false);
  test_binary(bzla_exp_bv_urem, bzla_proputils_cons_urem, 1, false);
}

TEST_F(TestPropCons, cons_slice)
{
  test_slice(bzla_proputils_cons_slice, false);
}

TEST_F(TestPropCons, cons_cond)
{
  test_cond(bzla_proputils_cons_cond, 0, false);
  test_cond(bzla_proputils_cons_cond, 1, false);
  test_cond(bzla_proputils_cons_cond, 2, false);
}

/*****************************************************************************/
/* Consistent values with fixed bits.                                        */
/*****************************************************************************/

TEST_F(TestPropCons, cons_add_const)
{
  test_binary(bzla_exp_bv_add, bzla_proputils_cons_add_const, 0, true);
  test_binary(bzla_exp_bv_add, bzla_proputils_cons_add_const, 1, true);
}

TEST_F(TestPropCons, cons_and_const)
{
  test_binary(bzla_exp_bv_and, bzla_proputils_cons_and_const, 0, true);
  test_binary(bzla_exp_bv_and, bzla_proputils_cons_and_const, 1, true);
}

TEST_F(TestPropCons, cons_eq_const)
{
  test_binary(bzla_exp_eq, bzla_proputils_cons_eq_const, 0, true);
  test_binary(bzla_exp_eq, bzla_proputils_cons_eq_const, 1, true);
}

TEST_F(TestPropCons, cons_concat_const)
{
  test_binary(bzla_exp_bv_concat, bzla_proputils_cons_concat_const, 0, true);
  test_binary(bzla_exp_bv_concat, bzla_proputils_cons_concat_const, 1, true);
}

TEST_F(TestPropCons, cons_mul_const)
{
  test_binary(bzla_exp_bv_mul, bzla_proputils_cons_mul_const, 0, true);
  test_binary(bzla_exp_bv_mul, bzla_proputils_cons_mul_const, 1, true);
}

TEST_F(TestPropCons, cons_sll_const)
{
  test_binary(bzla_exp_bv_sll, bzla_proputils_cons_sll_const, 0, true);
  test_binary(bzla_exp_bv_sll, bzla_proputils_cons_sll_const, 1, true);
}

TEST_F(TestPropCons, cons_srl_const)
{
  test_binary(bzla_exp_bv_srl, bzla_proputils_cons_srl_const, 0, true);
  test_binary(bzla_exp_bv_srl, bzla_proputils_cons_srl_const, 1, true);
}

TEST_F(TestPropCons, cons_sra_const)
{
  test_binary(bzla_exp_bv_sra, bzla_proputils_cons_sra_const, 0, true);
  test_binary(bzla_exp_bv_sra, bzla_proputils_cons_sra_const, 1, true);
}

TEST_F(TestPropCons, cons_udiv_const)
{
  test_binary(bzla_exp_bv_udiv, bzla_proputils_cons_udiv_const, 0, true);
  test_binary(bzla_exp_bv_udiv, bzla_proputils_cons_udiv_const, 1, true);
}

TEST_F(TestPropCons, cons_ult_const)
{
  test_binary(bzla_exp_bv_ult, bzla_proputils_cons_ult_const, 0, true);
  test_binary(bzla_exp_bv_ult, bzla_proputils_cons_ult_const, 1, true);
}

TEST_F(TestPropCons, cons_slt_const)
{
  test_binary(bzla_exp_bv_slt, bzla_proputils_cons_slt_const, 0, true);
  test_binary(bzla_exp_bv_slt, bzla_proputils_cons_slt_const, 1, true);
}

TEST_F(TestPropCons, cons_urem_const)
{
  test_binary(bzla_exp_bv_urem, bzla_proputils_cons_urem_const, 0, true);
  test_binary(bzla_exp_bv_urem, bzla_proputils_cons_urem_const, 1, true);
}

TEST_F(TestPropCons, cons_slice_const)
{
  test_slice(bzla_proputils_cons_slice_const, true);
}

TEST_F(TestPropCons, cons_cond_const)
{
  test_cond(bzla_proputils_cons_cond_const, 0, true);
  test_cond(bzla_proputils_cons_cond_const, 1, true);
  test_cond(bzla_proputils_cons_cond_const, 2, true);
}
