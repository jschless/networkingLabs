#!/usr/bin/env python3
import pynetbox

nb = pynetbox.api("http://172.31.40.23:8080", token=None)
print("Use the NetBox UI at http://127.0.0.1:8001 to create devices manually for this lab.")
