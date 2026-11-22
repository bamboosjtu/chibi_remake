extends RefCounted
## Shared campaign labels, IDs and portraits.
const CAMPAIGN_CAO := "chibic"             # 左格：曹操（关卡 id 前缀也是它）
const CAMPAIGN_LIU := "chibil"             # 右格：刘备
const CAMPAIGN_IDS := ["chibic", "chibil"]
const CAMPAIGN_TITLE := {"chibic": "曹操线", "chibil": "刘备线"}
const CAMPAIGN_FACTION := {"chibic": "曹操", "chibil": "刘备"}
const PORTRAIT_PATH := {
	"chibic": "res://art/full/officers/059-portrait-v2.png",
	"chibil": "res://art/full/officers/039-portrait-v2.png",
}
