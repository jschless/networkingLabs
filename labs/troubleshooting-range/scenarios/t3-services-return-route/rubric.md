# Proctor rubric — TR-302 (confidential)

**Root cause:** services1 has an invalid default route. Requests reach the service subnet, but DNS/web replies cannot return to corporate clients. **Pass:** 70/100 and `verify.sh` green. **Time:** 60 minutes.

Score separation of service process, DNS request, and return-path evidence (35), healthy alternate-path proof (15), minimal service-node route repair (25), and corporate DNS plus TCP verification (25). Restarting the service or adding client static workarounds without return-path evidence caps at 69.
