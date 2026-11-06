#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
const dir='godot/chibi_remake/art/production';
const catalog=JSON.parse(fs.readFileSync(`${dir}/catalog.json`));
const factionColors=['dark muted vermilion','muted azure blue','muted deep teal','muted olive green'];
const faces=['long lean face and fine straight brows','broad angular face and heavy brows','oval face and high arched brows','rounder face and small alert eyes','square face with pronounced cheekbones','narrow face with deeply set eyes','long face with prominent nose and calm eyes','broad face with soft brows and high forehead','compact face with sharp jaw and intense eyes'];
const facialHair=['neat short moustache and short beard','thin straight moustache and pointed beard','thick moustache and broad beard','neat trimmed sideburns and clean-shaven chin','long narrow black beard','short dark goatee and straight moustache','long greying forked beard'];
const portraits={
  0:'Gan Ning: weathered bold pirate-turned-general, swept black moustache, dark bronze helmet, red silk ties, small brass bells on shoulder strap.',
  1:'Taishi Ci: strong dignified middle-aged warrior, rectangular face, short dark beard, simple iron helmet, bronze lamellar armor.',
  5:'Zhou Tai: rugged battle-scarred jaw and brow, cropped beard, dark iron helmet and military red robe.',
  6:'Huang Gai: older veteran, broad stern face, thick grey beard, weathered bronze helmet and lamellar armor.',
  12:'Zhou Yu: youthful handsome refined clean-shaven commander, elegant black crown, dark red silk robe with restrained bronze shoulder armor.',
  13:'Lu Xun: young scholarly commander, refined narrow face, neat thin moustache, black scholar headdress, red-brown robe.',
  14:'Sun Quan: young stately leader, broad face, dark reddish beard, black ruler guan, subtle red robes and antique gold ornaments.',
  24:'Lu Su: kindly middle-aged scholar, full cheeks, long moustache and short beard, black scholar cap and understated russet robe.',
  33:'Zhao Yun: handsome composed young warrior, clean-shaven, white-silver helmet with white plume, white and azure cloth, silver lamellar armor.',
  34:'Zhang Fei: fierce broad dark-tanned face, large round eyes, dense bristling black beard, dark iron helmet, black-grey armor and blue sash.',
  35:'Guan Yu: dignified reddish complexion, long straight black beard, phoenix eyes, green headcloth and deep green robe.',
  39:'Liu Bei: refined middle-aged face, long ears suggested naturally, neat black moustache and beard, black guan crown and blue-green silk robe.',
  41:'Zhuge Liang: slender scholarly face, black tall guan, long pointed beard, ivory robe and dark teal collar, white feather fan.',
  42:'Xu Shu: thoughtful slender face, straight brows, black cloth scholar cap, neat moustache and beard, pale blue robe.',
  47:'Xu Chu: broad muscular neck, powerful square tanned face, thick short black beard, heavy dark iron helmet and thick bronze lamellar armor.',
  48:'Xu Huang: disciplined square face, steady eyes, neat full beard, simple iron helmet and deep teal soldier robe.',
  49:'Zhang Liao: firm angular face, narrow moustache, short pointed beard, bronze helmet and teal collar.',
  50:'Xiahou Dun: stern weathered face, dark cloth patch over left eye, thick moustache and short beard, dark iron helmet and teal armor.',
  59:'Cao Cao: middle-aged cunning calm leader, narrow eyes, high brows, short moustache and pointed beard, black ruler crown, dark teal robe.',
  84:'Cheng Yu: older tall-looking scholar, angular long face, greying long beard, tall black guan and muted teal robe.',
  90:'Xun You: composed middle-aged scholar, oval narrow face, neatly trimmed moustache and beard, black scholar guan and teal-grey robe.',
  92:'Zhang He: poised middle-aged general, long angular face, neat moustache and short beard, bronze helmet and teal lamellar armor.',
  93:'Xun Yu: refined calm scholarly middle-aged face, thin moustache and short beard, tall black guan and ivory-teal robe.',
  96:'Jia Xu: older reserved scholar, deep-set thoughtful eyes, greying long beard, modest black scholar cap, dark teal-brown robe.',
  98:'Wei Yan: imposing tanned face, fierce brows, long black beard, bronze helmet and olive military robe.',
  109:'Liu Biao: older aristocratic scholarly leader, broad forehead, neatly groomed grey beard, black court guan and muted olive silk robes.',
  111:'Liu Qi: young gentle aristocrat, slender pale face, sparse moustache, simple black guan and olive-ivory robe.',
  116:'Liu Cong: youthful teenage aristocrat, slender clean-shaven face, simple black guan and olive silk robe; age-appropriate dignified attire.'
};
const jobs=[];
for(const asset of [...catalog.assets,...(catalog.pages||[])]) {
	if(asset.category==='units' && asset.pages?.length)continue;
  if(fs.existsSync(`${dir}/deliveries/${asset.assetId}.json`) && JSON.parse(fs.readFileSync(`${dir}/deliveries/${asset.assetId}.json`)).texture===asset.target)continue;
  let prompt;
  if(asset.category==='officers') {
    if(asset.reference) {
      prompt=`Use case: identity-preserve / style-transfer. Finished high-definition square officer portrait for 三国赤壁 remaster. The reference is the ORIGINAL in-game portrait of ${asset.name}, ID ${asset.sourceId}. Faithfully repaint THIS individual: preserve exact facial structure, age appearance, expression, head angle, eye direction, skin tone, moustache/beard shape, hairstyle, headdress/helmet shape and colors, armor/robe colors, and visible collar. Do not substitute a generic face or reinterpret the character from folklore. Clean detailed hand-painted classic Chinese strategy-game portrait, crisp metal/fabric/hair, warm subtle upper-left light consistent with source. Fit the full source head and collar into a square portrait with modest side padding, preserve source background tone. A true repaint with new detail, not enlarged pixels or a photographic filter. No text, frame, watermark, modern elements or anime. Preserve the original identity and costume above all else.`;
    } else {
    const details=portraits[asset.sourceId]||`${asset.tier===4?'Civil scholar':'Military officer'}, age ${27+(asset.sourceId*11)%30}, ${faces[asset.sourceId%faces.length]}, ${facialHair[(asset.sourceId*3)%facialHair.length]}, ${asset.tier===4?'black late Han scholar guan and layered silk robe':'modest bronze or iron late Han helmet and lamellar shoulder armor'}, accents of ${factionColors[asset.faction-1]}.`;
    prompt=`Use case: historical-scene. Finished square bust portrait of Chinese Three Kingdoms figure ${asset.name}, stable character ID ${asset.sourceId}, for 三国赤壁 classic historical RTS remaster. ${details} Late Han Chinese attire. Hand-painted 1990s strategy-game portrait with fine brushwork and realistic restrained proportions, warm upper-left light, dark warm brown painterly background. Head and both shoulders framed with margin, eyes readable at 96px. A single distinctive individual face, not a generic shared placeholder. No text, name, UI frame, watermark, photograph, anime or modern elements. Match the portrait series' palette and level of detail.`;
    }
  } else if(['buildings','units','unit-pages'].includes(asset.category)) {
    prompt=`Use case: style-transfer. Finished transparent ${asset.category==='buildings'?'building-stage':'animation'} sprite atlas of ${asset.name}, type ${asset.sourceId}, for 三国赤壁 faithful HD redraw. Repaint ALL reference visual cells with EXACTLY ${asset.columns} equal columns and ${asset.rows} equal rows, keeping the same row-major ordering, EACH cell's exact pose and facing direction, world silhouette, proportions and bottom anchor. ${asset.sourceFrameCount} source cells; unused cells and dimension-label cards remain fully transparent. Reference rows are ORIGINAL animation groups: do not reorganize directions into columns, do not turn a row of rear views into front/side/back views. Preserve the exact source palette: green remains green, brown remains brown, only ORIGINAL blue/cyan parts remain blue/cyan. ${asset.teamTintable?'Original blue/cyan cloth or panels are team-color areas.':'This source has NO team-color pixels: do not introduce blue team sashes, ornaments or cyan clothes.'} Fully repaint crisp restrained hand-painted materials with upper-left light; keep the same character, clothes, hair, equipment and body proportions in every pose. Do not add flowers, baskets, muscles, ponds, rocks, scenery, weapons or ornaments absent from that source cell. Preserve movement/attack/death shapes exactly, never replace them with repeated idle sprites. ${asset.flatSourceShapes?.length?`Source cells ${asset.flatSourceShapes.join(',')} contain flat cyan utility silhouettes: keep their exact flat cyan shape, do not reinterpret them as ponds, rocks or scenery.`:''} Keep reference canvas aspect ${asset.columns*asset.frameWidth}:${asset.rows*asset.frameHeight}; fourfold source resolution if possible. Clean genuine transparent alpha immediately around each sprite; NO colored halo, opaque shadow backdrop, text, grid, watermark, rectangle or checkerboard. Source aliases reuse identical art, no invented variations.`;
  } else if(asset.category==='terrain') {
    prompt=`Use case: style-transfer. Finished transparent terrain tile atlas ${asset.name} for 三国赤壁 HD redraw. Repaint ALL cells in the reference atlas while preserving EXACT canvas proportions, original layout, diamond ground silhouettes, cliff/wall heights, edge cutouts and seamless neighboring variants. Each tile originally ${asset.frameWidth}x${asset.frameHeight}; exact ${asset.columns} columns x ${asset.rows} rows. Preserve original color palette, isometric 2:1 orthographic perspective and upper-left light. Fully redraw detailed hand-painted grass/earth/water/stone/wood material appropriate to reference; no change to geography, no scenery or extra objects. Fourfold reference resolution if possible. True transparent alpha wherever reference is transparent. No labels/grid/text/black rectangle/checkerboard/watermark. All variants required, not one isolated tile.`;
    prompt+=asset.sourceId<6?' These are FLAT continuous ground textures. The diamond is only a clipping mask, never a raised tile or slab. NO bevel, drop shadow, outline or dark rim at the diamond edge. Paint the material fully to each mask boundary, with neighboring variants joining continuously; no visible checkerboard seams. Keep ALL source-empty cells empty in the exact original grid.':' Preserve the source height and color of masonry, soil, fences and props; do not introduce unrelated plants or change grey stone to tan stone.';
    if(asset.dominantColors?.length)prompt+=` Source dominant opaque colors: ${asset.dominantColors.map(x=>`${x.hex} (${Math.round(x.fraction*100)}% of source pixels)`).join(', ')}. Preserve this material palette and overall darkness, no bleaching into beige or adding cinematic color grading.`;
  } else if(asset.category==='backgrounds'&&asset.sourceId===54&&asset.sourceBank==='BMP.LWC')continue;
  else if(asset.category==='backgrounds' && !asset.derivedFromPortraits) {
    prompt=`Use case: style-transfer. Finished high-definition background/interface illustration for 三国赤壁 remaster. Repaint the reference ${asset.name} retaining its original composition, palette, major objects and nostalgic late-Han/1990s Chinese RTS identity. Replace old dithering and blocky details with clean painted material, wood grain, silk/paper and bronze detail. Match the full reference aspect ratio and preserve room for the original interface. Do not invent different scenes, move heroes/ships/desks, or add a UI screenshot. Keep exact source silhouettes and border motifs. If the reference contains text, leave its location clear for live typesetting rather than reproducing text as texture. No modern objects, no watermark, no additional logos. Full opaque background. Original bank ${asset.sourceBank}, frame ${asset.sourceId}, palette ${asset.palette}.`;
  } else continue;
  let characterReference;
  if(asset.category==='unit-pages'&&asset.pageIndex>0) {
    const first=(catalog.pages||[]).find(x=>x.parentAssetId===asset.parentAssetId&&x.pageIndex===0);
    const delivery=first&&`${dir}/deliveries/${first.assetId}.json`;
    if(delivery&&fs.existsSync(delivery)&&JSON.parse(fs.readFileSync(delivery)).texture===first.target) {
      characterReference=path.resolve(first.target);
      prompt+=' The first reference controls exact poses and source colors; the second reference is the approved HD character design from page 0. Keep the same head, hair, face, costume, armor, weapon, proportions and material rendering as that character, while reproducing each pose in the FIRST reference. Do not copy page 0 poses over the current source poses.';
    }
  }
  jobs.push({assetId:asset.assetId,category:asset.category,reference:asset.reference,characterReference,transparent:asset.transparent,prompt});
}
fs.writeFileSync(`${dir}/generation-jobs.json`,JSON.stringify(jobs,null,2));
console.log(JSON.stringify({jobs:jobs.length,officers:jobs.filter(x=>x.category==='officers').length,atlases:jobs.filter(x=>x.category!=='officers').length}));
