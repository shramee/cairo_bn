//
// This file is for circuit setup for Groth16
//
// * Receives alpha, beta, gamma, delta
// * Computes Fixed pairing of alpha and negative beta
// * Computes -beta, -gamma, -delta
// * Computes line functions for gamma, delta miller steps
//
// Returns
// * e(alpha, -beta)
// * negative gamma, (negative negative) gamma
// * line functions array for gamma
// * negative delta, (negative negative) delta
// * line functions array for delta
//
// Then verification can be done as,
// e(a, b) * e_neg_alpha_beta * e(k, neg gamma) * e(c, neg delta) == 1
//

use bn::fields::fq_sparse::FqSparseTrait;
use bn::fields::fq_12_exponentiation::PairingExponentiationTrait;
use bn::traits::FieldOps;
use bn::curve::groups::ECOperations;
use bn::g::{Affine, AffineG1Impl, AffineG2Impl, g1, g2, AffineG1, AffineG2,};
use bn::fields::{Fq, fq, Fq2, print::{Fq2Display, Fq12Display}};
use bn::fields::{fq12, Fq12, Fq12Utils, Fq12Exponentiation};
use bn::curve::{pairing, get_field_nz};
use bn::traits::{MillerPrecompute, MillerSteps, FieldUtils};
use pairing::optimal_ate::{ate_miller_loop_steps};
use pairing::optimal_ate_utils::{
    p_precompute, line_fn, LineFn, step_double, step_dbl_add, correction_step
};
use pairing::optimal_ate_utils::{step_double_to_f, step_dbl_add_to_f, correction_step_to_f};
use pairing::optimal_ate_impls::{SingleMillerPrecompute, SingleMillerSteps, PPrecompute};
use bn::groth16::utils::{ICProcess, process_input_constraints, G16CircuitSetup, FixedG2Precompute};

// The points to generate lines precompute for
#[derive(Copy, Drop, Serde)]
struct G16SetupG2 {
    beta: AffineG2,
    delta: AffineG2,
    gamma: AffineG2,
}

// The points to generate lines precompute for
#[derive(Drop, Serde)]
struct G16SetupAcc {
    beta: AffineG2,
    delta: AffineG2,
    gamma: AffineG2,
    delta_lines: Array<LineFn>,
    gamma_lines: Array<LineFn>,
}

#[derive(Drop, Serde)]
struct G16SetupPreComp {
    p: AffineG1, // single alpha point
    q: G16SetupG2,
    neg_q: G16SetupG2,
    ppc: PPrecompute,
    field_nz: NonZero<u256>,
}

#[inline(always)]
fn line_fn_tuple_append(ref ar: Array<LineFn>, line_fns: (LineFn, LineFn)) {
    let (l1, l2) = line_fns;
    ar.append(l1);
    ar.append(l2);
}

#[generate_trait]
impl Private of PrivateTrait {
    #[inline(always)]
    fn acc_step_double(self: @G16SetupPreComp, ref acc: G16SetupAcc) {
        acc.gamma_lines.append(line_fn::step_double(ref acc.gamma, *self.field_nz));
        acc.delta_lines.append(line_fn::step_double(ref acc.delta, *self.field_nz));
    }

    #[inline(always)]
    fn acc_step_dbl_add(self: @G16SetupPreComp, q: @G16SetupG2, ref acc: G16SetupAcc) {
        line_fn_tuple_append(
            ref acc.gamma_lines, line_fn::step_dbl_add(ref acc.gamma, *q.gamma, *self.field_nz)
        );
        line_fn_tuple_append(
            ref acc.delta_lines, line_fn::step_dbl_add(ref acc.delta, *q.delta, *self.field_nz)
        );
    }

    #[inline(always)]
    fn acc_correction_step(self: @G16SetupPreComp, ref acc: G16SetupAcc) {
        line_fn_tuple_append(
            ref acc.gamma_lines,
            line_fn::correction_step(ref acc.gamma, *self.q.gamma, *self.field_nz)
        );
        line_fn_tuple_append(
            ref acc.delta_lines,
            line_fn::correction_step(ref acc.delta, *self.q.delta, *self.field_nz)
        );
    }
}

