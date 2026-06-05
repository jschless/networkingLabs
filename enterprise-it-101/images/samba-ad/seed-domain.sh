#!/bin/bash
# ============================================================
# Seed the LAB.CORP domain with the Lab 01 foundation objects:
# the Employees / Workstations / Service Accounts OUs, the
# alice/bob/charlie users, and the engineering/finance/all-staff
# groups. This reproduces the end state of Lab 01 so that Labs 02+
# start from the same cumulative foundation without the student
# re-doing Lab 01 by hand.
#
# samba-tool operates on the local sam.ldb, so this runs fine
# without the samba daemon up.
# ============================================================
set -e

ADMIN_PASS="${ADMIN_PASS:-P@ssw0rd1}"

samba-tool ou create "OU=Employees,DC=lab,DC=corp"
samba-tool ou create "OU=Workstations,DC=lab,DC=corp"
samba-tool ou create "OU=Service Accounts,DC=lab,DC=corp"

samba-tool user create alice "${ADMIN_PASS}" \
    --given-name=Alice --surname=Smith --userou="OU=Employees"
samba-tool user create bob "${ADMIN_PASS}" \
    --given-name=Bob --surname=Jones --userou="OU=Employees"
samba-tool user create charlie "${ADMIN_PASS}" \
    --given-name=Charlie --surname=Brown --userou="OU=Employees"

samba-tool group add engineering
samba-tool group add finance
samba-tool group add all-staff

samba-tool group addmembers engineering alice
samba-tool group addmembers finance bob
samba-tool group addmembers all-staff alice,bob,charlie
