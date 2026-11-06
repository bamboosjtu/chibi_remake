"""Copy tmp/*.AVI unchanged and index original video metadata; ffprobe reads metadata only."""
from pathlib import Path
import json,hashlib,shutil,subprocess
root=Path(__file__).resolve().parents[1];target=root/'godot/chibi_remake/media/videos';target.mkdir(parents=True,exist_ok=True)
files={}
for source in sorted((root/'tmp').glob('*.AVI')):
 info=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','stream=index,codec_type,codec_name,width,height,r_frame_rate,sample_rate,channels','-show_entries','format=duration','-of','json',str(source)]))
 video=next(s for s in info['streams'] if s['codec_type']=='video')
 shutil.copyfile(source,target/source.name)
 files[source.name]={'path':'res://media/videos/'+source.name,'width':video['width'],'height':video['height'],'fps':video['r_frame_rate'],'duration':float(info['format']['duration']),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'bytes':source.stat().st_size,'codec':video['codec_name']}
assert len(files)==47
(root/'godot/chibi_remake/data/db/video_catalog.json').write_text(json.dumps({'source':'tmp/','mode':'original bytes; no transcoding; native pixels; centered','files':files},indent=2)+'\n',encoding='utf-8')
print('Copied',len(files),'original AVI files without encoding;',sum(v['bytes'] for v in files.values()),'bytes')
