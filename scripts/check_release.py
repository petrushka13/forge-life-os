"""No-secret static release sanity checks. Prints paths, never matched values."""
from pathlib import Path
import re
import subprocess
import sys
root=Path(__file__).resolve().parent.parent
errors=[]
for filename in subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard'],cwd=root,text=True).splitlines():
    path=root/filename
    if path.suffix not in {'.swift','.py','.js','.json','.md','.sh','.xcconfig','.pbxproj'} or not path.exists():continue
    text=path.read_text(errors='ignore')
    if re.search(r'sk-[A-Za-z0-9_-]{24,}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{30,}|-----BEGIN [A-Z ]*PRIVATE KEY',text):errors.append('Credential pattern in '+filename)
for name in ['ACCEPTANCE_MATRIX','CAPABILITY_MATRIX','ACCEPTANCE_REPORT','RELEASE_CHECKLIST','ACCOUNT_SETUP','SECURITY']:
    if not (root/'docs'/f'{name}.md').exists():errors.append('Missing documentation: '+name)
matrix=(root/'docs/ACCEPTANCE_MATRIX.md').read_text()
for number in range(1,71):
    if not re.search(rf'^\| {number}\. ',matrix,re.M):errors.append('Missing acceptance requirement '+str(number))
if errors:print('\n'.join(errors));sys.exit(1)
print('Static sanity: 70 acceptance requirements, release documents and repository-secret pattern scan passed')
