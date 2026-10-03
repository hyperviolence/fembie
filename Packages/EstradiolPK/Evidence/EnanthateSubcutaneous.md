# EEn subcutaneous model

Model identifier: `fembie/enanthate-subcutaneous/im-k1-90-percent/v1`.

Copies the [EEn intramuscular model](EnanthateIntramuscular.md), including the
three-compartment single-dose response, dose superposition, analytic derivative,
input validation, and finite-result checks. The original Estrannaise attribution
and MIT license remain applicable.

Parameters: `[d, k1, k2, k3] = [191.4, 0.1071, 0.601, 0.402]`.
Only `k1` changes: `0.119 * 0.9`, a 10% reduction from the IM depot release rate.
Rates are in inverse days; dose is milligrams of ester; output is pg/mL, with
its derivative in pg/mL/hour.

The SC adjustment is a requested modeling assumption, not an independently
fitted or clinically validated SC parameter set. It retains the IM model's
limitations. Levels selects this model for saved EEn subcutaneous regimens.

## Rationale for the SC adaptation

Use IM EEn as the base, with slightly slower SC depot absorption and unchanged
exposure scaling and systemic elimination. The cited route comparisons do not
establish a reliable difference in overall estradiol exposure, but the direct
SC-versus-IM PK comparison motivates a possible later SC peak. That comparison
used estradiol cypionate (EC), not enanthate (EEn), so applying it here is an
extrapolation across esters, formulations, and study populations.

The literature supports keeping the routes broadly similar. It does not establish
a precise 10% reduction in EEn depot release, nor does a nonsignificant route
comparison prove pharmacokinetic equivalence.

## Studies informing the assumption

| Study | Population and preparation | Findings and relevance | Limitations for this model |
| --- | --- | --- | --- |
| [Wiemeyer et al., 1986](https://pubmed.ncbi.nlm.nih.gov/3814225/) | Postmenopausal women given 10 mg IM EEn | Reported absorption constant `k_a = 1.505/day`, absorption half-life 0.46 days, and an apparent terminal half-life of 5.57 days (`K = 0.12445/day`). Provides EEn-specific IM PK context. | No SC comparison. These parameters come from a different PK model and are not the coefficients used directly in this implementation. |
| [Sierra-Ramírez et al., 2011](https://pubmed.ncbi.nlm.nih.gov/22078184/) | 30 reproductive-age women randomized to SC or IM; 5 mg EC plus 25 mg medroxyprogesterone acetate | Main PK measures, including Cmax (peak concentration), AUC (exposure), and Tmax (time to peak), were similar between routes. The supplied study summary describes a later observed SC Tmax without a statistically significant difference, motivating a possible slower SC absorption. | EC rather than EEn, a combined contraceptive preparation, and a small sample. The later-Tmax detail from the supplied summary was not independently verified against the full PK table during this documentation update. It does not establish a numerical SC adjustment. |
| [Herndon et al., 2023](https://pubmed.ncbi.nlm.nih.gov/36868378/) | Retrospective cohort of 130 transgender and gender-diverse patients (74 SC, 56 IM) | Estradiol concentrations did not differ significantly, despite lower median weekly SC doses (3.75 versus 4 mg). Supports broadly similar route behavior rather than a substantial bioavailability adjustment. | Clinical concentration comparisons do not directly measure EEn SC absorption, clearance, or full-cycle AUC. |
| [Misakian et al., 2025](https://pmc.ncbi.nlm.nih.gov/articles/PMC12641524/) | Multicenter retrospective study of 562 transgender and gender-diverse patients using EV or EC | Dose and time since injection were significant covariates for estradiol concentrations; route was not a significant determinant. Supports keeping SC and IM broadly similar. | EV/EC rather than EEn; retrospective concentration data do not identify an EEn SC release constant. |
| [Poage et al., 2026](https://pmc.ncbi.nlm.nih.gov/articles/PMC12922051/) | Retrospective cohort of 70 patients comparing SC and IM estradiol | The supplied study summary reports no significant difference in reaching target estradiol levels, with higher measured E2 for IM in exploratory analysis. | Sampling timing was not tightly controlled, limiting inference about a route-specific PK difference. These result details are retained from the supplied summary; full-text verification was limited by source access during this update. |

Wiemeyer's reported `k_a` and terminal half-life are contextual evidence, not a
replacement parameter set or proof that the upstream coefficients were derived
solely from that study. The implementation remains the Estrannaise
three-compartment fit documented in [the IM evidence note](EnanthateIntramuscular.md).
In particular, `k_a = 1.505/day` must not be equated with our `k1 = 0.119/day`,
and the study's apparent terminal rate must not be equated with our `k3`.

## Why change depot absorption only?

The working hypothesis is that route affects release from the injection depot,
while the downstream conversion and removal of estradiol remain the same.
Conceptually, this is:

- `k_a,SC = 0.9 * k_a,IM` for the route-sensitive depot absorption step.
- `F_SC = F_IM` for assumed relative bioavailability.
- `k_e,SC = k_e,IM` for assumed systemic elimination.

In this implementation, the depot step is `k1`, and the elimination step is `k3`.
There is no separately exposed `F` parameter; retaining `d = 191.4` preserves the
same exposure scaling rather than introducing a route-specific multiplier.

| Model quantity | IM | SC | Decision |
| --- | --- | --- | --- |
| Scale `d` | 191.4 | 191.4 | Same exposure scaling |
| Depot release `k1` (per day) | 0.119 | 0.1071 | SC is 90% of IM |
| Ester-to-estradiol transfer `k2` (per day) | 0.601 | 0.601 | Same downstream conversion |
| Estradiol elimination `k3` (per day) | 0.402 | 0.402 | Same systemic elimination |

A smaller depot release constant produces a later, broader peak and may lower
Cmax; it does not guarantee exactly unchanged peak concentration. In this model,
the total single-dose AUC integrated to infinity is `dose * d / k3`, independent
of `k1` and `k2`. Therefore, holding `d` and `k3` constant preserves total modeled
exposure exactly, although exposure over a finite observation window can differ.
This is a property of the implemented equations, not a clinical equivalence claim.

## Uncertainty and proposed sensitivity analysis

The multiplier **0.9 is a provisional modeling assumption**, not a measured EEn SC
parameter. A proposed exploratory sensitivity range is **0.75–1.05 times IM `k1`**
(`0.08925–0.12495/day`). This range includes no route effect and slightly faster
SC release; it is not a study-derived confidence interval.

The current implementation uses the fixed 0.9 multiplier. The sensitivity range
is documented for future analysis and is not implemented as selectable parameters
or uncertainty bands. Direct EEn SC-versus-IM PK data would be needed to fit or
validate a route-specific adjustment.

## Numerical verification

Tests compare single-dose and repeated-dose concentrations against independent
RK4 integration of the compartment equations, check the analytic derivative
against finite differences, and verify input validation and route selection.
