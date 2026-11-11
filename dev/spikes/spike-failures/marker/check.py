import sys,subprocess,json,re
# For each Para/Plain/Header, report: contains marker text intact? stray '*' or literal '\' or '{.'? 
name=sys.argv[1]
j=json.loads(subprocess.check_output(['quarto','pandoc',f'cand_{name}.md','-t','json']))
def txt(x):
    if isinstance(x,list): return ''.join(txt(i) for i in x)
    if isinstance(x,dict):
        t=x['t']; c=x.get('c')
        if t=='Str': return c
        if t=='Space' or t=='SoftBreak': return ' '
        if t in('Strong','Emph','Strikeout','Span','Link'):
            return txt(c[-1] if t in('Span','Link') else c) if t not in('Span','Link') else txt(c[1])
        if t=='Code': return c[1]
        if t in('Para','Plain'): return txt(c)
        if t=='Header': return txt(c[2])
        if t=='Note': return '{{note:'+txt(c)+'}}'
        if t=='Cite': return txt(c[1])
        return txt(c) if c is not None else ''
    return ''
def walk(blocks,out):
    for b in blocks:
        t=b['t']
        if t in('Para','Plain','Header'): out.append(txt(b))
        elif t in('BulletList','OrderedList'):
            for it in (b['c'] if t=='BulletList' else b['c'][1]): walk(it,out)
        elif t=='Table':
            out.append('TABLE:'+json.dumps(b['c'][4:])[:0])
            def rec(o):
                if isinstance(o,dict) and o.get('t') in('Plain','Para'): out.append('  cell: '+txt(o))
                elif isinstance(o,dict): rec(o.get('c'))
                elif isinstance(o,list): [rec(i) for i in o]
            rec(b['c'])
        elif t=='BlockQuote': walk(b['c'],out)
out=[]; walk(j['blocks'],out)
meta=j['meta']['title']['c']; print('TITLE:',txt(meta))
for l in out: print(l)
