
print('\n=== 6. DETAIL AROUND TICKET 440/468 CLOSE AT 14:54 ===')
for a in actions:
    if '2026.10.02 14:5' in a['time'] or '2026.10.02 14:4' in a['time']:
        print(a)
