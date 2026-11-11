import re,sys
s=open(sys.argv[1]).read()
i=s.index('<main'); j=s.index('</main>')
m=s[i:j]
m=re.sub(r'data:image/png;base64,[A-Za-z0-9+/=]+','DATA',m)
m=re.sub(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}','UUID',m)
m=re.sub(r'\n\s*\n+','\n',m)
print(m)
