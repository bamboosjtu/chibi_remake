import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
export function writeCatalog(file,next,{replaceAccepted=false}={}){
  const lock=file+'.lock';
  const fd=fs.openSync(lock,'wx');
  try{
    const current=fs.existsSync(file)?JSON.parse(fs.readFileSync(file)):{};
    if(next.contentRevision&&current.contentRevision&&next.contentRevision!==current.contentRevision)throw new Error('Catalog changed while the task was running; reload before retrying.');
    if(!replaceAccepted){
      for(const field of ['assets','pages']){
        const merged=new Map((next[field]||[]).map(x=>[x.assetId,x]));
        for(const old of current[field]||[]){
          const record=path.join(path.dirname(file),'deliveries',old.assetId+'.json');
          const delivery=fs.existsSync(record)?JSON.parse(fs.readFileSync(record)):null;
          const accepted=old.status==='user-accepted'||(delivery?.texture===old.target&&delivery?.validation?.visual==='pass');
          if(accepted||!merged.has(old.assetId))merged.set(old.assetId,old);
        }
        next[field]=[...merged.values()];
      }
      for(const field of ['visualReviewPolicy','additionalBanks'])if(current[field])next[field]=current[field];
    }
    next.contentRevision=crypto.createHash('sha256').update(JSON.stringify({assets:next.assets,pages:next.pages,additionalBanks:next.additionalBanks})).digest('hex');
    const temporary=file+'.tmp';
    fs.writeFileSync(temporary,JSON.stringify(next,null,2)+'\n');
    JSON.parse(fs.readFileSync(temporary));
    fs.renameSync(temporary,file);
  }finally{fs.closeSync(fd);fs.unlinkSync(lock);}
  return next;
}
export function assertUnpublishedTarget(asset,data){
  if(fs.existsSync(asset.target)&&!fs.readFileSync(asset.target).equals(data))throw new Error('Immutable asset target already exists: '+asset.target+'; choose a new version.');
}
