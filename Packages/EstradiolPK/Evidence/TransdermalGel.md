# Generic transdermal gel approximation v1

Identifier: `fembie/transdermal-gel/v1`. This is an original, experimental
approximation, not an Estrannaise parameter set or a clinically validated model.
The user supplies only mg of estradiol contained in each gel application.
Brand, gel weight, concentration, body weight and absorbed dose are not inputs.

## Primary evidence (checked 2026-10-29)

- [EstroGel label, §12.3, revised May 2026](https://dailymed.nlm.nih.gov/dailymed/fda/fdaDrugXsl.cfm?setid=762ac371-bb8b-47e7-b48f-e80d452c9dd4):
  24 postmenopausal women, daily 0.75 mg estradiol in 1.25 g gel, posterior arm
  from wrist to shoulder for 14 days. Day-14 unadjusted mean Cavg 28.3 pg/mL,
  mean individual Cmax 46.4 pg/mL, apparent terminal half-life about 36 hours.
  Figure 1's mean curve is much flatter than individual Cmax suggests.
- [Divigel label, §12.3, revised February 2026](https://dailymed.nlm.nih.gov/dailymed/fda/fdaDrugXsl.cfm?setid=59e610dc-883e-4f07-9ec6-a5841b0bf9fb):
  daily application to upper thigh, 14-day phase-1 multiple-dose study.
  For 0.25/0.5/1 mg estradiol, unadjusted Cavg is 9.8/21/30.5 pg/mL and
  Cmax is 14.7/28.4/51.5 pg/mL. Median Tmax at 1 mg is 8 hours;
  apparent terminal half-life about 10 hours. Cavg CV is 92/148/81%.

These are postmenopausal populations and product/application-specific conditions.
The summaries do not provide a common assay calibration or reliable endogenous
baseline subtraction. We do not claim they identify physiological clearance or
the distribution of responses in transfeminine users.

## Reproducible construction

Each dose contributes an equal-weight mixture of two normalized Bateman responses:

`C(t) = dose × 0.5 × Σ[A_j × ka × k_j / (ka − k_j) × (exp(−k_j t) − exp(−ka t))]`

for elapsed `t > 0` in hours, otherwise zero. Concentration is pg/mL.
`A` is concentration-time area per applied mg, in pg·h/mL/mg.
No third-party implementation or fitted Estrannaise parameters were copied.

- `k_E = ln(2)/36` and `k_D = ln(2)/10` per hour retain the labels' distinct
  apparent terminal rates. They are effective response constants, not systemic
  elimination constants.
- `A_E = 24 × 28.3 / 0.75 = 905.6`.
- `A_D = 24 × Σ(dose × Cavg) / Σ(dose²) = 794.5142857142857` is a
  through-origin least-squares exposure slope over all three Divigel arms.
- `ka = 0.11041559302643777/hour` solves the steady-state Bateman Tmax equation
  at a 24-hour interval using Divigel's 8-hour median and `k_D`:
  `8 = ln[(ka/k_D) × (1−exp(−24 k_D))/(1−exp(−24 ka))] / (ka−k_D)`.
  Applying this common effective absorption rate to both components is an assumption.
- Equal component weights are a design choice, not a population meta-analysis:
  sample sizes/individual observations sufficient for such pooling are unavailable.

The derivative is evaluated analytically in pg/mL/hour. Dated single-dose
responses are added, so startup, stopping, skipped and moved doses do not require
assuming steady state. `expm1` avoids cancellation near application time.

## Checks and limitations

Daily steady-state Cavg per mg is `(A_E + A_D)/48 = 35.41904761904762 pg/mL`.
Consequently predicted daily Cavg at 0.25/0.5/0.75/1 mg is approximately
8.85/17.71/26.56/35.42 pg/mL. These differ from the respective label means by
about −10%/−16%/−6%/+16%. They are consistency checks against construction
data, not independent validation. Baseline remains confounded with exposure;
zero-dose output is zero and no additional population baseline is added.

At 1 mg/day, the model's steady-state curve ranges approximately 28.84–39.3
pg/mL. It does not reproduce the labels' mean individual Cmax values. Different
individual peak times can make the mean concentration curve flatter than mean
individual Cmax. No fit to digitized full curves, individual data or independent
clinical validation has been performed. Tmax is a median constraint, not a fitted
population absorption estimate. Tests check arithmetic, causality, derivatives,
accumulation, washout and application integration; they do not validate biology.

Formulation, application site/area, skin, washing and lotions can substantially
alter exposure. Genital application is not represented. Doses outside 0.25–1 mg
and intervals other than 24 hours are extrapolations. No uncertainty band or
individual-response distribution is established. In particular the analytic
rate-of-change curve and its turning points are unvalidated model behavior.
An additive lab calibration cannot establish the absorption shape or validate
subsequent predictions. A future model should assess full curves and independent
data while retaining this dose-only user interface.