impl G16SetupSteps of MillerSteps<G16SetupPreComp, G16SetupAcc> {
    fn miller_first_second(self: @G16SetupPreComp, i1: u32, i2: u32, ref acc: G16SetupAcc) -> Fq12 {
        // Handle O, N steps

        // step 0, run step double
        let l0 = step_double(ref acc.beta, self.ppc, *self.p, *self.field_nz);
        self.acc_step_double(ref acc);

        // sqr with mul 034 by 034
        let f_01234 = l0.sqr_034(*self.field_nz);

        // step -1, the next negative one step
        let (l1, l2) = step_dbl_add(
            ref acc.beta, self.ppc, *self.p, *self.neg_q.beta, *self.field_nz
        );
        self.acc_step_dbl_add(self.neg_q, ref acc);
        f_01234.mul_01234_01234(l1.mul_034_by_034(l2, *self.field_nz), *self.field_nz)
    }

    // 0 bit
    fn miller_bit_o(self: @G16SetupPreComp, i: u32, ref acc: G16SetupAcc, ref f: Fq12) {
        step_double_to_f(ref acc.beta, ref f, self.ppc, *self.p, *self.field_nz);
        self.acc_step_double(ref acc);
    }

    // 1 bit
    fn miller_bit_p(self: @G16SetupPreComp, i: u32, ref acc: G16SetupAcc, ref f: Fq12) {
        step_dbl_add_to_f(ref acc.beta, ref f, self.ppc, *self.p, *self.q.beta, *self.field_nz);
        self.acc_step_dbl_add(self.q, ref acc);
    }

    // -1 bit
    fn miller_bit_n(self: @G16SetupPreComp, i: u32, ref acc: G16SetupAcc, ref f: Fq12) {
        // use neg q
        step_dbl_add_to_f(ref acc.beta, ref f, self.ppc, *self.p, *self.neg_q.beta, *self.field_nz);
        self.acc_step_dbl_add(self.neg_q, ref acc);
    }

    // last step
    fn miller_last(self: @G16SetupPreComp, ref acc: G16SetupAcc, ref f: Fq12) {
        correction_step_to_f(ref acc.beta, ref f, self.ppc, *self.p, *self.q.beta, *self.field_nz);
        self.acc_correction_step(ref acc);
    }
}

fn setup_precompute(
    alpha: AffineG1, beta: AffineG2, gamma: AffineG2, delta: AffineG2,
) -> G16CircuitSetup { //
    // negate beta, gamma and delta
    // use the original as negative and negative as original
    let beta_neg = beta;
    let beta = beta.neg();
    let gamma_neg = gamma;
    let gamma = gamma.neg();
    let delta_neg = gamma;
    let delta = gamma.neg();

    // prepare miller precompute
    let field_nz = get_field_nz();
    let q = G16SetupG2 { beta, delta, gamma, };
    let neg_q = G16SetupG2 { beta: beta_neg, delta: gamma_neg, gamma: delta_neg, };
    let ppc = p_precompute(alpha, field_nz);
    let precomp = G16SetupPreComp { p: alpha, q, neg_q, ppc, field_nz, };

    // q points accumulator
    let mut delta_lines = array![];
    let mut gamma_lines = array![];
    let mut acc = G16SetupAcc { beta, delta, gamma, delta_lines, gamma_lines };
    // run miller steps
    // e(alpha, beta)
    let alpha_beta = ate_miller_loop_steps(precomp, ref acc);

    // extract line functions from accumulator
    let G16SetupAcc { beta: _, delta: _, gamma: _, delta_lines, gamma_lines } = acc;
    // line functions for gamma
    let gamma = FixedG2Precompute { lines: gamma_lines, point: gamma, neg: gamma_neg, };
    // line functions for delta
    let delta = FixedG2Precompute { lines: delta_lines, point: delta, neg: delta_neg, };
    G16CircuitSetup { alpha_beta, gamma, delta }
}
