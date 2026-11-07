# Bài học từ các trận đã ghi

Tự sinh bởi `tools/review_match.sh` (`sim/review.gd`), README "Ghi trận / phân tích". Không sửa tay: mỗi lần chạy
dựng lại cả file từ dòng `<!-- data ... -->` của từng trận (phân tích lại 1 trận = thay mục cũ). Ván cờ `bot` không vào đây.
Chi tiết trận: `<id>.review.md` cạnh file `.replay`.

## Mẫu lặp lại (2 trận)
- Người chơi:
  - dư vàng khi có thành trống (`gold_unspent`): 2 trận, 16 lần — lặp lại
  - mất làng (`village_lost`): 2 trận, 11 lần — lặp lại
  - bỏ lỡ nước giết chắc (`missed_sure_kill`): 2 trận, 9 lần — lặp lại
  - đánh làm địch lên cấp (`fed_promotion`): 2 trận, 6 lần — lặp lại
  - quân lẻ bị giết (`lone_unit_killed`): 2 trận, 5 lần — lặp lại
  - mất thành (`castle_lost`): 1 trận, 2 lần
  - để tướng trong tầm địch giết được (`hero_killable`): 1 trận, 1 lần
  - máu thấp không rút về ô hồi máu (`no_retreat`): 1 trận, 1 lần
- Bot:
  - bot bị khai thác (người đáp hay hơn mô hình đối thủ của bot) (`bot_exploited`): 2 trận, 8 lần — lặp lại
  - bot để quân lẻ trong tầm (`bot_lone_unit`): 2 trận, 7 lần — lặp lại
  - bot đi kém planner Khó v3 (`bot_blunder`): 2 trận, 3 lần — lặp lại
  - bot để quân lẻ, bị giết (`bot_lone_unit_punished`): 1 trận, 5 lần
  - bot để tướng giết được (`bot_hero_exposed`): 1 trận, 4 lần
  - bot bỏ trống thành trong tầm chiếm (`bot_castle_open`): 1 trận, 1 lần
  - bot để tướng hở, tướng chết (`bot_hero_exposed_punished`): 1 trận, 1 lần

## Các trận (mới nhất trước)

### 2026-11-07 23:00:39 · duel · dong_bang · e=army · thắng: e (người thua, 11 lượt)
- Bot yếu: t2 bot_exploited: human reply beat the bot's opponent model: e archer#11 died @(6,5), p took village @(6,7); t3 bot_blunder: played below hard v3 planner: wolf#9->(5,3) attack #1 hero; catapult#10->(7,4) attack #1 hero; archer#8->(5,4) attack #1…; t5 bot_exploited: human reply beat the bot's opponent model: p catapult#6 -> rank 2, e soldier#15 died @(7,4)
- Người chơi: t11 loss +1139 fed_promotion; t6 loss +822 gold_unspent; t8 loss +536 village_lost
<!-- data {"bot_notes":["t2 bot_exploited: human reply beat the bot's opponent model: e archer#11 died @(6,5), p took village @(6,7)","t3 bot_blunder: played below hard v3 planner: wolf#9->(5,3) attack #1 hero; catapult#10->(7,4) attack #1 hero; archer#8->(5,4) attack #1…","t5 bot_exploited: human reply beat the bot's opponent model: p catapult#6 -> rank 2, e soldier#15 died @(7,4)"],"bot_tags":{"bot_blunder":2,"bot_exploited":2,"bot_lone_unit":2},"bots":"e=army","date":"2026-11-07 23:00:39","human_notes":["t11 loss +1139 fed_promotion","t6 loss +822 gold_unspent","t8 loss +536 village_lost"],"human_tags":{"castle_lost":2,"fed_promotion":1,"gold_unspent":5,"hero_killable":1,"lone_unit_killed":2,"missed_sure_kill":1,"village_lost":1},"id":"2026-11-07_23-00-39_duel_dong_bang","kind":"duel","map":"dong_bang","result":"người thua","turns":11,"winner":"e"} -->

### 2026-11-07 22:19:09 · duel · dong_bang · e=army · thắng: p (người thắng, 24 lượt)
- Bot yếu: t5 bot_exploited: human reply beat the bot's opponent model: p bought soldier @(1,9), e hero#3 died @(2,6); t6 bot_exploited: human reply beat the bot's opponent model: p archer#11 -> rank 1, p bought soldier @(1,9), e soldier#8 died @(2,6), p to…; t7 bot_lone_unit: soldier#4 (1,8) 50hp
- Người chơi: t16 loss +2301 missed_sure_kill,gold_unspent; t15 loss +807 missed_sure_kill,village_lost,gold_unspent,fed_promotion; t14 loss +426 missed_sure_kill,fed_promotion
<!-- data {"bot_notes":["t5 bot_exploited: human reply beat the bot's opponent model: p bought soldier @(1,9), e hero#3 died @(2,6)","t6 bot_exploited: human reply beat the bot's opponent model: p archer#11 -> rank 1, p bought soldier @(1,9), e soldier#8 died @(2,6), p to…","t7 bot_lone_unit: soldier#4 (1,8) 50hp"],"bot_tags":{"bot_blunder":1,"bot_castle_open":1,"bot_exploited":6,"bot_hero_exposed":4,"bot_hero_exposed_punished":1,"bot_lone_unit":5,"bot_lone_unit_punished":5},"bots":"e=army","date":"2026-11-07 22:19:09","human_notes":["t16 loss +2301 missed_sure_kill,gold_unspent","t15 loss +807 missed_sure_kill,village_lost,gold_unspent,fed_promotion","t14 loss +426 missed_sure_kill,fed_promotion"],"human_tags":{"fed_promotion":5,"gold_unspent":11,"lone_unit_killed":3,"missed_sure_kill":8,"no_retreat":1,"village_lost":10},"id":"2026-11-07_22-19-09_duel_dong_bang","kind":"duel","map":"dong_bang","result":"người thắng","turns":24,"winner":"p"} -->
