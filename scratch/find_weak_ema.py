import re

mq4_path = r'c:\Users\venuadmin\AppData\Roaming\MetaQuotes\Terminal\2191F4A3D14D7B4B1EBB84F924777883\MQL4\Experts\V_EMAMULTIPLE_ORDERS.mq4'

with open(mq4_path, 'r', encoding='utf-8', errors='ignore') as f:
    lines = f.readlines()

print(f'Total lines: {len(lines)}')

results = []
for i, line in enumerate(lines):
    if re.search(r'weak', line, re.IGNORECASE):
        results.append((i + 1, line.strip()))

print(f'Found {len(results)} lines mentioning "weak":')
for l_num, text in results:
    print(f'Line {l_num:5d}: {text[:120]}')
