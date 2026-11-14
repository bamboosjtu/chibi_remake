from pathlib import Path
import tempfile,subprocess,importlib.util
root=Path(__file__).resolve().parent.parent
spec=importlib.util.spec_from_file_location('avi_builder',root/'tools/native/avi_decoder/build.py')
builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)
parent=root/'_work/native-source-tests';parent.mkdir(exist_ok=True)
fixture=Path(tempfile.mkdtemp(dir=parent));source=fixture/'origin';source.mkdir()
def git(*args):return subprocess.check_output(['git','-C',str(source),*args],text=True,stderr=subprocess.STDOUT).strip()
git('init','--quiet');git('config','user.name','Fixture');git('config','user.email','fixture@example.invalid')
(source/'code.c').write_text('int version = 1;\n');git('add','.');git('commit','--quiet','-m','fixture');commit=git('rev-parse','HEAD')
builder.WORK=fixture/'work';builder.WORK.mkdir();builder.LOCK={'fixture':{'repository':str(source),'commit':commit}}
builder.source_tree('fixture','dependency');builder.source_tree('fixture','dependency')
(builder.WORK/'dependency/code.c').write_text('tampered\n')
try:builder.source_tree('fixture','dependency');raise AssertionError('Modified source accepted')
except RuntimeError as error:assert 'Modified dependency sources' in str(error)
legacy=builder.WORK/'legacy';legacy.mkdir();(legacy/'notes').write_text('keep')
builder.source_tree('fixture','legacy');assert len(list(builder.WORK.glob('legacy.legacy-*')))==1
assert builder.git(builder.WORK/'legacy','rev-parse','HEAD')==commit
print('NATIVE SOURCES PASS pinned Git objects / cache validation / modified source rejection / legacy content retained')
