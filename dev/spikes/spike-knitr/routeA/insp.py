import re,sys
s=open(sys.argv[1]).read()
m=s[s.index('<main'):s.index('</main>')]
m=re.sub(r'data:image/png;base64,[A-Za-z0-9+/=]+','DATA',m)
m=re.sub(r'\n\s*\n+','\n',m)
i=m.find(sys.argv[2]); print(m[max(0,i-400):i+1400])
print('TOC:', re.findall(r'<nav id="TOC".*?</nav>',s,re.S)); print('xrefs', re.findall(r'class="quarto-xref">(.*?)</a>',m), '| ?@' , '?@' in s, '| {{', '{{' in s)
