import sys
name, M = sys.argv[1], sys.argv[2]
t = open('template.md').read().replace('@@', M)
open(f'cand_{name}.md','w').write(t)
