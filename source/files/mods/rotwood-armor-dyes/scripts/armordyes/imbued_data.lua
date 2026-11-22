-- Armor Dyes: the imbued (elite) boss looks. Made by build_imbued.py (art in anim/ and images/).
-- armour = the armour build (helmet, body and legs); weapons = the weapon builds by weapon type;
-- icons = the inventory icons by slot / weapon type ("images/<atlas>/<icon>.tex").
-- alt = an extra look (imbued_alt_looks in the settings); ref = a reference look, only with
-- imbued_reference_looks = true in the settings; dye_only = a dye in the piece's list only (no mirage patterns);
-- slots = the armour slots the art has (none: helmet, body and legs).
return {
	atlases = { "armordyes_imbued1", "armordyes_imbued2" },
	looks = {
		{
			boss = "megatreemon", key = "imbued", label = "Imbued", alt = false,
			armour = "armor_megatreemon_elite",
			weapons = {
				HAMMER = "weapon_back_hammer_megatreemon_elite",
				POLEARM = "weapon_back_polearm_megatreemon_elite",
				CANNON = "weapon_back_cannon_megatreemon_elite",
				SHOTPUT = "weapon_back_shotput_megatreemon_elite",
				CLEAVER = "weapon_back_cleaver_megatreemon_elite",
				BOW = "weapon_back_bow_megatreemon_elite",
			},
			icons = {
				HEAD = "images/armordyes_imbued1/icon_head_armor_megatreemon_imbued.tex",
				BODY = "images/armordyes_imbued1/icon_body_armor_megatreemon_imbued.tex",
				WAIST = "images/armordyes_imbued1/icon_pants_armor_megatreemon_imbued.tex",
				HAMMER = "images/armordyes_imbued1/icon_weapon_back_hammer_megatreemon_imbued.tex",
				POLEARM = "images/armordyes_imbued1/icon_weapon_back_polearm_megatreemon_imbued.tex",
				CANNON = "images/armordyes_imbued1/icon_weapon_back_cannon_megatreemon_imbued.tex",
				SHOTPUT = "images/armordyes_imbued1/icon_weapon_back_shotput_megatreemon_imbued.tex",
				CLEAVER = "images/armordyes_imbued1/icon_weapon_back_cleaver_megatreemon_imbued.tex",
				BOW = "images/armordyes_imbued1/icon_weapon_back_bow_megatreemon_imbued.tex",
			},
		},
		{
			boss = "megatreemon", key = "imbued_plum", label = "Imbued: Plum", alt = true,
			armour = "armor_megatreemon_elite_plum",
			icons = {
				HEAD = "images/armordyes_imbued1/icon_head_armor_megatreemon_imbued_plum.tex",
				BODY = "images/armordyes_imbued1/icon_body_armor_megatreemon_imbued_plum.tex",
				WAIST = "images/armordyes_imbued1/icon_pants_armor_megatreemon_imbued_plum.tex",
			},
		},
		{
			boss = "owlitzer", key = "imbued", label = "Imbued", alt = false,
			armour = "armor_owlitzer_elite",
			weapons = {
				HAMMER = "weapon_back_hammer_owlitzer_elite",
				POLEARM = "weapon_back_polearm_owlitzer_elite",
				CANNON = "weapon_back_cannon_owlitzer_elite",
				SHOTPUT = "weapon_back_shotput_owlitzer_elite",
				CLEAVER = "weapon_back_cleaver_owlitzer_elite",
				BOW = "weapon_back_bow_owlitzer_elite",
			},
			icons = {
				HEAD = "images/armordyes_imbued1/icon_head_armor_owlitzer_imbued.tex",
				BODY = "images/armordyes_imbued1/icon_body_armor_owlitzer_imbued.tex",
				WAIST = "images/armordyes_imbued1/icon_pants_armor_owlitzer_imbued.tex",
				HAMMER = "images/armordyes_imbued1/icon_weapon_back_hammer_owlitzer_imbued.tex",
				POLEARM = "images/armordyes_imbued1/icon_weapon_back_polearm_owlitzer_imbued.tex",
				CANNON = "images/armordyes_imbued1/icon_weapon_back_cannon_owlitzer_imbued.tex",
				SHOTPUT = "images/armordyes_imbued1/icon_weapon_back_shotput_owlitzer_imbued.tex",
				CLEAVER = "images/armordyes_imbued1/icon_weapon_back_cleaver_owlitzer_imbued.tex",
				BOW = "images/armordyes_imbued1/icon_weapon_back_bow_owlitzer_imbued.tex",
			},
		},
		{
			boss = "bandicoot", key = "imbued", label = "Imbued", alt = false,
			armour = "armor_bandicoot_elite",
			weapons = {
				HAMMER = "weapon_back_hammer_bandicoot_elite",
				POLEARM = "weapon_back_polearm_bandicoot_elite",
				CANNON = "weapon_back_cannon_bandicoot_elite",
				SHOTPUT = "weapon_back_shotput_bandicoot_elite",
				CLEAVER = "weapon_back_cleaver_bandicoot_elite",
				BOW = "weapon_back_bow_bandicoot_elite",
			},
			icons = {
				HEAD = "images/armordyes_imbued1/icon_head_armor_bandicoot_imbued.tex",
				BODY = "images/armordyes_imbued1/icon_body_armor_bandicoot_imbued.tex",
				WAIST = "images/armordyes_imbued1/icon_pants_armor_bandicoot_imbued.tex",
				HAMMER = "images/armordyes_imbued1/icon_weapon_back_hammer_bandicoot_imbued.tex",
				POLEARM = "images/armordyes_imbued1/icon_weapon_back_polearm_bandicoot_imbued.tex",
				CANNON = "images/armordyes_imbued1/icon_weapon_back_cannon_bandicoot_imbued.tex",
				SHOTPUT = "images/armordyes_imbued1/icon_weapon_back_shotput_bandicoot_imbued.tex",
				CLEAVER = "images/armordyes_imbued1/icon_weapon_back_cleaver_bandicoot_imbued.tex",
				BOW = "images/armordyes_imbued1/icon_weapon_back_bow_bandicoot_imbued.tex",
			},
		},
		{
			boss = "thatcher", key = "imbued_blackfur", label = "Imbued: Black Fur", alt = false,
			armour = "armor_thatcher_elite_blackfur_legsfur",
			weapons = {
				HAMMER = "weapon_back_hammer_thatcher_elite_blackfur",
				POLEARM = "weapon_back_polearm_thatcher_elite_blackfur",
				CANNON = "weapon_back_cannon_thatcher_elite_blackfur",
				SHOTPUT = "weapon_back_shotput_thatcher_elite_blackfur",
				CLEAVER = "weapon_back_cleaver_thatcher_elite_blackfur",
				BOW = "weapon_back_bow_thatcher_elite_blackfur",
			},
			icons = {
				HEAD = "images/armordyes_imbued1/icon_head_armor_thatcher_imbued_blackfur.tex",
				BODY = "images/armordyes_imbued1/icon_body_armor_thatcher_imbued_blackfur.tex",
				WAIST = "images/armordyes_imbued1/icon_pants_armor_thatcher_imbued_blackfur.tex",
				HAMMER = "images/armordyes_imbued1/icon_weapon_back_hammer_thatcher_imbued_blackfur.tex",
				POLEARM = "images/armordyes_imbued1/icon_weapon_back_polearm_thatcher_imbued_blackfur.tex",
				CANNON = "images/armordyes_imbued1/icon_weapon_back_cannon_thatcher_imbued_blackfur.tex",
				SHOTPUT = "images/armordyes_imbued1/icon_weapon_back_shotput_thatcher_imbued_blackfur.tex",
				CLEAVER = "images/armordyes_imbued1/icon_weapon_back_cleaver_thatcher_imbued_blackfur.tex",
				BOW = "images/armordyes_imbued1/icon_weapon_back_bow_thatcher_imbued_blackfur.tex",
			},
		},
		{
			boss = "thatcher", key = "imbued", label = "Imbued", alt = false,
			armour = "armor_thatcher_elite",
			weapons = {
				HAMMER = "weapon_back_hammer_thatcher_elite",
				POLEARM = "weapon_back_polearm_thatcher_elite",
				CANNON = "weapon_back_cannon_thatcher_elite",
				SHOTPUT = "weapon_back_shotput_thatcher_elite",
				CLEAVER = "weapon_back_cleaver_thatcher_elite",
				BOW = "weapon_back_bow_thatcher_elite",
			},
			icons = {
				HEAD = "images/armordyes_imbued1/icon_head_armor_thatcher_imbued.tex",
				BODY = "images/armordyes_imbued1/icon_body_armor_thatcher_imbued.tex",
				WAIST = "images/armordyes_imbued1/icon_pants_armor_thatcher_imbued.tex",
				HAMMER = "images/armordyes_imbued1/icon_weapon_back_hammer_thatcher_imbued.tex",
				POLEARM = "images/armordyes_imbued1/icon_weapon_back_polearm_thatcher_imbued.tex",
				CANNON = "images/armordyes_imbued1/icon_weapon_back_cannon_thatcher_imbued.tex",
				SHOTPUT = "images/armordyes_imbued1/icon_weapon_back_shotput_thatcher_imbued.tex",
				CLEAVER = "images/armordyes_imbued1/icon_weapon_back_cleaver_thatcher_imbued.tex",
				BOW = "images/armordyes_imbued1/icon_weapon_back_bow_thatcher_imbued.tex",
			},
		},
		{
			boss = "thatcher", key = "imbued_blackfur_plain", label = "Imbued: Black Fur, plain legs", alt = true,
			armour = "armor_thatcher_elite_blackfur_legs",
			icons = {
				HEAD = "images/armordyes_imbued1/icon_head_armor_thatcher_imbued_blackfur_plain.tex",
				BODY = "images/armordyes_imbued1/icon_body_armor_thatcher_imbued_blackfur_plain.tex",
				WAIST = "images/armordyes_imbued1/icon_pants_armor_thatcher_imbued_blackfur_plain.tex",
			},
		},
		{
			boss = "sedament", key = "imbued", label = "Imbued", alt = false,
			armour = "armor_sedament_elite",
			weapons = {
				HAMMER = "weapon_back_hammer_sedament_elite",
				POLEARM = "weapon_back_polearm_sedament_elite",
				CANNON = "weapon_back_cannon_sedament_elite",
				SHOTPUT = "weapon_back_shotput_sedament_elite",
				CLEAVER = "weapon_back_cleaver_sedament_elite",
				BOW = "weapon_back_bow_sedament_elite",
			},
			icons = {
				HEAD = "images/armordyes_imbued1/icon_head_armor_sedament_imbued.tex",
				BODY = "images/armordyes_imbued1/icon_body_armor_sedament_imbued.tex",
				WAIST = "images/armordyes_imbued1/icon_pants_armor_sedament_imbued.tex",
				HAMMER = "images/armordyes_imbued1/icon_weapon_back_hammer_sedament_imbued.tex",
				POLEARM = "images/armordyes_imbued1/icon_weapon_back_polearm_sedament_imbued.tex",
				CANNON = "images/armordyes_imbued1/icon_weapon_back_cannon_sedament_imbued.tex",
				SHOTPUT = "images/armordyes_imbued1/icon_weapon_back_shotput_sedament_imbued.tex",
				CLEAVER = "images/armordyes_imbued1/icon_weapon_back_cleaver_sedament_imbued.tex",
				BOW = "images/armordyes_imbued1/icon_weapon_back_bow_sedament_imbued.tex",
			},
		},
		{
			boss = "eggzy", key = "imbued", label = "Imbued", alt = false,
			armour = "armor_eggzy_elite_v2",
			weapons = {
				HAMMER = "weapon_back_hammer_eggzy_elite",
				POLEARM = "weapon_back_polearm_eggzy_elite",
				CANNON = "weapon_back_cannon_eggzy_elite",
				SHOTPUT = "weapon_back_shotput_eggzy_elite",
				CLEAVER = "weapon_back_cleaver_eggzy_elite",
				BOW = "weapon_back_bow_eggzy_elite",
			},
			icons = {
				HEAD = "images/armordyes_imbued1/icon_head_armor_eggzy_imbued.tex",
				BODY = "images/armordyes_imbued1/icon_body_armor_eggzy_imbued.tex",
				WAIST = "images/armordyes_imbued1/icon_pants_armor_eggzy_imbued.tex",
				HAMMER = "images/armordyes_imbued1/icon_weapon_back_hammer_eggzy_imbued.tex",
				POLEARM = "images/armordyes_imbued2/icon_weapon_back_polearm_eggzy_imbued.tex",
				CANNON = "images/armordyes_imbued2/icon_weapon_back_cannon_eggzy_imbued.tex",
				SHOTPUT = "images/armordyes_imbued2/icon_weapon_back_shotput_eggzy_imbued.tex",
				CLEAVER = "images/armordyes_imbued2/icon_weapon_back_cleaver_eggzy_imbued.tex",
				BOW = "images/armordyes_imbued2/icon_weapon_back_bow_eggzy_imbued.tex",
			},
		},
		{
			boss = "eggzy", key = "imbued_first", label = "Imbued: First", alt = true,
			armour = "armor_eggzy_elite",
			icons = {
				HEAD = "images/armordyes_imbued2/icon_head_armor_eggzy_imbued_first.tex",
				BODY = "images/armordyes_imbued2/icon_body_armor_eggzy_imbued_first.tex",
				WAIST = "images/armordyes_imbued2/icon_pants_armor_eggzy_imbued_first.tex",
			},
		},
		{
			boss = "eggzy", key = "imbued_salmon", label = "Imbued: Salmon", alt = true,
			armour = "armor_eggzy_elite_v3",
			icons = {
				HEAD = "images/armordyes_imbued2/icon_head_armor_eggzy_imbued_salmon.tex",
				BODY = "images/armordyes_imbued2/icon_body_armor_eggzy_imbued_salmon.tex",
				WAIST = "images/armordyes_imbued2/icon_pants_armor_eggzy_imbued_salmon.tex",
			},
		},
		{
			boss = "grimhollow", key = "imbued", label = "Imbued", alt = false,
			armour = "armor_grimhollow_elite",
			weapons = {
				HAMMER = "weapon_back_hammer_grimhollow_elite",
				POLEARM = "weapon_back_polearm_grimhollow_elite",
				CANNON = "weapon_back_cannon_grimhollow_elite",
				SHOTPUT = "weapon_back_shotput_grimhollow_elite",
				CLEAVER = "weapon_back_cleaver_grimhollow_elite",
				BOW = "weapon_back_bow_grimhollow_elite",
			},
			icons = {
				HEAD = "images/armordyes_imbued2/icon_head_armor_grimhollow_imbued.tex",
				BODY = "images/armordyes_imbued2/icon_body_armor_grimhollow_imbued.tex",
				WAIST = "images/armordyes_imbued2/icon_pants_armor_grimhollow_imbued.tex",
				HAMMER = "images/armordyes_imbued2/icon_weapon_back_hammer_grimhollow_imbued.tex",
				POLEARM = "images/armordyes_imbued2/icon_weapon_back_polearm_grimhollow_imbued.tex",
				CANNON = "images/armordyes_imbued2/icon_weapon_back_cannon_grimhollow_imbued.tex",
				SHOTPUT = "images/armordyes_imbued2/icon_weapon_back_shotput_grimhollow_imbued.tex",
				CLEAVER = "images/armordyes_imbued2/icon_weapon_back_cleaver_grimhollow_imbued.tex",
				BOW = "images/armordyes_imbued2/icon_weapon_back_bow_grimhollow_imbued.tex",
			},
		},
		{
			boss = "grimhollow", key = "imbued_lava", label = "Imbued: Lava", alt = true,
			armour = "armor_grimhollow_elite_lava",
			weapons = {
				HAMMER = "weapon_back_hammer_grimhollow_elite_lava",
				POLEARM = "weapon_back_polearm_grimhollow_elite_lava",
				CANNON = "weapon_back_cannon_grimhollow_elite_lava",
				SHOTPUT = "weapon_back_shotput_grimhollow_elite_lava",
				CLEAVER = "weapon_back_cleaver_grimhollow_elite_lava",
				BOW = "weapon_back_bow_grimhollow_elite_lava",
			},
			icons = {
				HEAD = "images/armordyes_imbued2/icon_head_armor_grimhollow_imbued_lava.tex",
				BODY = "images/armordyes_imbued2/icon_body_armor_grimhollow_imbued_lava.tex",
				WAIST = "images/armordyes_imbued2/icon_pants_armor_grimhollow_imbued_lava.tex",
				HAMMER = "images/armordyes_imbued2/icon_weapon_back_hammer_grimhollow_imbued_lava.tex",
				POLEARM = "images/armordyes_imbued2/icon_weapon_back_polearm_grimhollow_imbued_lava.tex",
				CANNON = "images/armordyes_imbued2/icon_weapon_back_cannon_grimhollow_imbued_lava.tex",
				SHOTPUT = "images/armordyes_imbued2/icon_weapon_back_shotput_grimhollow_imbued_lava.tex",
				CLEAVER = "images/armordyes_imbued2/icon_weapon_back_cleaver_grimhollow_imbued_lava.tex",
				BOW = "images/armordyes_imbued2/icon_weapon_back_bow_grimhollow_imbued_lava.tex",
			},
		},
		{
			boss = "grimhollow", key = "imbued_lava_purple", label = "Imbued: Lava, magenta glow", alt = true,
			armour = "armor_grimhollow_elite_lava_purple",
			weapons = {
				HAMMER = "weapon_back_hammer_grimhollow_elite_lava_purple",
				POLEARM = "weapon_back_polearm_grimhollow_elite_lava_purple",
				CANNON = "weapon_back_cannon_grimhollow_elite_lava_purple",
				SHOTPUT = "weapon_back_shotput_grimhollow_elite_lava_purple",
				CLEAVER = "weapon_back_cleaver_grimhollow_elite_lava_purple",
				BOW = "weapon_back_bow_grimhollow_elite_lava_purple",
			},
			icons = {
				HEAD = "images/armordyes_imbued2/icon_head_armor_grimhollow_imbued_lava_purple.tex",
				BODY = "images/armordyes_imbued2/icon_body_armor_grimhollow_imbued_lava_purple.tex",
				WAIST = "images/armordyes_imbued2/icon_pants_armor_grimhollow_imbued_lava_purple.tex",
				HAMMER = "images/armordyes_imbued2/icon_weapon_back_hammer_grimhollow_imbued_lava_purple.tex",
				POLEARM = "images/armordyes_imbued2/icon_weapon_back_polearm_grimhollow_imbued_lava_purple.tex",
				CANNON = "images/armordyes_imbued2/icon_weapon_back_cannon_grimhollow_imbued_lava_purple.tex",
				SHOTPUT = "images/armordyes_imbued2/icon_weapon_back_shotput_grimhollow_imbued_lava_purple.tex",
				CLEAVER = "images/armordyes_imbued2/icon_weapon_back_cleaver_grimhollow_imbued_lava_purple.tex",
				BOW = "images/armordyes_imbued2/icon_weapon_back_bow_grimhollow_imbued_lava_purple.tex",
			},
		},
		{
			boss = "grimhollow", key = "imbued_lava_red", label = "Imbued: Lava, red bow string", alt = true, ref = true,
			weapons = {
				BOW = "weapon_back_bow_grimhollow_elite_lava_red",
			},
			icons = {
				BOW = "images/armordyes_imbued2/icon_weapon_back_bow_grimhollow_imbued_lava_red.tex",
			},
		},
		{
			boss = "grimhollow", key = "imbued_lava_purple_red", label = "Imbued: Lava, magenta glow, red bow string", alt = true, ref = true,
			weapons = {
				BOW = "weapon_back_bow_grimhollow_elite_lava_purple_red",
			},
			icons = {
				BOW = "images/armordyes_imbued2/icon_weapon_back_bow_grimhollow_imbued_lava_purple_red.tex",
			},
		},
		{
			boss = "bandicoot", key = "imbued_brownmouth", label = "Imbued: Brown Mouth", alt = true, dye_only = true,
			weapons = {
				SHOTPUT = "weapon_back_shotput_bandicoot_elite_brownmouth",
			},
			icons = {
				SHOTPUT = "images/armordyes_imbued2/icon_weapon_back_shotput_bandicoot_imbued_brownmouth.tex",
			},
		},
		{
			boss = "hunter", key = "imbued_enigmox", label = "Imbued Enigmox", alt = false, dye_only = true,
			weapons = {
				HAMMER = "weapon_back_hammer_hunter_enigmox",
				POLEARM = "weapon_back_polearm_hunter_enigmox",
				CANNON = "weapon_back_cannon_hunter_enigmox",
				SHOTPUT = "weapon_back_shotput_hunter_enigmox",
				CLEAVER = "weapon_back_cleaver_hunter_enigmox",
				BOW = "weapon_back_bow_hunter_enigmox",
			},
			icons = {
				HAMMER = "images/armordyes_imbued2/icon_weapon_back_hammer_hunter_imbued_enigmox.tex",
				POLEARM = "images/armordyes_imbued2/icon_weapon_back_polearm_hunter_imbued_enigmox.tex",
				CANNON = "images/armordyes_imbued2/icon_weapon_back_cannon_hunter_imbued_enigmox.tex",
				SHOTPUT = "images/armordyes_imbued2/icon_weapon_back_shotput_hunter_imbued_enigmox.tex",
				CLEAVER = "images/armordyes_imbued2/icon_weapon_back_cleaver_hunter_imbued_enigmox.tex",
				BOW = "images/armordyes_imbued2/icon_weapon_back_bow_hunter_imbued_enigmox.tex",
			},
		},
		{
			boss = "bonejaw", key = "imbued_enigmox", label = "Imbued Enigmox", alt = false, dye_only = true,
			weapons = {
				HAMMER = "weapon_back_hammer_bonejaw_enigmox",
				POLEARM = "weapon_back_polearm_bonejaw_enigmox",
				CANNON = "weapon_back_cannon_bonejaw_enigmox",
				SHOTPUT = "weapon_back_shotput_bonejaw_enigmox",
				CLEAVER = "weapon_back_cleaver_bonejaw_enigmox",
				BOW = "weapon_back_bow_bonejaw_enigmox",
			},
			icons = {
				HAMMER = "images/armordyes_imbued2/icon_weapon_back_hammer_bonejaw_imbued_enigmox.tex",
				POLEARM = "images/armordyes_imbued2/icon_weapon_back_polearm_bonejaw_imbued_enigmox.tex",
				CANNON = "images/armordyes_imbued2/icon_weapon_back_cannon_bonejaw_imbued_enigmox.tex",
				SHOTPUT = "images/armordyes_imbued2/icon_weapon_back_shotput_bonejaw_imbued_enigmox.tex",
				CLEAVER = "images/armordyes_imbued2/icon_weapon_back_cleaver_bonejaw_imbued_enigmox.tex",
				BOW = "images/armordyes_imbued2/icon_weapon_back_bow_bonejaw_imbued_enigmox.tex",
			},
		},
		{
			boss = "basic", key = "baked_enigmox", label = "Enigmox", alt = false, dye_only = true,
			armour = "armor_basic_baked_enigmox",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "basic", key = "baked_enigmox_imbued", label = "Imbued Enigmox", alt = false, dye_only = true,
			armour = "armor_basic_baked_enigmox_imbued",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "basic", key = "baked_enigmox_blue_eyes", label = "Enigmox: Blue Eyes", alt = false, dye_only = true,
			armour = "armor_basic_baked_enigmox_blue_eyes",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "basic", key = "baked_enigmox_imbued_green_eyes", label = "Imbued Enigmox: Green Eyes", alt = false, dye_only = true,
			armour = "armor_basic_baked_enigmox_imbued_green_eyes",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "basic", key = "baked_enigmox_pale_fur", label = "Enigmox: Pale Fur", alt = false, dye_only = true,
			armour = "armor_basic_baked_enigmox_pale_fur",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "basic", key = "baked_enigmox_imbued_cream_fur", label = "Imbued Enigmox: Cream Fur", alt = false, dye_only = true,
			armour = "armor_basic_baked_enigmox_imbued_cream_fur",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "basic", key = "baked_treek", label = "Mother Treek", alt = false, dye_only = true,
			armour = "armor_basic_baked_treek",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "basic", key = "baked_treek_imbued", label = "Imbued Mother Treek", alt = false, dye_only = true,
			armour = "armor_basic_baked_treek_imbued",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "basic", key = "baked_owlitzer", label = "Owlitzer", alt = false, dye_only = true,
			armour = "armor_basic_baked_owlitzer",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "basic", key = "baked_owlitzer_imbued", label = "Imbued Owlitzer", alt = false, dye_only = true,
			armour = "armor_basic_baked_owlitzer_imbued",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "basic", key = "baked_thatcher", label = "Swarm", alt = false, dye_only = true,
			armour = "armor_basic_baked_thatcher",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "basic", key = "baked_thatcher_imbued", label = "Imbued Swarm", alt = false, dye_only = true,
			armour = "armor_basic_baked_thatcher_imbued",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "basic", key = "baked_sedament", label = "Rook", alt = false, dye_only = true,
			armour = "armor_basic_baked_sedament",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "basic", key = "baked_sedament_imbued", label = "Imbued Rook", alt = false, dye_only = true,
			armour = "armor_basic_baked_sedament_imbued",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "basic", key = "baked_eggzy", label = "Shell Drake", alt = false, dye_only = true,
			armour = "armor_basic_baked_eggzy",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "basic", key = "baked_eggzy_imbued", label = "Imbued Shell Drake", alt = false, dye_only = true,
			armour = "armor_basic_baked_eggzy_imbued",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "basic", key = "baked_grimhollow", label = "Grimhollow", alt = false, dye_only = true,
			armour = "armor_basic_baked_grimhollow",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "basic", key = "baked_grimhollow_imbued", label = "Imbued Grimhollow", alt = false, dye_only = true,
			armour = "armor_basic_baked_grimhollow_imbued",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "basic", key = "baked_brick", label = "Brick (baked)", alt = false, dye_only = true,
			armour = "armor_basic_baked_brick",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "basic", key = "baked_umber", label = "Umber (baked)", alt = false, dye_only = true,
			armour = "armor_basic_baked_umber",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "basic", key = "baked_leather", label = "Leather (baked)", alt = false, dye_only = true,
			armour = "armor_basic_baked_leather",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "basic", key = "baked_straw", label = "Straw (baked)", alt = false, dye_only = true,
			armour = "armor_basic_baked_straw",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "basic", key = "baked_sage", label = "Sage (baked)", alt = false, dye_only = true,
			armour = "armor_basic_baked_sage",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "basic", key = "baked_moss", label = "Moss (baked)", alt = false, dye_only = true,
			armour = "armor_basic_baked_moss",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "basic", key = "baked_verdigris", label = "Verdigris (baked)", alt = false, dye_only = true,
			armour = "armor_basic_baked_verdigris",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "basic", key = "baked_frost", label = "Frost (baked)", alt = false, dye_only = true,
			armour = "armor_basic_baked_frost",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "basic", key = "baked_plum", label = "Plum (baked)", alt = false, dye_only = true,
			armour = "armor_basic_baked_plum",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "basic", key = "baked_mauve", label = "Mauve (baked)", alt = false, dye_only = true,
			armour = "armor_basic_baked_mauve",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "basic", key = "baked_soot", label = "Soot (baked)", alt = false, dye_only = true,
			armour = "armor_basic_baked_soot",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "basic", key = "baked_iron", label = "Iron (baked)", alt = false, dye_only = true,
			armour = "armor_basic_baked_iron",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "basic", key = "baked_stone", label = "Stone (baked)", alt = false, dye_only = true,
			armour = "armor_basic_baked_stone",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "basic", key = "baked_bone", label = "Bone (baked)", alt = false, dye_only = true,
			armour = "armor_basic_baked_bone",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "woworm_2", key = "baked_enigmox", label = "Enigmox", alt = false, dye_only = true,
			armour = "armor_woworm_2_baked_enigmox",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "woworm_2", key = "baked_enigmox_imbued", label = "Imbued Enigmox", alt = false, dye_only = true,
			armour = "armor_woworm_2_baked_enigmox_imbued",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "woworm_2", key = "baked_enigmox_blue_eyes", label = "Enigmox: Blue Eyes", alt = false, dye_only = true,
			armour = "armor_woworm_2_baked_enigmox_blue_eyes",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "woworm_2", key = "baked_enigmox_imbued_green_eyes", label = "Imbued Enigmox: Green Eyes", alt = false, dye_only = true,
			armour = "armor_woworm_2_baked_enigmox_imbued_green_eyes",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "woworm_2", key = "baked_enigmox_pale_fur", label = "Enigmox: Pale Fur", alt = false, dye_only = true,
			armour = "armor_woworm_2_baked_enigmox_pale_fur",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "woworm_2", key = "baked_enigmox_imbued_cream_fur", label = "Imbued Enigmox: Cream Fur", alt = false, dye_only = true,
			armour = "armor_woworm_2_baked_enigmox_imbued_cream_fur",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "woworm_2", key = "baked_treek", label = "Mother Treek", alt = false, dye_only = true,
			armour = "armor_woworm_2_baked_treek",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "woworm_2", key = "baked_treek_imbued", label = "Imbued Mother Treek", alt = false, dye_only = true,
			armour = "armor_woworm_2_baked_treek_imbued",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "woworm_2", key = "baked_owlitzer", label = "Owlitzer", alt = false, dye_only = true,
			armour = "armor_woworm_2_baked_owlitzer",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "woworm_2", key = "baked_owlitzer_imbued", label = "Imbued Owlitzer", alt = false, dye_only = true,
			armour = "armor_woworm_2_baked_owlitzer_imbued",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "woworm_2", key = "baked_thatcher", label = "Swarm", alt = false, dye_only = true,
			armour = "armor_woworm_2_baked_thatcher",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "woworm_2", key = "baked_thatcher_imbued", label = "Imbued Swarm", alt = false, dye_only = true,
			armour = "armor_woworm_2_baked_thatcher_imbued",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "woworm_2", key = "baked_sedament", label = "Rook", alt = false, dye_only = true,
			armour = "armor_woworm_2_baked_sedament",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "woworm_2", key = "baked_sedament_imbued", label = "Imbued Rook", alt = false, dye_only = true,
			armour = "armor_woworm_2_baked_sedament_imbued",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "woworm_2", key = "baked_eggzy", label = "Shell Drake", alt = false, dye_only = true,
			armour = "armor_woworm_2_baked_eggzy",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "woworm_2", key = "baked_eggzy_imbued", label = "Imbued Shell Drake", alt = false, dye_only = true,
			armour = "armor_woworm_2_baked_eggzy_imbued",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "woworm_2", key = "baked_grimhollow", label = "Grimhollow", alt = false, dye_only = true,
			armour = "armor_woworm_2_baked_grimhollow",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "woworm_2", key = "baked_grimhollow_imbued", label = "Imbued Grimhollow", alt = false, dye_only = true,
			armour = "armor_woworm_2_baked_grimhollow_imbued",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "woworm_2", key = "baked_brick", label = "Brick (baked)", alt = false, dye_only = true,
			armour = "armor_woworm_2_baked_brick",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "woworm_2", key = "baked_umber", label = "Umber (baked)", alt = false, dye_only = true,
			armour = "armor_woworm_2_baked_umber",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "woworm_2", key = "baked_leather", label = "Leather (baked)", alt = false, dye_only = true,
			armour = "armor_woworm_2_baked_leather",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "woworm_2", key = "baked_straw", label = "Straw (baked)", alt = false, dye_only = true,
			armour = "armor_woworm_2_baked_straw",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "woworm_2", key = "baked_sage", label = "Sage (baked)", alt = false, dye_only = true,
			armour = "armor_woworm_2_baked_sage",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "woworm_2", key = "baked_moss", label = "Moss (baked)", alt = false, dye_only = true,
			armour = "armor_woworm_2_baked_moss",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "woworm_2", key = "baked_verdigris", label = "Verdigris (baked)", alt = false, dye_only = true,
			armour = "armor_woworm_2_baked_verdigris",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "woworm_2", key = "baked_frost", label = "Frost (baked)", alt = false, dye_only = true,
			armour = "armor_woworm_2_baked_frost",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "woworm_2", key = "baked_plum", label = "Plum (baked)", alt = false, dye_only = true,
			armour = "armor_woworm_2_baked_plum",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "woworm_2", key = "baked_mauve", label = "Mauve (baked)", alt = false, dye_only = true,
			armour = "armor_woworm_2_baked_mauve",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "woworm_2", key = "baked_soot", label = "Soot (baked)", alt = false, dye_only = true,
			armour = "armor_woworm_2_baked_soot",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "woworm_2", key = "baked_iron", label = "Iron (baked)", alt = false, dye_only = true,
			armour = "armor_woworm_2_baked_iron",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "woworm_2", key = "baked_stone", label = "Stone (baked)", alt = false, dye_only = true,
			armour = "armor_woworm_2_baked_stone",
			slots = { "HEAD" },
			icons = {
			},
		},
		{
			boss = "woworm_2", key = "baked_bone", label = "Bone (baked)", alt = false, dye_only = true,
			armour = "armor_woworm_2_baked_bone",
			slots = { "HEAD" },
			icons = {
			},
		},
	},
}
