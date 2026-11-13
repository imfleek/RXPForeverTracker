# Every build: (1) global reads of names the same file declares local (use before definition),
# (2) unusual lowercase global reads, (3) global writes other than the saved variables.
import subprocess, re, glob, sys
root = sys.argv[1]
known = set("""ipairs pairs type tostring tonumber math string table select pcall xpcall error assert unpack next rawget rawset
setmetatable getmetatable print _G hooksecurefunc tinsert tremove wipe geterrorhandler securecallfunction issecretvalue
strsplit strtrim format date time floor max min abs debugstack issecurevariable strlower strupper tContains""".split())
saved = {"RXPForeverTrackerDB", "RXPForeverTrackerGuideDB", "SLASH_ALLOBJECTIVESRXP1"}
problems = 0
for f in sorted(p for p in glob.glob(root + '/**/*.lua', recursive=True) if '/tests/' not in p.replace('\\', '/')):
    out = subprocess.run(['texluac', '-l', '-p', f], capture_output=True, text=True).stdout
    reads = set(re.findall(r'GETTABUP\s.*?_ENV "([A-Za-z_]\w*)"', out))
    writes = set(re.findall(r'SETTABUP\s.*?_ENV "([A-Za-z_]\w*)"', out))
    src = open(f).read()
    locals_ = set(re.findall(r'local\s+function\s+([A-Za-z_]\w*)', src))
    for m in re.finditer(r'local\s+([A-Za-z_][\w\s,]*?)(?:=|\n)', src):
        for n in m.group(1).split(','):
            n = n.strip()
            if re.fullmatch(r'[A-Za-z_]\w*', n): locals_.add(n)
    name = f[len(root) + 1:]
    for n in sorted(reads & locals_): print("READ-BEFORE-LOCAL", name, n); problems += 1
    for n in sorted(r for r in reads if r[0].islower() and r not in known): print("LOWERCASE-GLOBAL", name, n); problems += 1
    for n in sorted(writes - saved): print("GLOBAL-WRITE", name, n); problems += 1
print("globals audit:", "clean" if problems == 0 else f"{problems} problem(s)")
