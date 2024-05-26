#include "ArchiveReporter.hpp"

Core::Set<Red::ResourcePath> App::ArchiveReporter::s_knownBrokenPaths = {
    11667225134805795463ull,
    16905695163656296102ull, // base\localization\ru-ru\voiceovermap.json
    11096380914756954598ull, // base\localization\ru-ru\voiceovermap_1.json
    13599273398505966278ull, // base\localization\ru-ru\voiceovermap_helmet.json
    2804385064543512661ull, // base\localization\ru-ru\voiceovermap_holocall.json
    12384636868793699295ull, // base\localization\ru-ru\voiceovermap_rewinded.json
    14155995615789255623ull, // ep1\localization\ru-ru\voiceovermap.json
    12384636868793699295ull, // base\localization\ru-ru\voiceovermap_rewinded.json
    16536705523510859240ull, // ep1\localization\ru-ru\voiceovermap_rewinded.json
    13599273398505966278ull, // base\localization\ru-ru\voiceovermap_helmet.json
    3903362976908136045ull, // ep1\localization\ru-ru\voiceovermap_helmet.json
    2804385064543512661ull, // base\localization\ru-ru\voiceovermap_holocall.json
    2685430272643116154ull, // ep1\localization\ru-ru\voiceovermap_holocall.json
    6825014065494026304ull, // base\localization\en-us\subtitles\quest\q105\q105_10_transition.json
    15560413981220560032ull, // base\localization\en-us\subtitles\quest\q001\q001_intro_04b_technicians.json
    17187737396784657830ull, // base\localization\en-us\subtitles\quest\q001\q001_04c_boxing_match.json
    1709105392468103665ull, // base\localization\en-us\subtitles\quest\q103\q103_chicken_test.json
    15731418496636392082ull, // base\localization\en-us\subtitles\quest\sq028\sq028_08_aftermath.json
    14300223422541198273ull, // base\localization\en-us\subtitles\quest\sq030\sq030_10_sex.json
    15505214641242001929ull, // base\localization\en-us\subtitles\quest\q005\q005_00_jackie_afterlife_chat.json
    13945979658533217153ull, // base\localization\en-us\subtitles\quest\q001\q001_00_aaa_jackie_takedown_comment.json
    3525617374363740570ull, // base\localization\en-us\subtitles\open_world\community\e3_q110_parking_kids_chat.json
    8094176497816130028ull, // base\localization\en-us\subtitles\media\tv\test.json
    2092154009840669248ull, // base\localization\en-us\subtitles\quest\q110\q110_00_depictions.json
    15415159332104595913ull, // base\localization\en-us\subtitles\quest\q101\q101_07d_wilson.json
    15156247025334096990ull, // base\localization\en-us\subtitles\quest\weyland\weyland_default.json
    16644985099035968603ull, // base\localization\en-us\subtitles\quest\sq026\sq026_13a_dolls.json
    7471691853124775891ull, // base\localization\en-us\subtitles\media\fluff\trauma_team_1.json
    498619054346813748ull, // base\localization\en-us\subtitles\media\fluff\trauma_team_2.json
    1334439872556276917ull, // base\localization\en-us\subtitles\media\fluff\trauma_team_3.json
    14428483483292850790ull, // base\localization\en-us\subtitles\media\fluff\trauma_team_4.json
    13901544324104621679ull, // base\localization\en-us\subtitles\media\fluff\trauma_team_5.json
    5623439853602694897ull, // base\localization\en-us\subtitles\quest\q110\q110_ow_fluff_gate.json
    15524827529160088574ull, // base\localization\en-us\subtitles\open_world\community\e3_q110_butchery_corridor_man_big.json
    3928202566150387488ull, // base\localization\en-us\subtitles\open_world\community\e3_q110_butchery_turret.json
    12130216892916449580ull, // base\localization\en-us\subtitles\open_world\community\e3_q110_market_watching_tv.json
    4928710764560725156ull, // base\localization\en-us\subtitles\quest\q110\q110_00b_truck_scene.json
    1152428895429240498ull, // base\localization\en-us\subtitles\open_world\community\e3_q110_rascal_man.json
    5493466152052593255ull, // base\localization\en-us\subtitles\quest\mq034\mq034_xx_debug.json
    3004551306515817880ull, // base\localization\en-us\subtitles\open_world\voicesets\civilian_reprimend_voiceset_scene_block.json
    11648961211724795117ull, // base\localization\en-us\subtitles\open_world\voicesets\civilian_voiceset_scene_block.json
    2457526110830223195ull, // base\localization\en-us\subtitles\quest\q001\q001_intro_04d_hologram_cutscene.json
    12456624730962574075ull, // base\localization\en-us\subtitles\quest\sq029\sq029_06a_sex.json
    10483935435043796174ull, // base\localization\en-us\subtitles\open_world\voicesets\civ_low_m_92_chn_25_big.json
    8917793801875925699ull, // base\localization\en-us\subtitles\quest\mq015\mq015_00_chickentest.json
    17823205076050549602ull, // base\localization\en-us\subtitles\quest\vset\vset_emmerick.json
    16855015139860626883ull, // base\localization\en-us\subtitles\open_world\minor_activities\ma_wat_lch_14_shooting.json
    12555642121581430739ull, // base\localization\en-us\subtitles\media\intro\sh0600.json
    9789633104065281864ull, // base\localization\en-us\subtitles\media\intro\sh0100.json
    10796879437689833743ull, // base\localization\en-us\subtitles\media\intro\sh0200.json
    6243059961359373573ull, // base\localization\en-us\subtitles\media\intro\sh0400.json
    8947942267855314716ull, // base\localization\en-us\subtitles\media\intro\sh0500.json
    10623358862836870738ull, // base\localization\en-us\subtitles\media\intro\sh0700.json
    6889123727414292761ull, // base\localization\en-us\subtitles\media\intro\sh0800.json
    9429022396388524960ull, // base\localization\en-us\subtitles\media\intro\sh0900.json
    4237554708706218439ull, // base\localization\en-us\subtitles\media\intro\sh2000.json
    2820475389818989259ull, // base\localization\en-us\subtitles\media\loading_screens\depictions_of_city_template.json
    9931701464969191447ull, // base\localization\en-us\subtitles\open_world\minor_activities\ma_wat_nid_02_chicken_test.json
    11953855018704670ull, // base\localization\en-us\subtitles\media\benchmark\benchmark.json
    17054851119116191554ull, // base\localization\en-us\subtitles\media\loading_screens\wat_kab_.json
    16061662267893512459ull, // base\localization\en-us\subtitles\media\loading_screens\wat_lch_.json
    7223930877686018838ull, // base\localization\en-us\subtitles\open_world\scenes\la_execution_01.json
    3583682842936958529ull, // base\localization\en-us\subtitles\open_world\scenes\la_execution_02.json
    7470386486984124048ull, // base\localization\en-us\subtitles\open_world\scenes\la_execution_03.json
    14110776629722409077ull, // base\localization\en-us\subtitles\open_world\scenes\la_gang_hostilities_01.json
    14670591304295340442ull, // base\localization\en-us\subtitles\open_world\scenes\la_gang_hostilities_02.json
    13294617926736457922ull, // base\localization\en-us\subtitles\open_world\scenes\la_sexual_violence_01.json
    11584580018766072359ull, // base\localization\en-us\subtitles\open_world\scenes\la_hools_01.json
    4298254237204881976ull, // base\localization\en-us\subtitles\open_world\scenes\la_hools_02.json
    10352189174410731580ull, // base\localization\en-us\subtitles\open_world\scenes\la_human_trafficking_01.json
    1532728934563037493ull, // base\localization\en-us\subtitles\open_world\scenes\la_organ_harvesting_01.json
    7645402594736387035ull, // base\localization\en-us\subtitles\open_world\scenes\la_robbery_01.json
    6747378303127518780ull, // base\localization\en-us\subtitles\open_world\scenes\la_robbery_02.json
    15155660871412755897ull, // base\localization\en-us\subtitles\open_world\scenes\la_street_violence_01.json
    5223810711337979790ull, // base\localization\en-us\subtitles\open_world\scenes\la_street_violence_02.json
    15513410871034850455ull, // base\localization\en-us\subtitles\open_world\scenes\la_street_violence_03.json
    7060534650401908721ull, // base\localization\en-us\subtitles\media\loading_screens\ccn_dwn_.json
    9991143077590878679ull, // base\localization\en-us\subtitles\media\loading_screens\ccr_crp_.json
    2205156903453802949ull, // base\localization\en-us\subtitles\media\loading_screens\det_dc.json
    10085430579368485886ull, // base\localization\en-us\subtitles\media\loading_screens\dre_.json
    746977719182147274ull, // base\localization\en-us\subtitles\media\loading_screens\far_.json
    15579251098922359660ull, // base\localization\en-us\subtitles\media\loading_screens\hey_gle_.json
    13577265037995791117ull, // base\localization\en-us\subtitles\media\loading_screens\hey_vis.json
    5840246296727109079ull, // base\localization\en-us\subtitles\media\loading_screens\hey_wel.json
    2650876923237444699ull, // base\localization\en-us\subtitles\media\loading_screens\tlp_.json
    18348058685561915769ull, // base\localization\en-us\subtitles\media\loading_screens\tlp2_.json
    9227656312156515803ull, // base\localization\en-us\subtitles\media\loading_screens\wat_awf.json
    7497737550975562327ull, // base\localization\en-us\subtitles\media\loading_screens\wat_nid_.json
    10600688316431935434ull, // base\localization\en-us\subtitles\media\loading_screens\far2_.json
    10026543047944149465ull, // base\localization\en-us\subtitles\media\intro\sh0300_2.json
    3505810290298897644ull, // base\localization\en-us\subtitles\media\loading_screens\bad_nor_.json
    6205538186102244885ull, // base\localization\en-us\subtitles\media\loading_screens\pac_coa_.json
    18442788486072916533ull, // base\localization\en-us\subtitles\media\loading_screens\pac_wwe_.json
    17099697770506258635ull, // base\localization\en-us\subtitles\media\loading_screens\sdo_arr_.json
    13803816755545165486ull, // base\localization\en-us\subtitles\media\loading_screens\sdo_ran.json
    15719834156383995587ull, // base\localization\en-us\subtitles\media\loading_screens\wes_cha_.json
    17684716300529862919ull, // base\localization\en-us\subtitles\media\loading_screens\wes_jap.json
    18068517084669439011ull, // base\localization\en-us\subtitles\media\loading_screens\wes_noa_.json
    12301114825078479746ull, // base\localization\en-us\subtitles\media\loading_screens\bad_sou_.json
    5714577481810919274ull, // base\localization\en-us\subtitles\open_world\community\wat_lch_afterlife_bouncer.json
    6272061775043389576ull, // base\localization\en-us\subtitles\media\intro\sh0300_3.json
    14670694819331277237ull, // base\localization\en-us\subtitles\media\intro\sh1000_2.json
    4498913535298029399ull, // base\localization\en-us\subtitles\open_world\minor_activities\ma_bls_ina_se1_17_chicken_test.json
    4090948665101272775ull, // base\localization\en-us\subtitles\media\fluff\an_chip_in.json
    2170573012997407164ull, // base\localization\en-us\subtitles\media\fluff\an_guns_n_horses.json
    12560310841055929188ull, // base\localization\en-us\subtitles\media\fluff\an_just_ads.json
    17042126325225292924ull, // base\localization\en-us\subtitles\media\fluff\an_n54_news.json
    10554530034614170393ull, // base\localization\en-us\subtitles\media\fluff\an_safe_n_sound.json
    11320040933116399289ull, // base\localization\en-us\subtitles\media\fluff\an_wns_news.json
    13677842794100522421ull, // base\localization\en-us\subtitles\media\fluff\an_your_business.json
    7179951036711080309ull, // base\localization\en-us\subtitles\media\fluff\an_ziggy_q.json
    5816673093182633132ull, // base\localization\en-us\subtitles\open_world\minor_activities\ma_hey_rey_06_chicken_test.json
    10207188267380037498ull, // base\localization\en-us\subtitles\open_world\vendors\hey_gle_junkshop_01.json
    4889979140539553276ull, // base\localization\en-us\subtitles\open_world\scenes\la_street_violence_04.json
    15675834388915883399ull, // base\localization\en-us\subtitles\open_world\scenes\la_drugs_01.json
    1078341638198821757ull, // base\localization\en-us\subtitles\open_world\scenes\la_robbery_03.json
    601937406047009230ull, // base\localization\en-us\subtitles\open_world\scenes\la_robbery_04.json
    10752498093659017431ull, // base\localization\en-us\subtitles\open_world\scenes\la_robbery_05.json
    6712432606334211880ull, // base\localization\en-us\subtitles\open_world\scenes\la_robbery_06.json
    18296773955955516989ull, // base\localization\en-us\subtitles\open_world\scenes\la_street_violence_05.json
    5835126790229145031ull, // base\localization\en-us\subtitles\open_world\city_scenes\cs_homeless_trashcan_player_scene.json
    17866138092783754506ull, // base\localization\en-us\subtitles\open_world\city_scenes\cs_garbage_collectors_scene_sync.json
    7507405175320078086ull, // base\localization\en-us\subtitles\open_world\voicesets\apuc_enemies_missing_scene_block.json
    16043648091381920951ull, // base\localization\en-us\subtitles\quest\default\default_com_lizzies_scenes.json
    7554320700301323941ull, // base\localization\en-us\subtitles\quest\q000\q000_com_lizzies_scenes.json
    5307265880021464501ull, // base\localization\en-us\subtitles\quest\q004\q004_com_lizzies_scenes.json
    15345106984776816693ull, // base\localization\en-us\subtitles\quest\q105\q105_com_lizzies_scenes.json
    14341710761247012912ull, // base\localization\en-us\subtitles\open_world\street_stories\sts_wat_nid_07_recording_scene.json
    7445811099082457528ull, // base\localization\en-us\subtitles\media\loading_screens\wat_wlc_.json
    696197362508048656ull, // base\localization\en-us\subtitles\open_world\community\megabuilding_police_chat.json
    823063323194024275ull, // base\localization\en-us\subtitles\open_world\minor_activities\ma_wat_kab_08_johnny_and_clues.json
    5893609938256514665ull, // base\localization\en-us\subtitles\quest\sq032\sq032_00_sickness.json
    2404601885050829846ull, // base\localization\en-us\subtitles\open_world\minor_activities\ma_wat_lch_06_clues_n_mood.json
    14196817324125901647ull, // base\localization\en-us\subtitles\open_world\minor_activities\ma_wat_nid_15_investigation.json
    14977146756514865697ull, // base\localization\en-us\subtitles\media\loading_screens\bsc_d_a.json
    4048733019328545635ull, // base\localization\en-us\subtitles\media\loading_screens\det.json
    9399200668923727172ull, // base\localization\en-us\subtitles\open_world\minor_activities\ma_wat_nid_03_scene.json
    7815134599916380730ull, // base\localization\en-us\subtitles\quest\mq030\mq030_02_jinguji_community.json
    709522678813450246ull, // base\localization\en-us\subtitles\open_world\minor_activities\ma_cct_dtn_03_scenes.json
    5098072286881971327ull, // base\localization\en-us\subtitles\open_world\minor_activities\ma_std_rcr_11_02_carthrow.json
    13001010256173625891ull, // base\localization\en-us\subtitles\media\difficulty_selection\difficulty_selection_scene.json
    17958027033575656610ull, // base\localization\en-us\subtitles\quest\q001\q001_01aa_epilog_house_av.json
    15249191287325217620ull, // base\localization\en-us\subtitles\open_world\city_scenes\cs_gun_suicide.json
    16497434024084594049ull, // base\localization\en-us\subtitles\quest\reggie\reggie_holocall.json
    2263127613903776040ull, // base\localization\en-us\subtitles\open_world\city_scenes\cs_biohazard_materials_dmg_loop.json
    4717641066374397847ull, // base\localization\en-us\subtitles\quest\blue\blue_moon_holocall.json
    17309789903175693019ull, // base\localization\en-us\subtitles\quest\anders\anders_hellman_holocall.json
    14944522037398089573ull, // base\localization\en-us\subtitles\quest\anthony\anthony_gilchrist_holocall.json
    8672220738691178903ull, // base\localization\en-us\subtitles\quest\bob\bob_holocall.json
    6269715474887649107ull, // base\localization\en-us\subtitles\quest\carol\carol_holocall.json
    10068387162555873983ull, // base\localization\en-us\subtitles\quest\cassidy\cassidy_holocall.json
    10025776756753128351ull, // base\localization\en-us\subtitles\quest\claire\claire_holocall.json
    16194321744860548863ull, // base\localization\en-us\subtitles\quest\coach\coach_holocall.json
    1929143681090633759ull, // base\localization\en-us\subtitles\quest\cynthia\cynthia_holocall.json
    13506810261424547383ull, // base\localization\en-us\subtitles\quest\dakota\dakota_holocall.json
    538624977156912545ull, // base\localization\en-us\subtitles\quest\delamain\delamain_holocall.json
    3960594121158698095ull, // base\localization\en-us\subtitles\quest\dex\dex_holocall.json
    8292892434674566111ull, // base\localization\en-us\subtitles\quest\dino\dino_holocall.json
    183880764021491807ull, // base\localization\en-us\subtitles\quest\elizabeth\elizabeth_holocall.json
    9936312072369290729ull, // base\localization\en-us\subtitles\quest\emmerick\emmerick_holocall.json
    8061702837731240341ull, // base\localization\en-us\subtitles\quest\evelyn\evelyn_holocall.json
    6806652443252663359ull, // base\localization\en-us\subtitles\quest\frank\frank_holocall.json
    4225844120713001519ull, // base\localization\en-us\subtitles\quest\hanako\hanako_holocall.json
    7251295179274832337ull, // base\localization\en-us\subtitles\quest\jackie\jackie_holocall.json
    3843665556530880223ull, // base\localization\en-us\subtitles\quest\jefferson\jefferson_holocall.json
    15753282668842590727ull, // base\localization\en-us\subtitles\quest\jenkins\jenkins_holocall.json
    7044587181669068675ull, // base\localization\en-us\subtitles\quest\judy\judy_holocall.json
    3754979887238089015ull, // base\localization\en-us\subtitles\quest\kerry\kerry_holocall.json
    14255357259857062369ull, // base\localization\en-us\subtitles\quest\kirk\kirk_holocall.json
    5440319061788752187ull, // base\localization\en-us\subtitles\quest\lizzy\lizzy_holocall.json
    17165274812358217706ull, // base\localization\en-us\subtitles\quest\mama\mama_welles_holocall.json
    17298834747201026728ull, // base\localization\en-us\subtitles\quest\maman\maman_brigitte_holocall.json
    11427418469922727327ull, // base\localization\en-us\subtitles\quest\meredith\meredith_holocall.json
    5691855596730584943ull, // base\localization\en-us\subtitles\quest\misty\misty_holocall.json
    5932362187408163675ull, // base\localization\en-us\subtitles\quest\mitch\mitch_holocall.json
    9894540554631281757ull, // base\localization\en-us\subtitles\quest\mr\mr_blue_eyes_holocall.json
    7364182336931290804ull, // base\localization\en-us\subtitles\quest\mr\mr_hands_holocall.json
    12615607851616091082ull, // base\localization\en-us\subtitles\quest\mr\mr_stud_holocall.json
    15287700054006815937ull, // base\localization\en-us\subtitles\quest\muamar\muamar_holocall.json
    152590538415230801ull, // base\localization\en-us\subtitles\quest\ncpd\ncpd_dispatcher_holocall.json
    10541988716749248991ull, // base\localization\en-us\subtitles\quest\padre\padre_holocall.json
    846855382364900111ull, // base\localization\en-us\subtitles\quest\panam\panam_holocall.json
    7721363601751617751ull, // base\localization\en-us\subtitles\quest\pepe\pepe_holocall.json
    10564724416476620639ull, // base\localization\en-us\subtitles\quest\placide\placide_holocall.json
    949638799128985745ull, // base\localization\en-us\subtitles\quest\rachel\rachel_holocall.json
    7984941028447682623ull, // base\localization\en-us\subtitles\quest\river\river_holocall.json
    6171084029857338087ull, // base\localization\en-us\subtitles\quest\rogue\rogue_holocall.json
    2271138763890077077ull, // base\localization\en-us\subtitles\quest\sandra\sandra_holocall.json
    10959202911022742741ull, // base\localization\en-us\subtitles\quest\saul\saul_holocall.json
    8797119363645561705ull, // base\localization\en-us\subtitles\quest\scorpion\scorpion_holocall.json
    14379646554513141287ull, // base\localization\en-us\subtitles\quest\tbug\tbug_holocall.json
    10965552024570930259ull, // base\localization\en-us\subtitles\quest\teddy\teddy_holocall.json
    9866940062426671861ull, // base\localization\en-us\subtitles\quest\victor\victor_holocall.json
    7369366234046143615ull, // base\localization\en-us\subtitles\quest\wakako\wakako_holocall.json
    1904400665747218943ull, // base\localization\en-us\subtitles\quest\wilson\wilson_holocall.json
    9049326575676052949ull, // base\localization\en-us\subtitles\quest\yorinobu\yorinobu_holocall.json
    7485748300515995539ull, // base\localization\en-us\subtitles\quest\nancy\nancy_holocall.json
    6663378715669398785ull, // base\localization\en-us\subtitles\quest\conspiracy\conspiracy_holocall.json
    13905671921880942151ull, // base\localization\en-us\subtitles\quest\jessy\jessy_holocall.json
    11542188644856185087ull, // base\localization\en-us\subtitles\quest\ozob\ozob_holocall.json
    7051672129535312615ull, // base\localization\en-us\subtitles\quest\santiago\santiago_holocall.json
    5321595517020226635ull, // base\localization\en-us\subtitles\quest\spider\spider_murphy_holocall.json
    94713153281123391ull, // base\localization\en-us\subtitles\quest\thompson\thompson_holocall.json
    5495758861175302275ull, // base\localization\en-us\subtitles\quest\weyland\weyland_holocall.json
    16946055907197844911ull, // base\localization\en-us\subtitles\quest\takemura\takemura_holocall.json
    9009247733071715018ull, // base\localization\en-us\subtitles\media\loading_screens\depiction_of_city_test.json
    11701140933151398927ull, // base\localization\en-us\subtitles\quest\r3no\r3no_holocall.json
    4545157498152521349ull, // base\localization\en-us\subtitles\quest\joss\joss_holocall.json
    6524862280830676133ull, // base\localization\en-us\subtitles\quest\dennis\dennis_holocall.json
    10146100286727785441ull, // base\localization\en-us\subtitles\open_world\minor_activities\ma_bls_ina_se1_22_scene.json
    9872589055361319644ull, // base\localization\en-us\subtitles\open_world\street_stories\sts_cct_dtn_04_av_scene.json
    418771620435754895ull, // base\localization\en-us\subtitles\quest\stephen\stephen_holocall.json
    7489344908039697235ull, // base\localization\en-us\subtitles\quest\nix\nix_holocall.json
    3449726361379754597ull, // base\localization\en-us\subtitles\open_world\mini_world_stories\mws_wat_01.json
    1512993350760453813ull, // base\localization\en-us\subtitles\open_world\mini_world_stories\mws_hey_01_follow.json
    13994684593118403850ull, // base\localization\en-us\subtitles\open_world\mini_world_stories\mws_arr_01.json
    15135164992952244974ull, // base\localization\en-us\subtitles\quest\wilsons\wilsons_shooting_range.json
    6987923592934676532ull, // base\localization\en-us\subtitles\open_world\mini_world_stories\mws_wat_03_cop_lines.json
    6492371608549509538ull, // base\localization\en-us\subtitles\open_world\mini_world_stories\mws_se5_01.json
    5071972111565237533ull, // base\localization\en-us\subtitles\open_world\mini_world_stories\mws_pac_01.json
    14885527567979008171ull, // base\localization\en-us\subtitles\open_world\mini_world_stories\mws_se5_03_arcade.json
    1064832095484543032ull, // base\localization\en-us\subtitles\open_world\mini_world_stories\mws_cc_01_vending_shock.json
    12660755148439945669ull, // base\localization\en-us\subtitles\quest\mq005\mq005_02_passout.json
    9010536428649985132ull, // base\localization\en-us\subtitles\open_world\mini_world_stories\mws_wbr_01.json
    6327820973245223525ull, // base\localization\en-us\subtitles\quest\karl\karl_ginsky_holocall.json
    9844628335254309342ull, // base\localization\en-us\subtitles\quest\pedro\pedro_aimar_holocall.json
    2314500253917229209ull, // base\localization\en-us\subtitles\open_world\mini_world_stories\mws_pac_05.json
    3032852063104536057ull, // base\localization\en-us\subtitles\open_world\mini_world_stories\mws_se5_06.json
    3581984217756057149ull, // base\localization\en-us\subtitles\quest\holofixer\holofixer_scene.json
    6657469063850936890ull, // ep1\localization\en-us\subtitles\quest\ari\ari_holocall.json
    18353345868702946594ull, // ep1\localization\en-us\subtitles\quest\dawn\dawn_holocall.json
    9395766128440442882ull, // ep1\localization\en-us\subtitles\quest\hawkins\hawkins_holocall.json
    7296783217893504410ull, // ep1\localization\en-us\subtitles\quest\isiah\isiah_holocall.json
    4546216838189231842ull, // ep1\localization\en-us\subtitles\quest\kurtz\kurtz_holocall.json
    10547524051333118190ull, // ep1\localization\en-us\subtitles\quest\mac\mac_holocall.json
    4941747907443911822ull, // ep1\localization\en-us\subtitles\quest\mullins\mullins_holocall.json
    18428720347266987614ull, // ep1\localization\en-us\subtitles\quest\myers\myers_holocall.json
    9798872072195437718ull, // ep1\localization\en-us\subtitles\quest\reed\reed_holocall.json
    2931312558173399778ull, // ep1\localization\en-us\subtitles\quest\shawn\shawn_holocall.json
    5185362638750624770ull, // ep1\localization\en-us\subtitles\quest\songbird\songbird_holocall.json
    9687117229514270342ull, // ep1\localization\en-us\subtitles\open_world\street_stories\sts_ep1_12_voodoboys_guard_q110_friendly_scene.json
    14275322328988511898ull, // ep1\localization\en-us\subtitles\quest\8ug8ear\8ug8ear_holocall.json
    4988526897212268306ull, // ep1\localization\en-us\subtitles\quest\jurij\jurij_holocall.json
    6097548041205072734ull, // ep1\localization\en-us\subtitles\quest\q305\q305_03_holocall_to_reed_pre_ambush.json
    16230753486316188986ull, // ep1\localization\en-us\subtitles\quest\chang\chang_hoon_nam_holocall.json
    12020529060602844172ull, // ep1\localization\en-us\subtitles\quest\mq304\mq304_00_city_scenes.json
    13483870710843719818ull, // ep1\localization\en-us\subtitles\quest\alex\alex_holocall.json
    829815861198393659ull, // ep1\localization\en-us\subtitles\open_world\scene\chat_example.json
    249120348438722917ull, // ep1\localization\en-us\subtitles\quest\bunker\bunker_security_holocall.json
    14164671920222276866ull, // ep1\localization\en-us\subtitles\quest\elif\elif_holocall.json
    1650113732476664997ull, // ep1\localization\en-us\subtitles\quest\q305\q305_08f_outer_bunker_minor_hallucinations.json
    3667677955075005962ull, // ep1\localization\en-us\subtitles\media\open_world\news_sts_ep1_06_zembinsky_missing.json
    4697829571187871358ull, // ep1\localization\en-us\subtitles\media\open_world\news_sts_ep1_07_nele_killed.json
    7319575058799321321ull, // ep1\localization\en-us\subtitles\media\open_world\news_sts_ep1_07_nele_lived.json
    11194250097006758909ull, // ep1\localization\en-us\subtitles\media\open_world\news_sts_ep1_07_terrorists.json
    13432337046389240299ull, // ep1\localization\en-us\subtitles\media\open_world\news_sts_ep1_12_hacked_cyberware.json
    8477041530813366760ull, // ep1\localization\en-us\subtitles\media\open_world\news_sts_ep1_12_hackers_captured.json
    14179221814870406466ull, // ep1\localization\en-us\subtitles\media\open_world\news_sts_ep1_13_interview.json
    11550824419472965572ull, // ep1\localization\en-us\subtitles\media\open_world\news_sts_ep1_13_leak.json
    6660015876636888306ull, // ep1\localization\en-us\subtitles\quest\q302\q302_squot_safehouse.json
    17721674142722138830ull, // ep1\localization\en-us\subtitles\quest\q306\q306_03b_oa_staff_reactions.json
    16494703908005204914ull, // ep1\localization\en-us\subtitles\overlays_quest\judy\judy_holocall.json
    2925353348540163378ull, // ep1\localization\en-us\subtitles\overlays_quest\kerry\kerry_holocall.json
    9884199145470964090ull, // ep1\localization\en-us\subtitles\overlays_quest\river\river_holocall.json
    3143943619699066179ull, // ep1\localization\en-us\subtitles\media\loading_screens\loading_screen_ep1_02_after_q301_crash.json
    11998983641353480330ull, // ep1\localization\en-us\subtitles\media\loading_screens\loading_screen_ep1_03_after_q304_deal.json
    10817843004146853175ull, // ep1\localization\en-us\subtitles\media\loading_screens\loading_screen_ep1_04_after_q305_the_bunker.json
    16770365552281542383ull, // ep1\localization\en-us\subtitles\media\loading_screens\loading_screen_ep1_05_after_q306_spaceport.json
    17271752688328892076ull, // ep1\localization\en-us\subtitles\overlays_quest\victor\victor_holocall.json
    14776984022978860330ull, // ep1\localization\en-us\subtitles\quest\janet\janet_holocall.json
    13804772265290302983ull, // ep1\localization\en-us\subtitles\quest\mark\mark_bana_holocall.json
    4398152510614197240ull, // ep1\localization\en-us\subtitles\overlays_quest\mq005\mq005_02_passout.json
    16389373250885280475ull, // ep1\localization\en-us\subtitles\open_world\mini_world_stories\mws_cz_02_scene_01.json
    2870817267701380164ull, // ep1\localization\en-us\subtitles\open_world\mini_world_stories\mws_cz_04.json
    14321966108667556001ull, // ep1\localization\en-us\subtitles\quest\officer\officer_daniels_holocall.json
    4568108465801271898ull, // ep1\localization\en-us\subtitles\open_world\vendors\cz_stadium_gunsmith_01_johnny_easter_egg.json
    13839972908489584082ull, // ep1\localization\en-us\subtitles\open_world\sandbox_activities\cbj_ep1_11_facial_scene.json
    10210898540686081978ull, // ep1\localization\en-us\subtitles\overlays_quest\panam\panam_holocall.json
    799614804077722441ull, // ep1\localization\en-us\subtitles\overlay_open_world\mini_world_stories\mws_se5_03_arcade.json
    12971766947039424001ull, // ep1\localization\en-us\subtitles\quest\q306\q306_07a_viewing_gallery.json
    3938195356625209436ull, // ep1\localization\en-us\subtitles\quest\q301\q301_00a_standalone_opening.json
    2656953732831757963ull, // ep1\localization\en-us\subtitles\open_world\world_stories\wst_ep1_hgp_105_scene.json
    16533664233554108034ull, // ep1\localization\en-us\subtitles\open_world\world_stories\wst_ep1_mdo_103_scene.json
    70497995623399042ull, // ep1\localization\en-us\subtitles\quest\q305\q305_08h_outer_bunker_killroom.json
    5618561391048049054ull, // ep1\localization\en-us\subtitles\quest\q305\q305_09f_inner_bunker_killroom.json
    17118025343679485108ull, // user\piotr_gieroba\effects\static_effect.es
    14090293621554587512ull, // test\gameplay\strike\debugstrike.es
    3398472962771865045ull, // base\gameplay\game_effects\projectiles\bullet.es
    3466660726395908010ull, // base\gameplay\game_effects\attack_effects\ragdoll\ragdoll.es
    14703013922431402450ull,
    14072978149773510328ull, // \descriptor.journaldesc
    8228473524453639483ull, // base\fx\weapons\power\handguns\corporate\p_hg_corp_01_lvl1_muzzle.effect
    3549392514259171176ull, // base\fx\weapons\smart\rifles\corporate\s_rifle_corp_01_lvl1_bullet_trail.effect
    4266592589219495655ull, // base\fx\weapons\smart\rifles\corporate\s_rifle_corp_01_lvl1_bullet_trail_sand.effect
    9055597644719343280ull, // base\fx\weapons\smart\rifles\corporate\s_rifle_corp_01_lvl1_muzzle_eject.effect
    8710078452882632598ull, // base\gameplay\factories\test\environment_test.csv
    12612181945219120155ull, // sectors\_generated\ar_markers.json
    6300934772051896454ull,
    11849900913431717288ull,
    14095938516815192205ull, // base\materials\ui_main_hud.mt
    11111682928633937833ull, // base\materials\ui_main_menu.mt
    7620792422861055719ull, // base\characters\main_npc\demo_vicky\a0_001_wa__right_demo_vicky_lights.mesh
    628304274119368619ull, // base\animations\anim_motion_database\cover_action.csv
    16047644507638096565ull, // base\gameplay\combat_gadgets\grenades\frag_grenade\frag_grenade_effect.es
    9562379042030747676ull, // base\animations\cyberware\mantisblade\mantisblade_01_enemy_face.anims
    15310493020661802135ull, // base\animations\weapon\one_handed_blunt\face_one_handed_blunt_dildo_finisher.anims
    11268589481128994795ull,
    3756571308554796504ull,
    1631982893041224884ull,
    2546904568145001183ull,
    4948850813592949642ull,
    7198681696135856109ull,
    10645248755204606594ull,
    12593654176977020009ull,
    12677887371896107733ull,
    12983702032593715491ull,
    15435500940593151981ull,
    16625305172545565288ull,
    17890197104103574117ull,
    3781742406182772623ull,
    4679265168385700629ull,
    8395477426590373572ull,
    10373613071553508254ull,
    11900052379616407111ull,
    12190096409172737305ull,
    15405744121097392407ull,
    17117594807170815592ull,
    2851798006086439770ull,
    16228693057780638872ull,
    4212424567859029620ull,
    6448407400260747489ull,
    7952397978930323418ull,
    8134872650426974092ull,
    10973445748162586643ull,
    17260443095502951794ull,
    17548951180839284803ull,
    2814005410135323482ull,
    5143955558431415106ull,
    4361856824525015480ull,
    7575548892290406265ull,
    3197105074862851034ull,
    660798737768738167ull,
    1244475619444182786ull,
    4240258497901042658ull,
    4688438631185999906ull,
    5259566683822461864ull,
    7492268532228957788ull,
    13075249972258488213ull,
    13998302748379780300ull,
    14767783659735186540ull,
    2282426951754653906ull,
    3248491136464710739ull,
    4162217930930660549ull,
    8441083875255069720ull,
    11409771823950587555ull,
    6790867877009516355ull,
    9319414149687285085ull,
    14953172997520295712ull,
    16309787048745130946ull,
    17830107131808485849ull,
    3229294508788324594ull,
    4041133450793638927ull,
    5603179620148161075ull,
    8939884301281898199ull,
    11368089936366793010ull,
    13678440196195745051ull,
    5524109445934804505ull,
    3384655581798203484ull,
    4434739520257622475ull,
    6434259286347463037ull,
    10779192176832538333ull,
    13802366959093169725ull,
    8529294641469182355ull,
    7177725289409966574ull, // base\gameplay\gui\fullscreen\ripperdoc\target.ent
    14400540986322705624ull, // base\gameplay\gui\fullscreen\vendor\target.ent
    4035625248673376261ull,
    5711290539210191265ull,
    8303858713075639831ull,
    10641972293239599296ull,
    12386635738681490536ull,
    12607448843543157059ull,
    13953763425079415258ull,
    1666187471609180760ull,
    8494870005965327246ull,
    8910782634198392471ull,
    11642378069122098354ull,
    17026626105863749162ull,
    658113631883891987ull,
    1525190042548909231ull,
    2355181984809131197ull,
    2563862776815938974ull,
    3245980724385374703ull,
    3388184651717608979ull,
    4339918835769142993ull,
    5710165244723896244ull,
    5946467485873345541ull,
    6616983968868264243ull,
    8071129709376441038ull,
    8393144564087242691ull,
    8917044608084355602ull,
    9477372032452037472ull,
    10708339627511459772ull,
    11102019155100255358ull,
    11160224786813163165ull,
    11717946427641287890ull,
    12290996450152448700ull,
    14133903152298303893ull,
    16320581301424006721ull,
    17480129501952602599ull,
    256712407611412135ull,
    4303389916253201359ull,
    705725186279940355ull,
    3391652477559112394ull,
    3393752349480577778ull,
    14729762007285332481ull,
    12574240578781080408ull,
    5896156376476192535ull,
    8056922238459952473ull,
    12121670095702346327ull,
    15193884416915770984ull,
    1796032423124358953ull,
    4036037879205518283ull, // test\level_design\ld_kit\meshes\primitives\box\ld_kit_box_glass_1x1x1m_a.mesh
    673042214838878266ull,
    1732573835375678946ull,
    2754240972655782677ull,
    10516003911721437307ull,
    12036222600175067247ull,
    16403788844656004271ull,
    18050043938033962515ull,
    4802333609178085440ull, // base\gameplay\devices\default_device_interaction.interaction
    11430285584918589649ull,
    9825448324728846373ull, // base\workspots\bar\bar\generic__stand_bar_can__remove_drink__01.workspot
    12308141018891671529ull, // base\quest\main_quests\prologue\q003\workspots\q003_07a_jackie_holds_spider.workspot
    3559238455357933103ull, // base\quest\main_quests\prologue\q003\workspots\jackie_stand_waiting.workspot
    4094371632772948306ull, // base\quest\main_quests\prologue\q003\workspots\q003_jackie_stands_next_to_the_car.workspot
    634915947263022185ull, // base\quest\main_quests\prologue\q003\workspots\q003_jackie_after_deal.workspot
    11487742062408620482ull, // base\quest\main_quests\prologue\q003\workspots\jackie_looking_peeks_window.workspot
    12234082061010049846ull, // base\quest\main_quests\prologue\q003\workspots\jackie_stand_waiting_elevator.workspot
    5318513501809605591ull, // base\quest\main_quests\prologue\q003\workspots\q003_mealstrom_jackie_elevator.workspot
    8484891070634287925ull, // base\quest\main_quests\prologue\q003\workspots\jackie_stand_waiting_corridor_2.workspot
    10232183175460030646ull, // base\quest\main_quests\prologue\q003\workspots\jackie_alerted.workspot
    15375988756990926419ull, // base\workspots\common\wall\generic__stand_wall_lean_right__stand_around__03.workspot
    9415995752567650103ull, // base\workspots\archetype\corpo\corpo__stand_ground_jukebox__use__01.workspot
    16719033700269684649ull, // base\quest\side_quests\sq026\scenes\lipsync\en\sq026_07_judys\tom.anims
    1836274035108523802ull, // base\quest\side_quests\sq026\scenes\lipsync\en\sq026_07_judys\roxanne.anims
    11849980430957602798ull, // base\quest\side_quests\sq026\scenes\lipsync\en\sq026_07_judys\maiko.anims
    4039238150331905268ull, // ep1\animations\npc\gameplay\man_average\gang\unarmed\ma_gang_unarmed_reaction_death.anims
    5029586337525823077ull, // base\gameplay\ai\archetypes\vehicles\base_vehicle.aiarch
    2042103499386981772ull, // ep1\animations\npc\gameplay\woman_average\gang\unarmed\wa_gang_unarmed_reaction_death.anims
    6989483941748410158ull, // ep1\animations\npc\gameplay\man_average\gang\unarmed\face_ma_gang_unarmed_reaction_death.anims
    14954544347651837484ull, // base\quest\main_quests\prologue\q003\workspots\q003_jackie_in_the_car.workspot
    5652643468045900349ull, // ep1\animations\npc\gameplay\man_fat\gang\unarmed\mf_gang_unarmed_reaction_death.anims
    14991456851754484460ull, // ep1\animations\npc\gameplay\man_big\gang\unarmed\mb_gang_unarmed_reaction_death.anims
    782240114803387306ull, // base\open_world\city_scenes\templates\noncombat\cs_homeless_trashcan\lipsync\en\cs_homeless_trashcan_player_scene\v.anims
    4072059517063462694ull, // base\gameplay\gui\widgets\devices\tv\tv_atlas.inkatlas
    4592603131828552269ull, // base\gameplay\gui\fullscreen\placeholder_chardev\chardev_placeholder_atlas.inkatlas
    18269475428674666941ull, // base\gameplay\gui\widgets\shapes\shapes.inkshapecollection
    3324805608216975500ull, // base\gameplay\gui\widgets\crosshair\atlas_crosshair_basic.inkatlas
    1435589920621466688ull, // base\gameplay\gui\widgets\crosshair\supertemporarytestatlas.inkatlas
    16533767141346916145ull, // base\animations\npc\gameplay\man_average\maelstrom\shotgun\w_shotgun_dual\w_shotgun_dual_ma__rcv1.anims
    6592318733059938925ull, // ep1\openworld\mini_world_stories\combat_zone\mws_cz_15\scenes\lipsync\en\mws_cz_15_best_dressed_device\v.anims
    10585526399794743532ull, // base\quest\side_quests\sq032\scenes\lipsync\en\sq032_00_sickness\johnny.anims
    3869353023306324209ull, // base\quest\minor_quests\mq033\scenes\lipsync\en\mq033_1_first_grafitti\misty.anims
    4142113860666867570ull, // base\quest\main_quests\prologue\q003\scenes\lipsync\en\q003_08_stout\votest_oliver.anims
    12678881341201925455ull, // base\quest\main_quests\prologue\q003\scenes\lipsync\en\q003_08_stout\johnny.anims
    10889785885315776421ull, // base\quest\main_quests\prologue\q003\scenes\lipsync\en\q003_08_stout\meredith_stout.anims
    10175261419483985175ull, // base\quest\main_quests\prologue\q001\scenes\lipsync\en\q001_02a_fistfight_tutorial\arasaka_ai.anims
    793139339525730461ull, // base\worlds\03_night_city\_compiled\default\ep1\e058ef08e02e1dcc.streamingsector_inplace
    12628943611489526080ull,
    3555203180697648183ull,
    14035398040263693162ull,
    17156098568101883172ull,
    4691978711598818486ull,
    3996491221616261303ull,
    9731612109784491042ull,
    17074797891922700080ull,
    166043100663134029ull,
    4564793951313889808ull,
    6436185790849957529ull, // base\prefabs\environment\decoration\_decoration_set\bottles\do_not_use\decoset_trash_packaging_pile_b.mesh
    11435804289909587637ull,
    11049293897729860770ull,
    10844751471223375374ull,
    6057631188506461781ull,
    10557401041314547508ull,
    12984667360838698667ull,
    7168567684096759621ull,
    13236812660226125814ull,
    6249941552613376636ull,
    16768473343167070141ull,
    3259108505202160307ull,
    14789090173149073319ull,
    4014457307987795206ull,
    11872769952289320765ull,
    7663124204840520520ull,
    6901171576943582354ull,
    9409873742517296685ull,
    9468016636999605568ull,
    4624442520022981090ull,
    7891756446407416058ull,
    1874781106850613655ull,
    9183531175711436319ull,
    9002985674979294037ull,
    13728908199947783969ull,
    1889218779055036320ull, // test\level_design\ld_kit\meshes\primitives\box\ld_kit_box_black_1x1x1m_a.mesh
    17043405229731860080ull,
    18192354839235863077ull,
    2259139705850193329ull, // test\level_design\ld_kit\meshes\primitives\box\box_basematerial.w2mesh
    15382837125326764739ull, // base\surfaces\materials\plastic\plastic_tech\plastic_tech_01_300_m.xbm
    1442193992437561821ull, // base\environment\decoration\doors\single\door_single_sliding\textures\ml_door_single_sliding_c_bare.mlsetup
    10788769087688676053ull, // base\environment\decoration\doors\single\door_single_sliding\textures\ml_door_single_sliding_c_masksset.mlmask
    4182182619268525693ull, // base\environment\decorations\garbage\trash_cardboard\trash_cardboard_d.mesh
    2233280122712310719ull, // base\quest\minor_quests\mq008\scenes\lipsync\en\mq008_01_party_chats\gang_6th_f_02_mex_25.anims
    5614621711427757351ull, // ep1\quest\main_quests\q301\scenes\lipsync\en\q301_00a_standalone_opening\v.anims
    13768823815186330216ull, // base\gameplay\gui\fullscreen\main_menu\test_loading_saves_placeholder\save_list_ref.inkatlas
    615491547470059640ull, // base\characters\player\pma\e3\feet\s1_001_pma_shoe__converse\s1_001_pma_shoe__converse_lights.mesh
    1716702187171781786ull,
    15195387815288923358ull,
    8604900197863224608ull,
    6268917947641067314ull,
    90033030717651392ull, // base\worlds\03_night_city\_compiled\default\ep1\bdc42cc63fb5dbb2.streamingsector_inplace
    8394486547209730122ull, // test\level_design\ld_kit\meshes\wall\ld_kit_wall_6x1m_a.mesh
    9409185922777902418ull, // test\level_design\ld_kit\meshes\wall_window\ld_kit_wall_4m_window_b_middle.mesh
    3639094317211634452ull,
    8579758680240338466ull,
    12143442333577779760ull,
    847642677126501096ull, // test\level_design\ld_kit\meshes\primitives\sphere.mesh
    560687975702174736ull,
    16975531297052726798ull, // base\environment\decoration\advertising\digital\billboards\textures\33x10_hor_cirrus_cola.xbm
    194995785193659094ull, // base\environment\decoration\advertising\digital\billboards\textures\33x10_hor_combat_cab_v2_c.xbm
    5807322553843538452ull, // base\environment\decoration\advertising\digital\billboards\textures\33x10_hor_el_guapo.xbm
    15569028769928101474ull, // base\environment\decoration\advertising\digital\billboards\textures\33x10_hor_skin_chrome.xbm
    12313126831323931360ull, // base\environment\decoration\advertising\digital\billboards\textures\33x10_hor_combat_cab_v2_a.xbm
    13963527665991742127ull, // base\environment\decoration\advertising\digital\billboards\textures\33x10_hor_midnight_lady.xbm
    1732304537414200143ull, // base\environment\decoration\advertising\digital\billboards\textures\33x10_hor_gomorrah.xbm
    10984142539711414424ull, // base\environment\decoration\advertising\digital\billboards\textures\33x10_hor_nicola_a.xbm
    6390594682047099012ull, // base\fx\environment\screens\sky_panorama.xbm
    6289033717489228492ull,
    9645261427044635212ull, // base\animations\npc\gameplay\man_average\corpo\katana\ma_corpo_katana_locomotion_combat_close.anims
    14609590095506533551ull, // base\open_world\street_stories\pacifica\west_wind_estates\sts_pac_wwd_05\scenes\lipsync\en\sts_pac_wwd_05_bouncer\gang_ani_m_10_bra_20_big.anims
    14670288728819178200ull, // base\open_world\scenes\dancefloors\lipsync\en\dancefloor_cs_goons_rave_party\v.anims
    5386252812494293582ull, // base\open_world\street_stories\watson\kabuki\sts_wat_kab_02\scenes\lipsync\en\sts_wat_kab_02_scene\gang_mls_m_10_enus_25.anims
    6295169955689247157ull, // base\quest\main_quests\part1\q105\scenes\lipsync\en\q105_04_jigjig_street\judy.anims
    8033764394995413197ull, // base\quest\main_quests\part1\q105\scenes\lipsync\en\q105_04_jigjig_street\civ_prst_f_04_chn_30.anims
    14472633501339219262ull, // base\quest\main_quests\part1\q105\scenes\lipsync\en\q105_04_jigjig_street\civ_prst_f_01_enus_30.anims
    8441217912059740788ull, // base\quest\main_quests\part1\q105\scenes\lipsync\en\q105_04_jigjig_street\votest_andrew.anims
    9790490870933663689ull, // base\open_world\vendors\pacifica\west_wind_estate\pac_wwd_guns_01\lipsync\en\pac_wwd_guns_01\civ_mid_f_73_car_40.anims
    17604339195810594780ull, // base\open_world\vendors\badlands\inland_avenue_se5\bls_ina_se5_junkshop_01\lipsync\en\bls_ina_se5_junkshop_01\civ_mid_m_57_jap_40.anims
    16410439211092346978ull, // base\open_world\vendors\santo_domingo\arroyo\std_arr_gunsmith_01\lipsync\en\std_arr_gunsmith_01\civ_mid_m_10_enus_30_big.anims
    9223256271785037251ull, // base\open_world\vendors\westbrook\charter_hill\wbr_hil_foodshop_01\lipsync\en\wbr_hil_foodshop_01\civ_high_m_43_engb_40.anims
    9360035660858066823ull, // base\open_world\vendors\westbrook\charter_hill\wbr_hil_clothingshop_01\lipsync\en\wbr_hil_clothingshop_01\civ_mid_f_64_jap_30.anims
    8685846096775064828ull, // base\open_world\vendors\santo_domingo\rancho_coronado\std_rcr_gunsmith_01\lipsync\en\std_rcr_gunsmith_01\civ_low_f_107_bra_25.anims
    14305698475583829418ull, // base\open_world\vendors\badlands\inland_avenue_se1\bls_ina_se1_junkshop_01\lipsync\en\bls_ina_se1_junkshop_01\civ_mid_m_51_chn_40.anims
    7796973998388900452ull, // base\quest\minor_quests\mq006\scenes\lipsync\en\mq006_02_finale\civ_low_m_110_car_20.anims
    5744460116286275625ull, // base\open_world\vendors\badlands\inland_avenue_se5\bls_ina_se5_melee_01\lipsync\en\bls_ina_se5_melee_01\civ_low_f_109_bra_40.anims
    13822097413450854542ull, // base\quest\main_quests\part1\q115\scenes\versions\patch0\lipsync\en\q115_00b_hanako\civ_high_m_23_jap_40.anims
    2460790363036303083ull, // base\quest\main_quests\part1\q115\scenes\versions\patch0\lipsync\en\q115_00b_hanako\civ_high_m_09_afam_30.anims
    1070770234018927418ull, // base\quest\main_quests\part1\q115\scenes\versions\patch0\lipsync\en\q115_00b_hanako\hanako.anims
    2847525383818351311ull, // ep1\quest\main_quests\q303\scenes\lipsync\en\q303_10_concert_braindance\v.anims
    7545779846110143634ull, // base\open_world\vendors\city_center\corpo_plaza\cct_cpz_food_01\lipsync\en\cct_cpz_food_01\civ_high_f_44_engb_50.anims
    8817004185127968812ull, // ep1\quest\minor_quests\mq303\scenes\lipsync\en\mq303_06_vendor\tool.anims
    4543672990083841710ull, // ep1\quest\minor_quests\mq303\scenes\lipsync\en\mq303_01_hook\lina.anims
    12373531299254023253ull, // ep1\quest\minor_quests\mq303\scenes\lipsync\en\mq303_01_hook\shank.anims
    1237008647777174733ull, // base\open_world\vendors\badlands\inland_avenue_se1\bls_ina_se1_gunsmith_02\lipsync\en\bls_ina_se1_gunsmith_02\civ_mid_f_38_afam_30.anims
    16626923253280992104ull, // base\open_world\vendors\heywood\glen\hey_gle_foodshop_02\lipsync\en\hey_gle_foodshop_02\civ_low_m_72_mex_50.anims
    4441962912986853828ull, // ep1\openworld\mini_world_stories\combat_zone\mws_cz_04\scene\lipsync\en\mws_cz_04\droid_combat.anims
    6298022683707449858ull, // ep1\openworld\mini_world_stories\combat_zone\mws_cz_04\scene\lipsync\en\mws_cz_04\civ_low_f_93_chn_10_chd.anims
    2025445495622287436ull, // ep1\openworld\vendors\monument_av\cz_monument_av_ripperdoc_anderson\lipsync\en\cz_monument_av_ripperdoc_anderson\anthony_anderson.anims
    9686338688647549470ull, // ep1\quest\minor_quests\mq304\scenes\lipsync\en\mq304_05_bennett\gang_kml_m_08_chn_30.anims
    9077930234701781085ull, // ep1\quest\minor_quests\mq304\scenes\lipsync\en\mq304_05_bennett\bennett.anims
    10491068943917544069ull, // ep1\quest\minor_quests\mq301\scenes\lipsync\en\mq301_06_contacts\kurtz.anims
    4086991303310288635ull, // ep1\quest\minor_quests\mq301\scenes\lipsync\en\mq301_06_contacts\jurij.anims
    14905126937488719473ull, // ep1\quest\minor_quests\mq301\scenes\lipsync\en\mq301_06_contacts\kruger.anims
    847941717770069466ull, // ep1\quest\minor_quests\mq301\scenes\lipsync\en\mq301_06_contacts\paco.anims
    1396594548312381416ull, // ep1\openworld\vendors\cz_foodshop_01\lipsync\en\cz_foodshop_01\civ_cbz_f_03_afam_30.anims
    8404522086254490559ull, // base\gameplay\gui\widgets\crosshair\megatron\atlas_megatron_hud.inkatlas
    11122632172810842659ull, // base\gameplay\gui\common\simple_dot.inkatlas
    16228063059749886517ull,
    15529996232588830196ull,
    4670319699175681068ull,
    13517940159598671766ull,
    4973988291215684944ull,
    12448768245039059752ull,
    9507505895586312195ull, // ep1\fx\quest\q305\q305_water_stream.ent
    7645724739822943726ull,
    10021385164229512437ull,
    9826710929089331389ull,
    17081799367167721140ull,
    4980545548382959338ull,
    8702313159627283403ull,
    11385306962312089863ull,
    14764459797164422158ull,
    17709976535314306836ull,
    10603855664292726820ull,
    919514092783635622ull,
    1115234675807763148ull,
    1901576587511098491ull,
    4029847575273263009ull,
    4702398062536519173ull,
    5508047494640881472ull,
    5862244062772356329ull,
    9331797004649891540ull,
    10454757659635110589ull,
    12726005892706830316ull,
    15050224354365389574ull,
    15124935411818004444ull,
    17688948518702669719ull,
    824647392620123458ull,
    4482602868838092810ull,
    11908153721518751660ull,
    14595084558140829226ull,
    5786348357968585031ull, // base\environment\decoration\advertising\digital\billboards\textures\21x9_hor_orbital_air.xbm
    13951658315660338738ull, // base\weapons\firearms\handgun\arasaka_yukimura\entities\meshes\textures\ml_w_handgun__arasaka_yukimura__base1_02_default_masksset.mlmask
    13722368990697011143ull, // base\weapons\firearms\handgun\arasaka_yukimura\entities\meshes\textures\ml_w_handgun__arasaka_yukimura__base1_02_default_masksset.mlsetup
    12836206333423938432ull, // base\weapons\firearms\handgun\arasaka_yukimura\entities\meshes\textures\tpp\w_handgun__arasaka_yukimura__base1_02_n01.xbm
    8672918746313615564ull, // base\weapons\firearms\handgun\arasaka_yukimura\entities\meshes\textures\ml_w_handgun__arasaka_yukimura__base1_02_default_masksset_maskssettpp.mlmask
    436097873112162732ull,
    690720331270521661ull,
    2549856673686485815ull,
    5647461065142637064ull,
    8499572007829106093ull,
    12863988047953981736ull,
    15161806481717388843ull,
    16359418754606764190ull,
    17015046532319784748ull,
    5340499180925822829ull,
    18293698811838454693ull,
    1740279990286873096ull,
    946689000067138199ull,
    11710462980186748751ull,
    3575370701914874235ull,
    12365635798452349432ull,
    11136944008656160694ull,
    2462866889555394643ull,
    17220668577176724583ull,
    11091361134192906143ull,
    8131467813633197613ull,
    9369877588910424439ull,
    10818025326111018366ull,
    13405685111167157066ull,
    16515744900504932607ull,
    1522859646135334199ull,
    3064573236017468545ull,
    3497849021632424914ull,
    4135218688770335967ull,
    5451698087604714411ull,
    7805227514369483030ull,
    9020507815090450133ull,
    12229393253886532907ull,
    16144920940157863358ull,
    16958091483237386868ull,
    17716573430994910645ull,
    18136429689978779315ull,
    315687055575562979ull,
    1189599893924190481ull,
    2754084346470949357ull,
    5334097275362523816ull,
    5532342002996023430ull,
    6575589641069446232ull,
    9277671699000991931ull,
    9900856701453709164ull,
    12411361675227386068ull,
    16065357430846583665ull,
    17804236639869807439ull,
    9853474057797026254ull,
    10475849157828043815ull,
    11035521869303976800ull,
    12202910970873140293ull,
    16170842190092867541ull,
    1483264523734158767ull,
    17277125966157701252ull,
    9832278918208528116ull,
    9876489507122721194ull,
    16809154822357700816ull,
    17782522435093617704ull,
    2455414765584931355ull,
    398542232951839519ull,
    1816307478014075454ull,
    10003767291419064748ull,
    12030730773559131305ull,
    35083350102507149ull, // base\open_world\street_stories\santo_domingo\rancho_corronado\sts_std_rcr_03\scenes\lipsync\en\sts_std_rcr_03_meeting_hayashi\civ_high_m_28_bra_40.anims
    8623633553217237530ull, // base\open_world\vendors\santo_domingo\arroyo\std_arr_medicstore_01\lipsync\en\std_arr_medicstore_01\civ_mid_m_04_enus_30.anims
    5689328254686718993ull, // base\open_world\vendors\city_center\downtown\cct_dtn_ripdoc_01\lipsync\en\cct_dtn_ripdoc_01\civ_low_m_46_afam_40.anims
    7993419396679597473ull, // base\open_world\vendors\santo_domingo\arroyo\std_arr_ripperdoc_01\lipsync\en\std_arr_ripperdoc_01\civ_high_m_18_jap_25.anims
    10869753351900391806ull, // base\open_world\vendors\watson\northside\wat_nid_gunsmith_01\lipsync\en\wat_nid_gunsmith_01\civ_low_m_10_enus_30.anims
    350443890220614234ull, // base\quest\minor_quests\mq000\scenes\lipsync\en\mq000_01_apartment\v.anims
    8510293227128271044ull, // base\open_world\vendors\heywood\glen\hey_gle_gunsmith_01\lipsync\en\hey_gle_gunsmith_01\civ_low_m_05_enus_40.anims
    14458927655943155441ull, // base\quest\minor_quests\mq015\scenes\lipsync\en\mq015_05_afterlife\nix.anims
    422523415958748057ull, // base\quest\side_quests\sq032\scenes\lipsync\en\sq032_05_fifth_episode\johnny.anims
    7934784169968356780ull, // base\fx\environment\smoke_steam\steam_fans.particle
    9838901154554038852ull, // base\characters\common\hair\textures\hair_profiles\brown_001.hp
    8150987924053132516ull, // base\quest\holocalls\victor\lipsync\en\victor_holocall\victor_vector.anims
    1993673784737750404ull,
    3915697773959683707ull, // base\surfaces\materials\glass\windows_opaque\windows_opaque_01_200_d.xbm
    15372073420557890299ull, // base\animations\player\shared\body_carry_strong.anims
    1096470456104100291ull, // base\animations\player\shared\body_carry_friendly.anims
    11046533773606631805ull, // base\worlds\03_night_city\_compiled\default\ep1\d1ad27992135d8cc.streamingsector_inplace
    3734372515701218441ull,
    9767328504779043844ull, // ep1\fx\quest\q304\lab\q304_zap_to_left_soldier.effect
    1720096121084590359ull,
    9470911170236960122ull,
    6624696963080540221ull,
    7005446773630084250ull,
    11666891367445046782ull,
    11195375102092548717ull,
    16514233880272415269ull,
    13381792719571435626ull,
    421203924168632886ull, // test\environment\temp_box\1x1x1_box_brick.mesh
    9423773622876015194ull, // ep1\characters\appearances\main_npc\proxy\bella_default\bella_default.mesh
    11539657794791886221ull, // ep1\quest\main_quests\q304\scenes\versions\patch2_0\lipsync\en\q304_07b_lab\gang_kml_m_08_chn_30.anims
    4215764393546274690ull, // ep1\quest\main_quests\q304\scenes\versions\patch2_0\lipsync\en\q304_07b_lab\gang_kml_m_13_mex_30.anims
    8273838755259854670ull, // ep1\quest\main_quests\q304\scenes\versions\patch2_0\lipsync\en\q304_07b_lab\gang_kml_m_03_bra_30.anims
    6260953378246703531ull, // ep1\openworld\street_stories\sts_ep1_12\scenes\lipsync\en\sts_ep1_12_final_scene\gang_vdb_m_03_car_30_mt.anims
    6306503615304449855ull, // ep1\openworld\street_stories\sts_ep1_12\scenes\lipsync\en\sts_ep1_12_final_scene\droid_combat.anims
    16491463751398837581ull, // ep1\openworld\street_stories\sts_ep1_12\scenes\lipsync\en\sts_ep1_12_final_scene\alan_noel.anims
    15248834289789764953ull, // base\weapons\firearms\attachments\scope\w_att__scope_short_06\entities\meshes\textures\ml_w_att__scope_short_06_01_default_masksset.mlmask
    11509141204779359078ull, // base\weapons\firearms\attachments\scope\w_att__scope_short_06\entities\meshes\textures\ml_w_att__scope_short_06_01_default_masksset.mlsetup
    7034754478187310103ull,
    7500118969759998364ull,
    15622076101168353485ull,
    13335949642088548120ull, // ep1\gameplay\gui\world\adverts\crystal_palace\crystal_palace.xbm
    17430112309349059328ull, // ep1\gameplay\gui\world\adverts\dark_star\dark_star_720p.xbm
    7561502446733356066ull, // ep1\gameplay\gui\world\adverts\spaceport\spaceport.xbm
    4363598992020357451ull, // base\fx\vehicles\visual_customization\v_visual_customization_sfx.effect
    9939321351975102323ull, // base\fx\vehicles\_lights\veh_brake_lights.effect
    10312836233739489145ull, // ep1\quest\main_quests\q306\scenes\lipsync\en\q306_08_control_tower\johnny.anims
    6967409598428628181ull, // ep1\quest\main_quests\q306\scenes\lipsync\en\q306_08_control_tower\reed.anims
    16387054771389605592ull, // ep1\quest\main_quests\q306\scenes\lipsync\en\q306_08_control_tower\sec_high_m_03_afam_40.anims
    4174999170848356766ull, // ep1\quest\main_quests\q306\scenes\lipsync\en\q306_08_control_tower\sec_high_m_05_jap_30_big.anims
};
