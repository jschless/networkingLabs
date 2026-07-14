# Ticket AR-205 — Provider reports an internal prefix leak

**Reported by:** Internet provider routing desk
**Impact:** The provider is receiving an enterprise client prefix that must
never leave the private routing domain. Internal and internet services remain
available.
**Symptom:** Both provider paths and internal monitoring are green, but the
provider can see the same private prefix through more than one external path.

Diagnose, contain, fix, and verify the incident. Submit outbound advertisement
evidence, the minimal policy/configuration correction, proof of withdrawal from
the external domain, and unaffected internal service tests.
