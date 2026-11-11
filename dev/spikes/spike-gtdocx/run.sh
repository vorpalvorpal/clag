#!/bin/sh
# Render each minimal doc to docx, html, typst; dump docx text.
cd "$(dirname "$0")"
for f in a b c d e f g h; do
  quarto render $f.qmd --to docx,html,typst >/dev/null 2>&1 || echo "render fail $f"
  echo "== $f docx"; unzip -p $f.docx word/document.xml | python3 -c "
import sys,re
x=sys.stdin.read()
for p in re.findall(r'<w:p[ >].*?</w:p>',x,re.S):
    s=''.join(re.findall(r'<w:t[^>]*>([^<]*)</w:t>',p)); st=re.findall(r'w:pStyle w:val=\"([^\"]*)\"',p)
    print(st,repr(s))
" | head -12
  echo "-- html:"; grep -o 'Plain caption' $f.html | wc -l
  echo "-- typ:"; grep -n 'Plain caption' $f.typ 2>/dev/null | head -3
done
