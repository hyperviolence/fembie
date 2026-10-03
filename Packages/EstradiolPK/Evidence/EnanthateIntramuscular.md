# EEn intramuscular MVP

Model identifier: `estrannaise/enanthate-intramuscular/v1`.

Source: supplied `estrannai/models.js` and `estrannai/modeldata.js`, from
[Estrannaise](https://github.com/WHSAH/estrannaise.js), copyright (c) 2025 alix.
The MIT notice is preserved in `LICENSE-Estrannaise.txt` and displayed in Levels.

Source snapshot SHA-256:

- models.js: `7537569e050719b7e7306135d1e3330ed02ed1ee9aa40ab7f9c34e0ae7cd4f2f`
- modeldata.js: `f7568a05f829b51ef6c98caf6deca611196e707c725cc79ba6e2e6cb3e9994d4`

Parameters: `[d, k1, k2, k3] = [191.4, 0.119, 0.601, 0.402]`.
Elapsed time is in days, rates in inverse days, injection dose in milligrams
of ester, and concentration in pg/mL. The analytic derivative is converted
from pg/mL/day to pg/mL/hour. These fixed rates are distinct; the port does
not expose arbitrary parameters or implement general equal-rate limits.

The MVP sums single-dose responses from saved history and projected schedules.
It does not assume steady state, estimate endogenous baseline, calibrate to
blood tests, or include uncertainty bands. Levels automatically selects this
model only when the saved regimen specifies enanthate and the intramuscular
route. Unsupported ester/route combinations show an unavailable-model state.

Tests verify agreement with JavaScript single-dose and repeated-dose fixtures,
check the derivative against finite differences, and exercise skipped and moved
administrations. Numerical parity is not clinical validation. Upstream's
[limitations](https://estrannai.se/) and [references](https://estrannai.se/docs/refs/)
remain applicable; no additional clinical validation was performed for this port.
