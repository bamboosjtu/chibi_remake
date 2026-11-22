import assert from 'node:assert/strict';import {headingAnchors} from './lib/markdown_anchors.mjs';
const anchors=headingAnchors('# 1. 清理\n## 运输船与载员\n## 重复\n## 重复\n```\n## ignored\n```\n');
assert(anchors.has('1-清理')&&anchors.has('运输船与载员')&&anchors.has('重复-1'));assert(!anchors.has('ignored'));assert(!anchors.has('9-清理'));
console.log('MARKDOWN ANCHORS PASS punctuation / CJK / duplicate headings / fenced code / bad fragment rejected');
