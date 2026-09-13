from pathlib import Path
import zipfile
root=Path(__file__).resolve().parents[1]
out=root.parent/'nexus-ai-source.zip'
excluded={'.git','.dart_tool','.gradle','build','.idea'}
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
 for p in root.rglob('*'):
  rel=p.relative_to(root)
  if p.is_file() and not excluded.intersection(rel.parts) and p.name not in {'local.properties','.flutter-plugins-dependencies'} and p.suffix not in {'.jks','.keystore','.log'}: z.write(p,Path('nexus')/rel)
with zipfile.ZipFile(out,'a',zipfile.ZIP_DEFLATED) as z:
 history=root.parent/'nexus-history.bundle'
 if history.exists():z.write(history,'nexus-history.bundle')
print(out)
