# AI: tham số, tự đấu, độ khó

## Tham số (`scripts/core/ai.gd`)
- Mọi hằng số chấm điểm ở `AI.DEFAULT` (1 Dictionary): trọng số khoảng cách tới mục tiêu, thủ địa hình, thận trọng (lính / tướng), giá máu / giá chết, hồi máu, về nhà, thành, chiếm, đánh, nhiễu, mua lính.
- Ghi đè theo phe: `s.aiParams = { "e": { "noise": 40.0, ... } }` (dict thiếu khóa cũng được, gộp lên `DEFAULT`, nhớ trong `mem` theo lượt). Không có `aiParams` = `DEFAULT`, file lưu không đổi, golden không đổi.
- Lính máu thấp: hp < `home_hp` (50) -> mục tiêu = ô hồi máu của phe (làng / thành của ta, đền) còn trống -> đi về qua nhiều lượt; thưởng `heal_hp` (< 70) giữ nó trên ô tới ~70 máu rồi quay lại đánh. Ô hồi gần nhất xa hơn `home_turns` (4) lượt đi / không có -> mục tiêu thường, lính thường bỏ sợ chết (không ngồi ỳ). Mục tiêu màn "tới đích" vẫn ưu tiên.
- Thử: `sim/probes/sulk.gd -- scene` (1 lính máu 25 ở xa nhà, địch đứng yên: vị trí / máu mỗi lượt), `-- scan 4` (mọi màn + đấu tự do: lính < 50 máu ngoài ô hồi -> đánh / về nhà / ỳ), `sim/probes/ai_time.gd` (ms mỗi nước AI).

## Tự đấu (`sim/tune.gd`, `tools/tune.sh`)
- `match a=<spec> b=<spec> games=N salt=S`: A (phe p) vs B (phe e) rồi đổi chỗ, trên mọi bản đồ đấu tự do (`Content.SKIRMISH.MAPS`, 3 bản) -> điểm A (thắng 1, hòa 0.5), 6·N ván. Seed: ván k của salt -> `1000 + (salt·64 + k)·7919` (LCG như `sim_lib`). Cùng params -> đúng 0.500 (kiểm tra).
- `evolve out=<file> games=8 minutes=20 island=k thr=0.55`: đột biến ~3 khóa của best (×exp(N(0, 0.3)), `noise` + `cap_last` giữ nguyên), đấu con vs best; giữ con khi > thr trên 2 bộ seed (2·48 ván). Ghi `var_to_str({gen, best, history})` sau mỗi thế hệ -> chạy lại cùng file = tiếp tục.
- `tools/tune.sh [islands] [minutes] [games] [held_games]`: các đảo chạy song song (mỗi đảo 1 tiến trình, `run_guarded`), rồi mỗi best vs `DEFAULT` trên seed giữ riêng (salt 9000000, `held_games`·6 ván); đảo tốt nhất (nếu > 0.5) -> `sim/tuned_params.txt`. Không đổi AI mặc định của game.
- `presets games=N [names=easy,normal,hard_v1,hard_v2]`: vòng tròn các mức độ khó (bên dưới).
- Spec: `hard_v1` = Khó trước planner (cố định, thước đo), `hard_v2` = `AI.PRESETS.hard` (nay = Khó v3), `hard_v2_0` / `hard_v3` = Khó v2 / v3 lúc ship (cố định); ghi đè `<spec>+khóa:giá trị` (vd `hard_v2+pl_kill:2`). `time a= b= games=` = ms mỗi bước / lượt của A. `log=1` = 1 dòng mỗi ván (thắng, lý do, lượt, số lần tướng chết).

### Phiên tune 2026-11-06 (AI `5a75b2a` = `fe83a5d` + bảng tham số, Mac 10 nhân, chạy chung máy với việc khác)
- `tools/tune.sh 6 25 8 16`: 6 đảo × 25 phút, 12–13 thế hệ / đảo (48 ván / thế hệ, 96 khi xác nhận; 576–624 ván / đảo), 2 lần nhận.
- Tốc độ: ~1,0 ván/s một tiến trình khi máy rảnh; 0,4 ván/s mỗi đảo khi 6 đảo + việc khác (tổng ~2,4 ván/s); 4 tiến trình: ~0,65 ván/s mỗi cái.
- Ván có lợi thế ghế theo bản đồ (DEFAULT vs DEFAULT: dong_bang phe e thắng ~80%, nui_rung phe p ~75%) -> luôn đấu cả 2 ghế.
- Best (đảo 5): `hp_cap` 150 -> 81,3, `kill_hero` 600 -> 552 (lính rẻ cũng tính giá chết -> ít lao vào chỗ chết). Vs `DEFAULT`: 0,562 / 96 ván (seed chọn đảo), **0,573 / 384 ván seed mới** (salt 9000001–4; ~2,9 SE). Đảo 2 (`caution` 0,6 -> 0,94): 0,531 / 96. 4 đảo còn lại không nhận con nào (0,500).
- Ghi vào `sim/tuned_params.txt`; AI mặc định của game **không đổi**.

## Khó v2: lập kế hoạch cả lượt (`scripts/core/ai_plan.gd`, 2026-11-07)
`AI.PRESETS.hard` = knob v1 (`hp_cap`, `kill_hero`) + `"planner": 2` -> `AI.next_step` chuyển sang `AIPlan.next_step` (từ Khó v3 thêm knob kinh nghiệm người chơi, mục dưới). Không có `planner` (chiến dịch, đấu tự do, Thường, Dễ, gợi ý, golden) = `AI.greedy_step` = AI cũ y nguyên.

### Cách chạy
- Đầu lượt: tạo vài **lượt ứng viên** (portfolio), mỗi cái = tiền tố bắt buộc + AI tham lam v1 đi nốt lượt:
  1. `STYLES` (`pl_cands` = 3 bộ knob đầu): như cũ / không nhiễu / liều (`caution` 0, `atk_bias` 80).
  2. **Dồn đòn giết** (`kill_prefixes`, `pl_kill` = 3): với 3 địch giá trị nhất đánh tới được, chuỗi đòn giết hẳn nó (roll giữa): có đòn giết ngay -> quân rẻ nhất ra đòn kết (ưu tiên giết chắc ở roll thấp nhất); chưa giết được -> đòn có (sát thương × giá địch − phản đòn × giá ta) cao nhất (cung / máy bắn đá không bị phản đòn -> đánh trước). Thêm 1 ứng viên giết đôi (mục tiêu 1 rồi mục tiêu kế).
  3. **Giữ thành** (`guard_prefix`, `pl_guard` = 1): thành ta mà tướng địch bước tới được lượt sau -> quân đang đứng đó ở lại, thành trống -> quân rẻ nhất tới được vào đứng.
- Mỗi ứng viên chơi trên bản sao state (`Game.fixed_roll` 0,5), rồi **địch đáp 1 lượt** bằng AI tham lam v1 (Thường, không nhiễu), hết lượt (thu nhập, hồi máu) -> chấm điểm thế cờ (2 ply):
  - mỗi quân: giá (`AI.value`) × máu, nhưng phần phụ thuộc máu chặn ở `pl_hp_cap` 200 (máu hồi được; phần còn lại tính khi còn sống) -> tướng 900: 700 + 200 × máu.
  - + vàng, + thu nhập × 4 lượt, + 300 / thành, − 4 / ô quân tới công trình chưa của mình, − 12 / ô tướng tới thành chưa của mình; thắng / thua = ±1e6. Đối xứng (ta − địch).
- Ứng viên điểm cao nhất -> các bước của nó phát ra từng bước (UI vẫn diễn từng bước). Mỗi bước: tập id quân còn sống phải khớp dự đoán (roll thật giết / không giết khác roll giữa) + bước còn hợp lệ, không thì **lập lại** cho phần còn lại (`pl_replan` = 3 style + giết + giữ thành).
- Tất định: RNG riêng seed `hash([s.rng, s.turn, side, lần lập, id còn sống])`; không đụng `AI.rng` (trả lại đúng giá trị cũ, cả `Game.fixed_roll`); không sửa `s`. Giới hạn = số ứng viên (đếm được); `pl_ms` 4000 ms chỉ là phanh khẩn cấp (đo: không bao giờ chạm).
- Cache reach / threat / dist field (`mem.tm` / `rc` / `df`) dùng chung cho mọi bản sao trong lượt (khóa theo vị trí quân + địa hình -> an toàn).

### Nguồn tham khảo (đọc 2026-11-06)
- Battle for Wesnoth: đánh giá tổ hợp đòn (`src/ai/default/attack.cpp` `attack_analysis::rating`: `chance_to_kill × target_value − avg_losses × (1 − aggression)`, phạt phơi quân theo vulnerability / support, đòn đe dọa tướng ×5) + RCA AI (combat chạy trước chiếm làng / di chuyển) — https://github.com/wesnoth/wesnoth/blob/master/src/ai/default/attack.cpp , https://wiki.wesnoth.org/RCA_AI , https://wiki.wesnoth.org/LuaAPI/ai -> ý dồn đòn giết + đòn kết bằng quân rẻ.
- Portfolio Greedy Search (Churchill & Buro 2013, StarCraft combat): sinh nước bằng vài script thay vì vét mọi tổ hợp, chấm bằng playout — https://www.cs.mun.ca/~dchurchill/publications/pdf/combat13.pdf -> portfolio = style knob + tiền tố giết + giữ thành, AI v1 làm playout.
- Online Evolution (Justesen, Mahlmann, Togelius 2016; Justesen et al. 2018, Hero Academy, game nhiều hành động / lượt): tìm trên cả lượt, chấm bằng hàm đánh giá state, thắng MCTS vì nhánh quá rộng — https://core.ac.uk/download/84859342.pdf , https://njustesen.github.io/njustesen/publications/justesen2017playing.pdf -> lập kế hoạch cả lượt, không từng quân.
- Advance Wars / tactics: dồn hỏa lực tăng sức mạnh bậc 2, lính máu thấp đánh yếu (AE2 cũng vậy: sát thương × máu / 100) -> giết hẳn 1 quân > rải đòn. Đánh trước thắng thế.
- Hướng dẫn chiến thuật riêng cho Ancient Empires II: tìm không ra nguồn dùng được (kết quả toàn Age of Empires) -> dựa luật gốc đã xác minh bằng bytecode (`docs/review/ae2_research.md`).

### Đo trong lúc làm (seed dev salt 100–305, 144 ván / thử, điểm v2 vs Khó v1)
| Thử | Điểm |
|---|---|
| chỉ 6 style | 0,680 |
| + dồn đòn giết (6 style) | 0,816 |
| 3 style (nhanh hơn) / 5 mục tiêu giết / 3 ply / thu nhập ×8 + thành 600 | 0,826 / 0,795 / 0,812 / 0,833 (= nhiễu) |
| địch đáp thêm bằng dồn đòn giết / roll đáp 0,7 / thưởng tướng sống 800 | 0,785 / 0,802 / 0,812 (không lợi) |
| + "tướng về ô an toàn" + giữ thành (bản lỗi) | 0,663 / 0,694 (**tệ**: ứng viên thụ động mà hàm điểm lại thích) |
| **máu tướng rẻ (`pl_hp_cap` 200)** | **0,875** (cùng seed: 0,812 -> 0,875); 100: 0,854 |
| + phạt nguy cơ chết của tướng (threat map) | 0,826 (lại thụ động) |
| + giữ thành (đã sửa: thành có quân ta tính theo khoảng cách) | 0,882; seed khác 0,920 |

- Bài học: nút thắt là **hàm điểm**, không phải độ rộng tìm kiếm. Tính đủ giá 900 cho máu tướng -> mọi ứng viên "tướng nấp" thắng điểm -> chơi thụ động -> thua. Giống v1 (`hp_cap`): máu rẻ, giá trị lớn chỉ khi chết.
- Mọi trận thua đều có tướng ta chết (log `log=1`), tướng địch gần như không chết.
- `evolve` (`tune.gd`) không đột biến knob `pl_*` (chúng nằm ở `AIPlan.DEFAULT`, không ở `AI.DEFAULT`).

### Kết quả (seed giữ riêng salt 9000100–9000105, 66 ván / map / ghế -> 396 ván / cặp, cả 2 ghế, 3 map)
- **Khó v2 vs Khó v1: 0,896** (±0,015 SE; 355 thắng / 41 thua). Theo map (v2 ghế p / e): đồng bằng 65/66 – 65/66, cửa biển 49/66 – 55/66, núi rừng 59/66 – 62/66.
- Ma trận (điểm hàng vs cột, thắng 1 hòa 0,5, 396 ván / ô, cùng bộ seed; chạy song song `match` 6 tiến trình × `games=11`, salt 9000100–105):

| | Dễ | Thường | Khó v1 | Khó v2 |
|---|---|---|---|---|
| Dễ | – | 0,255 | 0,232 | 0,081 |
| Thường | 0,745 | – | 0,477 | 0,107 |
| Khó v1 | 0,768 | 0,523 | – | 0,104 |
| **Khó v2** | **0,919** | **0,893** | **0,896** | – |

- Thời gian (`tune.gd -- time a=hard_v2 b=hard_v1 games=4 salt=9100000`, 24 ván, Mac 10 nhân, máy đang tải ~5,7): mỗi bước TB 22 ms, p95 170 ms, tệ nhất 877 ms; **mỗi lượt TB 202 ms, p95 529 ms, tệ nhất 1,19 s**. Khó v1 cùng seed: bước 2,5 ms, lượt TB 16 ms / tệ nhất 46 ms. `AIPlan.last.capped` không bật lần nào (phanh 4 s). Điện thoại chậm ~3–5× -> lượt TB ~0,6–1 s, tệ nhất có thể 3–6 s: cần đo máy thật; giảm `pl_kill` / `pl_replan` nếu chậm (đổi lực, phải đo lại).
- Sim chậm hơn: ~0,25 ván/s mỗi tiến trình khi có v2 (v1–v1 ~0,7).

### Ví dụ (`sim/probes/plan_probe.gd -- games=1`, seed salt 9200000)
- Đồng bằng lượt 15 (v2 = p): tướng địch 45 máu ở (12,1). v1: tướng ta chiếm làng, 3 lính đánh tướng địch -> roll giữa còn sống. v2: tướng ta đánh trước rồi 2 lính kết -> **giết tướng địch** (dư 1 lính đi đánh lính khác).
- Cửa biển lượt 16 (v2 = e): tướng ta 64 máu. v1: cung #18 đi chỗ khác, 5 quân đánh -> tướng sống (roll giữa). v2: **6 đòn dồn**, cung / thuyền (không bị phản đòn hoặc phản yếu) trước -> tướng chết.
- Cửa biển lượt 6 (v2 = p): tướng địch đứng sát thành ta (8,7). v1 cho lính trên thành đi chỗ khác -> thành trống. v2 đưa cung vào đứng thành (điểm 2 ply thấy tướng địch chiếm thành ở lượt đáp).
- Thống kê 1 lượt chạy (80 lượt v2): lần lập đầu lượt chọn style 58 lần, dồn đòn giết 28 lần; lập lại giữa lượt 10 lần (roll thật khác dự đoán).

### Luyện thêm (2026-11-07, phiên 2): có khôn hơn không?
Thước đo cố định: spec `hard_v2_0` (`sim/tune.gd`) = `AI.PRESETS.hard` + `AIPlan.DEFAULT` lúc ship v2 (`20fae2e`), đổi default sau này không làm trôi mốc. Mọi số dưới: điểm ứng viên vs `hard_v2_0`, cả 2 ghế, 3 map.

Công cụ mới:
- `tools/match_par.sh <a> <b> [games] [salt0] [nproc]`: 8 tiến trình, salt `salt0..salt0+7`, cộng điểm, ± SE (nhị thức). Cảnh báo nếu `pl_ms` cắt plan (mất tất định).
- `tune.gd -- evaldata` + `tools/texel_fit.py`: kiểu Texel (cờ vua) — mỗi đầu lượt (đúng thế cờ planner chấm) ghi đặc trưng (giá quân, máu mất, vàng, thu nhập, thành, khoảng cách, tướng sống, độ phơi tướng 2 bên) + kết quả ván -> hồi quy logistic -> trọng số "đúng" theo dữ liệu.
- `pl_buy` (mặc định 0): ứng viên mua trước (lính mua đi ngay lượt đó, AE2), + mua rồi dồn đòn giết. `AI.buy_step` tách từ `greedy_step` (y nguyên).
- `plan_probe.gd over=k:v+k:v`: đếm ứng viên thắng với knob khác.

Seed dev: bộ A salt 100–107, bộ B 200–207 (`games=3` -> 144 ván / lần, SE ~0,042). Tốc độ thật: v2 vs v2 ~0,3 ván/s cả 8 tiến trình (144 ván ~8–10 phút), chậm hơn ước tính 3×.

| Thử (vs `hard_v2_0`) | Bộ A | Bộ B |
|---|---|---|
| `pl_buy` 2 (mua trước + mua rồi giết) | 0,514 | |
| `pl_hp_cap` 300 / 140 | **0,434** / 0,493 | |
| `pl_castle` 550 | 0,493 | |
| `pl_inc` 8 / 2 | **0,406** / 0,500 | |
| `pl_adv_hero` 24 | 0,486 | |
| `pl_adv` 8 / 2 / 0 | **0,354** / 0,531 / 0,542 | – / – / 0,538 |
| `pl_opp_roll` 0,65 (địch đáp gặp may) | 0,528 | |
| `pl_alpha` 0,5 | 0,514 | |
| `pl_gold` 0,6 | 0,521 | |
| **`pl_opp_kill` 1** (địch đáp thêm bằng dồn đòn giết quân giá trị nhất = tướng ta) | **0,556** | **0,569** |
| `pl_opp_kill` 1 + `pl_adv` 2 / + `pl_adv` 0 | 0,535 | 0,580 / 0,521 |
| (vs Khó v1, salt 300–307) `pl_opp_kill` 1 + `pl_adv` 2 / `hard_v2_0` | 0,854 / 0,872 | |

- Mua trước: được chọn 17 / 97 lần lập đầu lượt (`plan_probe over=pl_buy:2`, salt 300) nhưng không thắng hơn -> hàm điểm coi vàng = giá quân (mua là trung tính), lợi 1 lượt đi sớm nhỏ.
- Hàm điểm hiện tại gần đỉnh cục bộ: đổi trọng số 2× theo hướng nào cũng hòa hoặc thua; `pl_adv` cao (đẩy quân lên) thua đậm, thấp hơn hơi tốt (0,54, chưa chắc).
- Texel (192 ván v2 tự đấu, 7384 thế cờ, salt 500–507): hàm điểm hiện tại đã dự đoán gần bằng hồi quy tự do (log-loss kiểm tra 0,250 vs 0,245–0,251); thêm độ phơi tướng không dự đoán tốt hơn (0,2500). Hệ số học được **không ổn định** giữa 2 nửa dữ liệu (thành: +217 / −98; tướng sống: +44 / −258; máu mất ×0,2 / ×2,8) -> 192 ván quá ít, và trọng số dự đoán tốt ≠ chọn nước tốt (Texel gợi ý thu nhập cao hơn; đo: `pl_inc` 8 thua 0,406).
- `pl_opp_kill` 1: ý tưởng — địch v2 dồn đòn giết có kế hoạch, mô hình địch hiện tại (v1 tham lam từng đòn) đánh giá thấp nguy cơ tướng ta; thêm lời đáp "địch dồn đòn giết quân giá trị nhất của ta" (+ giết đôi), lấy lời đáp tệ nhất = cẩn thận đúng chỗ thay vì phạt nguy cơ cố định. Chi phí: tối đa 3 lời đáp / ứng viên (~+18% thời gian / lượt, đo lúc máy tải nặng).

**Kết quả seed giữ riêng** (salt 9300000–9300007 mới, `games=8` × 8 tiến trình = 384 ván / cặp, cả 2 ghế, 3 map; ± SE):

| A vs B | Điểm A |
|---|---|
| `hard_v2_0` + `pl_opp_kill` 1 vs `hard_v2_0` | **0,517 ± 0,026** (cần ≥ 0,55) |
| `hard_v2_0` + `pl_opp_kill` 1 vs Khó v1 | 0,895 ± 0,016 |
| `hard_v2_0` vs Khó v1 | 0,919 ± 0,014 |
| `hard_v2_0` + `pl_opp_kill` 1 vs Thường | 0,849 ± 0,018 |
| `hard_v2_0` vs Thường | 0,878 ± 0,017 |

- **Kết luận: luyện thêm không làm máy khôn hơn rõ** — ứng viên tốt nhất dev (0,563 / 288 ván, bộ A+B) chỉ còn 0,517 trên seed mới (= nhiễu + chọn lọc), lại yếu hơn chút vs Khó v1 / Thường (−0,024 / −0,029, ~1 SE): mô hình địch bi quan hợp với địch mạnh, thừa thận trọng với địch yếu. **Không đổi `AI.PRESETS.hard` / `AIPlan.DEFAULT`** (chỉ thêm công cụ + knob tắt).
- `pl_ms` (phanh 4 s) bị chạm vài lần khi 8 sim song song + game người dùng (tải ~10–12), chỉ ở ứng viên có `pl_opp_kill` (lời đáp đắt): held-out 5 lần / 384 ván; dev: 1–8 tiến trình mỗi lần chạy có `pl_opp_kill`. Các ván đó không tất định tuyệt đối (không đổi kết luận). `hard_v2_0` và các knob trọng số: không chạm lần nào.
- Thời gian (hành vi không đổi): đo lại `tune.gd -- time a=hard_v2_0 b=hard_v1 games=4 salt=9100000` (24 ván, chạy song song 3 gate, tải ~3–7): lượt TB 255 ms, p95 658 ms, tệ nhất 1,58 s; bước TB 28 ms, tệ nhất 1,18 s (cũ: 202 ms / 1,19 s ở tải ~5,7) -> tệ nhất nhạy với tải máy, cần đo trên điện thoại thật. `pl_opp_kill` 1 lúc tải ~10: +18% thời gian / lượt so với `hard_v2_0` cùng lúc.
- Vì sao không lên: hàm điểm 7 trọng số tay đã ở gần đỉnh cục bộ (mọi bước 2× đều ≤ hòa); lợi thế ghế theo map rất mạnh (v2 vs v2 seed giữ riêng: núi rừng ghế e thắng ~75%, cửa biển ghế e ~64%, đồng bằng ghế p ~63%) -> 144 ván chỉ phân biệt được chênh ≥ ~0,08; ứng viên cấu trúc (mua trước, địch đáp dồn đòn) tăng ≤ ~0,02 thật.
- Muốn "siêu khó" tiếp, thử theo thứ tự: (1) đổi nguồn mạnh chứ không chỉnh trọng số — tìm kiếm sâu hơn ở chỗ quyết định (2 lượt của ta khi có thể giết tướng / mất thành), (2) đánh giá học từ nhiều dữ liệu hơn (≥ 2000 ván, đặc trưng theo loại quân / vị trí tướng so với thành), dùng làm thứ tự ứng viên chứ không thay hàm điểm, (3) thưởng / chấp vàng cho "Siêu khó" (rẻ, chắc chắn mạnh hơn), (4) mỗi đánh giá ≥ 400 ván (paired, cả 2 ghế) — dưới mức đó chênh 0,05 không thấy.

### Kinh nghiệm người chơi = Khó v3 (2026-11-07, phiên 3)
Mẹo của user (người chơi AE2 lâu năm) + vài mẹo thêm (8–10), mỗi mẹo = 1 knob trong `AI.DEFAULT` (mặc định 0 = tắt -> Dễ / Thường / chiến dịch / golden y nguyên). Đều là **điểm của AI tham lam v1** (chọn nước từng quân) -> mọi lượt ứng viên của planner (style, dồn đòn, giữ thành) thừa hưởng; mô hình địch (`OPP`) không có. Không đụng hàm điểm 2 ply.

| Mẹo | Knob (v3) | Cách làm |
|---|---|---|
| 3 + 8: không sang lẻ, tập kết rồi ập vào | `lone_w` 0,3, `lone_n` 1 | ô cuối trong tầm địch + < `lone_n` quân ta trong bán kính 2 -> − `lone_w` × giá quân × khả năng bị dồn chết (tổng đòn mọi địch với tới / máu: 0,6 -> 0, ≥ 1 -> 1). Cả nước đánh không giết (máu còn lại sau phản đòn). Bỏ qua tướng. Bản đồ "quân ta quanh ô" dựng 1 lần / bước (`AI.support_map`) |
| 5 + 9: giết quân hỗ trợ phiền, giết theo độ nguy hiểm | `tgt_sup` 0,5, `tgt_thr` 2 | `AI.tvalue`: giá mục tiêu × 1,5 cho thầy mo / sói / trống, + 2 × đòn của nó (atk giữa + cấp + trống) × máu / 100. Dùng ở điểm đánh v1 + thứ tự / chấm đòn của dồn đòn giết (`kill_prefixes`, `focus`) |
| 6: đổi 1:1 chỉ khi lời | `trade_w` 1 | đòn không giết: − (phản đòn × giá ta − sát thương × giá địch) / 100 nếu lỗ |
| 4: cung bắn trước, cận chiến sau (cả đòn không giết) | `order_w` 1 | đòn cận chiến không giết bị phản, mà còn quân tầm xa chưa đi đánh tới được mục tiêu -> − phản đòn × giá / 100 (để cung bắn trước, địch yếu đi, phản đòn nhỏ lại) |
| 10: không nuôi địch lên cấp | `feed_w` 1 | AE2 không có thưởng giết: XP = sát thương × chất lượng nạn nhân mỗi đòn, cả phản đòn -> đòn không giết mà phản đòn đủ cho địch lên cấp: − 0,2 × giá địch |
| 1: tướng đi chiếm thành, có hộ tống | `escort_w` 30, `hero_cgoal` 1 (v3: **tắt**, thua Khó v1) | tướng chỉ nhắm thành chưa của mình (làng để lính); quân thường đứng trong bán kính 2 quanh tướng (tướng có < 3 quân cạnh) +30 |
| 2 + 7: quân cấp cao / đắt sợ chết, về hồi máu sớm, đứng công trình | `home_val`, `home_rank`, `home_cap` 80, `bld_w` (v3: **tắt**) | ngưỡng về nhà = 50 + `home_val` × (giá − 150) / 100 + `home_rank` × cấp (≤ 80, trừ tướng); quân bị thương đứng ô hồi máu ta + `bld_w` × (giá trị − 150) / 100 |

Đo hành vi: `sim/probes/tactics_probe.gd` (+ `tools/tactics_par.sh`, 8 tiến trình): A vs B mọi map, 2 ghế; đếm ở cuối mỗi lượt A / sau lượt đáp. "Lẻ bị dồn chết được" = quân thường (không tướng) trong tầm địch, tổng đòn (roll giữa) mọi địch với tới ≥ máu, không quân ta trong bán kính 2. `examples=N` in lượt mà `hard_v2_0` (cùng thế cờ đầu lượt) để quân lẻ còn A thì không.

Hành vi vs `hard_v2_0` (A vs `hard_v2_0`, 96 ván, salt 600–607, cùng ván đầu):

| Chỉ số | v2_0 | `lone_w` | `tgt_*` | `trade/order/feed` | `escort/hero_cgoal` | `home_val` 10 + `bld_w` 20 (bản 1) | v3 bản 1 (tất cả, dev) |
|---|---|---|---|---|---|---|---|
| điểm (96 ván) | 0,500 | 0,625 | 0,562 | 0,552 | 0,573 | 0,542 | 0,802 |
| quân lẻ bị dồn chết được / 100 lượt-quân | 8,43 | **4,45** | 6,41 | 6,74 | 6,76 | 7,28 | **3,91** |
| quân bị dồn chết được (kể cả có bạn) / 100 | 18,55 | 14,62 | 14,55 | 15,56 | 16,35 | | 10,88 |
| quân ta chết / ván | 10,78 | 8,75 | 9,68 | 9,77 | 9,58 | 10,92 | **7,08** |
| quân quý chết / ván (cấp ≥ 1 hoặc giá ≥ 400) | 4,10 | 3,31 | 3,62 | 3,67 | 4,06 | 4,21 | 3,18 |
| tướng ta chết / ván | 0,60 | 0,36 | 0,48 | 0,58 | 0,61 | 0,44 | 0,45 |
| giết tướng địch / ván | 0,70 | 0,74 | 0,71 | 0,74 | 0,83 | 0,66 | 0,94 |
| chiếm thành / ván | 1,83 | 2,05 | 1,88 | 2,00 | 1,86 | 1,97 | 2,33 |
| quân ta cách tướng ≤ 2 (TB) | 0,99 | 1,10 | 1,12 | 1,08 | **1,45** | 1,08 | **1,61** |
| tướng đứng một mình % | 45,4 | 42,0 | 44,0 | 44,6 | **29,5** | 45,0 | **27,4** |
| đòn không giết, lỗ giá trị % | 3,16 | 2,89 | 3,49 | **2,08** | 4,39 | 3,46 | 2,69 |
| đòn không giết từ ô thủ thấp hơn địch % | 31,3 | 28,1 | 27,2 | **24,9** | 27,9 | 30,9 | 23,0 |
| cung bắn sau cận chiến cùng mục tiêu / 100 đòn | 4,38 | 4,02 | 5,15 | **2,21** | 4,13 | 4,25 | 2,18 |
| địch lên cấp nhờ đòn ta / ván | 3,82 | 3,04 | 3,42 | **1,68** | 3,28 | 3,79 | 1,32 |
| quân quý < 50 máu cuối lượt / ván ; % trên ô hồi | 4,99 ; 58 | 4,84 ; 51 | 4,92 ; 53 | 4,78 ; 61 | 6,29 ; 58 | 5,23 ; 57 | 4,93 ; 54 |

- Quân hỗ trợ (thầy mo / sói / trống): AI gần như không mua (`aiWeight` 0,5–1,2) -> 0 lần gặp trong 96 ván, chỉ số không đo được bằng tự đấu; kiểm bằng test (`sim/tests/planner.gd` "tgt_sup / tgt_thr"). Với người chơi hay mua sói / trống thì có tác dụng.
- `home_val` 10 + `home_rank` 8 + `bld_w` 40 (bản 2, chỉ thưởng ô hồi khi bị thương): quân quý < 50 máu 4,99 -> 4,06 / ván (về sớm hơn), quân quý chết 4,10 -> 3,93 (= nhiễu), điểm 0,500 (192 ván) -> hành vi đổi ít, không mạnh hơn. Ghép vào bộ v3: 0,747 vs 0,775 không có nó (cùng 384 ván) -> **để tắt**. Lý do đoán: hàm điểm 2 ply tính máu rẻ (`pl_hp_cap`), lính hồi 20 / lượt; ngưỡng về nhà 50 vốn đủ.

Đo sức (dev, vs `hard_v2_0`, 192 ván / thử, salt 600–607; ± SE):

| Thử | Điểm |
|---|---|
| `lone_w` 0,3 | **0,630 ± 0,035** |
| `tgt_sup` 0,5 + `tgt_thr` 2 | 0,521 ± 0,036 |
| `trade_w` 1 + `order_w` 1 + `feed_w` 1 | 0,562 ± 0,036 |
| `escort_w` 30 + `hero_cgoal` 1 | 0,557 ± 0,036 |
| `home_val` 10 + `bld_w` 20 / bản 2 (`home_rank` 8, `bld_w` 40) | 0,510 / 0,500 |
| tất cả (bản 1 `home_*`: `home_val` theo giá trị kể cả cấp, `bld_w` cả khi đầy máu), 384 ván salt 700–707 | **0,775 ± 0,021** (đồng bằng 126/128) |
| tất cả (bản 2 `home_*`), 384 ván salt 700–707 | 0,747 ± 0,022 |

**Seed giữ riêng lần 1** (v3 bản 1 = mọi knob trừ `home_*` / `bld_w`; salt 9400000–007 vs `hard_v2_0` 768 ván, 9400008–015 vs Khó v1 432 ván, 9400016–023 vs Thường 432 ván; cùng seed cho `hard_v2_0` -> so cặp):

| A | vs `hard_v2_0` | vs Khó v1 | vs Thường |
|---|---|---|---|
| v3 bản 1 | **0,743 ± 0,016** | 0,843 ± 0,018 | 0,909 ± 0,014 |
| `hard_v2_0` | 0,500 | 0,910 ± 0,014 | 0,880 ± 0,016 |

- Thắng v2 đậm (đồng bằng 246,5/256; cửa biển ghế e 108/128; núi rừng ghế p 64/128 = hòa), hơn v2 vs Thường (+0,029), nhưng **thua v2 vs Khó v1 (−0,067, ~2,9 SE)**: trượt điều kiện ship. Mất ở núi rừng (v3 109/144 vs v2 138/144).
- Tách lỗi (dev salt 800–807, 192 ván / thử, vs Khó v1; `hard_v2_0` = 0,885, v3 bản 1 = 0,857): bỏ `lone_w` 0,844, bỏ `tgt_*` 0,885, bỏ `trade/order/feed` 0,828, **bỏ `escort_w` + `hero_cgoal` 0,958**, chỉ bỏ `hero_cgoal` 0,885, chỉ bỏ `escort_w` 0,932 -> thủ phạm = mẹo 1 (tướng chỉ nhắm thành + kéo quân hộ tống), các knob khác giúp cả vs Khó v1.
- Lỗi tìm ra sau đó: `hero_cgoal` quét `s.owner`, mà thành trung lập không có trong `s.owner` -> tướng bỏ qua thành trung lập, chỉ nhắm thành địch (lao sâu). Đã sửa (quét bản đồ), bản sửa **chưa đo**, để tắt.

**Seed giữ riêng lần 2** (salt 9410000+, chưa dùng; ghi trước khi xem kết quả): B = v3 bản 1 − `hero_cgoal` (giữ hộ tống), A = B − `escort_w`. Luật chọn: ship B nếu (B vs `hard_v2_0`) ≥ 0,50 và (B vs Khó v1) − (`hard_v2_0` vs Khó v1) ≥ −0,03 và (B vs Thường) − (`hard_v2_0` vs Thường) ≥ −0,03 (cùng seed; SE hiệu ~0,023); không thì A cùng luật; không cái nào qua -> không ship.

Kết quả lần 2 (cùng seed cho mọi hàng; 768 ván vs `hard_v2_0` salt 9410000–007, 432 ván vs Khó v1 salt 9410008–015, 432 ván vs Thường salt 9410016–023):

| A | vs `hard_v2_0` | vs Khó v1 | vs Thường |
|---|---|---|---|
| B (giữ hộ tống) | (dừng) | 0,860 ± 0,017 (−0,032: **trượt**) | (dừng) |
| **A = Khó v3** | **0,744 ± 0,016** | **0,949 ± 0,011** (+0,057) | **0,925 ± 0,013** (+0,038) |
| `hard_v2_0` | 0,500 | 0,892 ± 0,015 | 0,887 ± 0,015 |

- B trượt luật Khó v1 sát nút (−0,032) -> dừng chuỗi B, đo A. **A qua cả 3 -> ship**: `AI.PRESETS.hard` = v2 + `lone_w` 0,3, `tgt_sup` 0,5, `tgt_thr` 2, `trade_w` 1, `order_w` 1, `feed_w` 1. Spec cố định `hard_v3` (`sim/tune.gd`, `V3_TACTICS`) = đúng bộ đó (kiểm: `hard_v3`, `hard_v3+hero_cgoal:0+escort_w:0`, `hard_v2` ra cùng 6 ván, salt 9410003).
- v3 vs v2 theo map: đồng bằng 224/256, núi rừng ghế e 126/128 (ghế p 62,5/128 = hòa), cửa biển 159/256. Không lần nào chạm `pl_ms`.
- Mạnh nhất + khôn nhất hiện tại = Khó v3: hơn v2 cả vs bot planner (0,744), vs Khó v1 (+0,057) lẫn Thường (+0,038).

Hành vi Khó v3 (bản ship) vs `hard_v2_0`, seed giữ riêng salt 9400100–107 (96 ván, A vs `hard_v2_0`, cùng ván đầu):

| Chỉ số | v2_0 | **v3** |
|---|---|---|
| quân lẻ bị dồn chết được / 100 lượt-quân | 6,69 | **4,04** (−40%) |
| quân bị dồn chết được (kể cả có bạn) / 100 | 16,36 | 13,28 |
| quân ta chết / ván | 10,81 | **7,12** (−34%) |
| quân quý chết / ván | 3,92 | 3,14 |
| tướng ta chết / ván ; giết tướng địch / ván | 0,53 ; 0,64 | 0,35 ; 0,81 |
| chiếm thành / ván | 1,85 | 2,10 |
| đòn không giết từ ô thủ thấp hơn địch % | 30,7 | 24,3 |
| đòn không giết, lỗ giá trị % | 3,45 | 3,18 |
| cung bắn sau cận chiến cùng mục tiêu / 100 đòn | 3,57 | 2,61 |
| địch lên cấp nhờ đòn ta / ván | 4,15 | **1,47** (−65%) |
| tướng đứng một mình % (mẹo 1 tắt) | 46,8 | 40,7 |

- Thời gian (`tune.gd -- time a=<spec> b=hard_v1 games=4 salt=9100000`, 24 ván, v3 và v2_0 chạy song song cùng tải ~3–7): **v3 lượt TB 176 ms, p95 362 ms, tệ nhất 562 ms**; bước TB 18 ms, tệ nhất 498 ms. v2_0 cùng lúc: lượt 208 / 575 / 1291 ms. v3 không chậm hơn (ván ngắn hơn, ít quân chết -> ít lập lại). `tvalue` cache theo mục tiêu trong 1 lần `best_for_unit`.
- Mẹo chưa làm: 11 giữ điểm hẹp (đầu cầu) bằng quân thủ cao, 12 đua làng sớm (v1 đã chia làng gần nhất qua `claims`).
- Tiếp (v4): user chơi thử Khó v3 trước; thử lại mẹo 1 từng knob (`escort_w` riêng ít hơn, `hero_cgoal` đã sửa), `lone_w` 0,6 / `lone_n` 2; threat map tính cả quân địch mua ngay lượt sau (đánh luôn được, trừ máy bắn đá).

Ví dụ (`tactics_probe.gd -- games=1 salt=9200000 base=v3 opp=v2_0 examples=4`, bản ship; cùng thế cờ đầu lượt, v2_0 vs v3):
- Đồng bằng lượt 2 (ghế e): v2_0 cho cung #6 lên tận cầu (6,5) bắn tướng địch rồi đứng một mình (bị dồn chết được); v3 bắn cung địch từ (8,4) bên bờ mình, lính #4 đứng sát cạnh (8,3) (mẹo 3).
- Đồng bằng lượt 6 (ghế e): v2_0 cho lính #9 còn 18 máu chạy sang (3,8) đánh lẻ 1 cung; v3: tướng + lính + cung dồn đánh tướng địch, lính #9 rút về (6,5) cạnh lính #13 (7,5) (mẹo 3 + 7).
- Núi rừng lượt 4 (ghế p): v2_0 cho lính #6 còn 8 máu một mình đánh tướng địch từ (13,7); v3: 2 lính khỏe #9, #2 cùng đánh tướng, lính #6 yếu đánh lính địch từ (12,10) gần đồng đội (mẹo 3 + 6).

Bài học: phiên 2 kết luận "nút thắt là hàm điểm" — sai một nửa: mọi ứng viên của planner đều do v1 tham lam sinh ra, nên lỗi chung của v1 (đưa quân lẻ vào tầm địch từng con một) có trong mọi ứng viên, hàm điểm không có gì tốt hơn để chọn. Sửa chỗ **sinh ứng viên** (`lone_w`) cho +0,13 một mình. Thận trọng theo từng quân + tình huống (quân lẻ có thể bị dồn chết) ≠ thận trọng cả đội (tướng nấp, phạt nguy cơ cố định — đều thua).

### Mẹo người chơi trên mạng = Khó v4 (2026-11-07, phiên 4)
Mẹo của người chơi giỏi trên mạng (Advance Wars, Wesnoth, Wargroove, Fire Emblem) + mẹo suy từ luật AE2 đã xác minh (`docs/review/ae2_research.md`; hướng dẫn chiến thuật riêng cho AE2: không có nguồn dùng được). Mỗi mẹo = 1 knob, mặc định 0 = tắt -> Dễ / Thường / chiến dịch / đấu tự do / golden y nguyên. Làm như bài học v3: sửa **sinh ứng viên** (điểm AI tham lam v1 mà mọi ứng viên planner thừa hưởng) hoặc thêm tiền tố ứng viên có điều kiện cho 2 ply chấm, không phạt cố định trong hàm điểm. Mốc = spec cố định `hard_v3`.

Nguồn (đọc 2026-11-07):
- Advance Wars: Taz's strategy guide https://isndev.forumotion.co.uk/t671-taz-s-strategy-guide , LP https://lparchive.org/Advance-Wars/Update%2005 — lính mới mua ra đánh ngay, dồn hỏa lực, giữ / cướp nhà máy.
- Wesnoth: https://wiki.wesnoth.org/BasicStrategy — XP, rút lui, xoay vòng, không phơi quân lẻ; code AI rút lui https://raw.githubusercontent.com/wesnoth/wesnoth/master/data/ai/lua/retreat.lua + `ca_retreat_injured.lua` — ngưỡng rút theo địa hình / máu.
- Wargroove: https://news.xbox.com/en-us/2019/02/08/wargroove-tips-and-tricks/ — tướng mạnh nhưng chết = thua, thứ tự đòn (buff trước).
- Fire Emblem zoning AI: https://feuniverse.us/t/zoning-ai/8431 — vùng đe dọa, đứng ngoài tầm rồi ập vào.

| Mẹo | Knob | Cách làm |
|---|---|---|
| T1 tầm quân địch mua (AW: lính mua ra đánh ngay; AE2 cũng vậy) | `buy_threat` (`AI.DEFAULT`) | `AI.buy_threats`: mỗi thành địch còn chỗ (≤ 1 quân đứng trên) = 1 quân ảo: quân đánh mạnh nhất địch mua được bằng vàng + thu nhập lượt sau (chia ngân sách theo thứ tự thành; bỏ máy bắn đá: không đi + bắn cùng lượt; tướng nếu đã chết + đủ tiền chuộc), máu = `buy_threat` × 100, id < 0, không vào `s.units`. Cộng vào `AI.threat_map` -> rủi ro / `lone_w` của v1. Lời đáp 2 ply đã có sẵn (v1 mua rồi cho quân mới đi ngay) |
| T2 XP: quân ta lên cấp | `promo_w` (`AI.DEFAULT`, cả `focus`) | đòn làm quân ta lên cấp (XP = sát thương × chất lượng nạn nhân, +1 cấp = +2 công / +2 thủ) + `promo_w` × 0,2 × giá gốc. Phần "không nuôi địch" đã có ở v3 (`feed_w`) |
| T5 thứ tự chuỗi đòn: trống / sói trước | `pl_chain` (`AIPlan`) | trong `focus` (dồn đòn giết): đòn không giết của quân có `aura` (trống, +10 công cho quân cạnh) / `poison` (sói, −10 thủ mục tiêu) + `pl_chain` × buff × số quân ta còn đánh tới mục tiêu (trống: trong bán kính 2) × giá mục tiêu / 100 |
| T6–T8 tìm sâu ở lượt quyết định (cướp thành / giết tướng khi địch hết tiền chuộc) | `pl_dp` (`AIPlan`) | `AIPlan.decision_point`: (a) tướng ta tới được thành địch trống ở lượt sau (khoảng cách > mv, ≤ 2·mv) -> thêm ứng viên "snipe" (tướng tới ô gần thành nhất trước); (b) tổng đòn 2 lượt của quân ta lên tướng địch ≥ máu nó và địch không đủ vàng + thu nhập chuộc tướng. Có (a) hoặc (b) -> mọi ứng viên của lần lập đó chơi thêm lượt sau của ta (= `pl_ply3` có điều kiện) |
| T9 ngưỡng rút theo giáp + địa hình (Wesnoth retreat) | `ret_terr` (`AI.DEFAULT`) | quân thường: ngưỡng về nhà `home_hp` × lerp(1, clamp((40 − thủ − 2·cấp − thủ ô) / 20, 0,5; 1,5), `ret_terr`) -> lính giáp mỏng trên đất trống về sớm (75), voi / trong rừng về muộn |
| T12 mua quân hỗ trợ (để dành) | `buy_sup` (`AI.DEFAULT`) | xem dưới (làm sau held-out) |
| T3, T4, T10, T11, T13, T14 | — | không làm: ma / thầy mo / trống / sói gần như không được mua trong tự đấu (v3: 0 lần gặp / 96 ván) -> T3 (lá chắn ma), T4 (giẫm mộ) không đo được; T10 xoay vòng, T11 tập kết trùng `lone_w` (v3); mua trước = `pl_buy` (phiên 2: 0,514); T13 phá làng đã có (`raze`) |

Đo (dev, A vs `hard_v3`, salt 1000–1007, 192 ván / thử, ± 0,036 SE; hành vi: `tactics_probe.gd` + `tools/tactics_par.sh`, mốc = `hard_v3` vs chính nó, 96 ván (k = 0, 1) cùng salt):

| Chỉ số (A vs `hard_v3`) | v3 (mốc) | `buy_threat` 0,5 | `buy_threat` 1 | `pl_dp` 1 | `promo_w` 1 | `ret_terr` 1 |
|---|---|---|---|---|---|---|
| điểm | 0,500 | 0,526 | 0,518 | 0,495 | 0,477 | 0,516 |
| quân ở trong tầm quân địch mua / 100 lượt-quân | 8,46 | 8,57 | **7,71** | 9,50 | 8,65 | 9,42 |
| đòn của quân địch vừa mua / ván ; sát thương | 2,83 ; 86,8 | 2,88 ; 89,9 | **2,70 ; 82,8** | 2,93 ; 88,9 | 2,96 ; 90,0 | 3,26 ; 100,8 |
| quân ta chết vì quân vừa mua / ván | 0,38 | 0,42 | 0,41 | 0,45 | 0,53 | 0,47 |
| quân lẻ bị dồn chết được / 100 lượt-quân | 5,86 | 5,59 | 5,35 | 6,21 | 6,13 | 5,37 |
| quân ta chết / ván ; quân quý chết | 9,70 ; 3,84 | 9,97 ; 4,04 | 10,18 ; 4,01 | 10,25 ; 4,12 | 10,96 ; 4,51 | 10,14 ; 4,37 |
| tướng ta chết / ván ; giết tướng địch | 0,73 ; 0,80 | 0,63 ; 0,78 | 0,68 ; 0,75 | 0,73 ; 0,74 | 0,66 ; 0,73 | 0,66 ; 0,72 |
| chiếm thành / ván | 1,68 | 1,80 | 1,77 | 1,79 | 1,73 | 1,77 |
| quân ta lên cấp / ván | 11,38 | 12,42 | 12,59 | 11,54 | **13,45** | 12,92 |
| đòn không giết, lỗ giá trị % | 4,05 | 3,37 | 3,10 | 3,86 | **5,35** | 3,34 |
| quân quý < 50 máu cuối lượt / ván ; % trên ô hồi | 5,15 ; 54 | 5,72 ; 53 | 5,67 ; 57 | 5,56 ; 52 | 5,83 ; 53 | 5,35 ; 53 |

- `pl_dp`: điểm quyết định ở 30% lần lập (snipe 3,65 / ván, giết 1,30, cả hai 0,44); ứng viên snipe được chọn 0,75 lần / ván; chiếm thành / giết tướng không đổi -> 0,495.
- `promo_w`: lên cấp nhiều hơn (+18%) nhưng đổi lỗ nhiều hơn, chết nhiều hơn -> 0,477.
- `pl_chain`: chỉ kiểm bằng test (`sim/tests/planner.gd` "pl_chain"): AI gần như không mua trống / sói -> không đo được bằng tự đấu.

Chỉnh lại v3 (không phải mẹo trên mạng; dev cùng salt 1000–1007, 192 ván vs `hard_v3`): `lone_w` 0,6: 0,518; `lone_n` 2: **0,414** (thua); `hero_cgoal` 1 (bản đã sửa thành trung lập): 0,492; `escort_w` 10: 0,539 (tướng đứng một mình 42,8% -> 34,9%; < 0,57 = ~2 SE, luật chọn ghi trước -> không đưa vào v4).

- Kết quả dev (7 cột bảng trên + 4 chỉnh v3): cao nhất 0,539 (`escort_w` 10), mẹo trên mạng cao nhất 0,526 < mức nhiễu kỳ vọng của số lớn nhất trong 7 lần rút (~0,55) -> **không có tín hiệu**. Chọn v4 = v3 + `buy_threat` 1 (knob duy nhất đổi đúng hành vi muốn: quân trong tầm quân địch mua −9%, sát thương quân vừa mua −5%), knob khác để 0. Spec cố định `hard_v4` (`sim/tune.gd`, `V4_TACTICS`, ghi rõ mọi knob mới). Kiểm: `hard_v3` ra đúng cùng ván ở code cũ (`3ef121a`) và code mới; `hard_v4` = `hard_v3+buy_threat:1` cùng ván.

**Seed giữ riêng (ghi trước khi xem kết quả)**: salt 9500000–007 `games=16` (768 ván) `hard_v4` vs `hard_v3`; 9500100–107 / 9500200–207 / 9500300–307 `games=9` (432 ván) vs `hard_v2_0` / Khó v1 / Thường, cùng seed cho hàng `hard_v3`. Luật ship: `AI.PRESETS.hard` = v4 chỉ khi (v4 vs `hard_v3`) ≥ 0,55 **và** v4 vs `hard_v2_0` / Khó v1 / Thường không kém hàng `hard_v3` quá ~1 SE **và** thời gian trong ngân sách (lượt TB ≤ ~0,3 s, tệ nhất ≤ 1,5 s trên Mac này). Không thì giữ v3, knob v4 để tắt, `hard_v4` vẫn cố định để so.

Kết quả seed giữ riêng (`tools/match_par.sh`, 8 tiến trình; cùng seed cho 2 hàng ở mỗi cột; ± SE nhị thức):

| A | vs `hard_v3` (768 ván, salt 9500000–007) | vs `hard_v2_0` (432, 9500100–107) | vs Khó v1 (432, 9500200–207) | vs Thường (432, 9500300–307) |
|---|---|---|---|---|
| `hard_v4` | **0,497 ± 0,018** | 0,775 ± 0,020 | 0,943 ± 0,011 | 0,924 ± 0,013 |
| `hard_v3` | 0,500 | 0,770 ± 0,020 | 0,954 ± 0,010 | 0,917 ± 0,013 |

- v4 vs v3 theo map (v4 ghế p / e, / 128): đồng bằng 81,5 / 43; cửa biển 56,5 / 67,5; núi rừng 25 / 108 -> lệch ghế rất mạnh, tổng = hòa.
- `pl_ms` (phanh 4 s) chạm 2 lần ở v4 vs Thường (máy tải ~10–20: phiên khác chạy song song) -> vài ván không tất định tuyệt đối, không đổi kết luận. Hàng khác: 0 lần.
- Thời gian (`tune.gd -- time a=<spec> b=hard_v1 games=4 salt=9100000`, 24 ván, v4 và v3 chạy cùng lúc, tải 5–10): **v4 lượt TB 302 ms, p95 573 ms, tệ nhất 1,06 s**; bước TB 32 ms, tệ nhất 696 ms. v3 cùng lúc: lượt 310 / 599 / 1130 ms -> v4 không chậm hơn (lượt TB ~0,3 s là do tải máy; v3 đo lúc tải 3–7: 176 ms).
- **Kết luận: không ship.** v4 vs v3 = 0,497 (cần ≥ 0,55); vs `hard_v2_0` / Khó v1 / Thường trong ~1 SE của v3 (+0,005 / −0,011 / +0,007). `AI.PRESETS.hard` giữ = Khó v3; knob v4 để 0; `hard_v4` vẫn cố định để so. Mạnh nhất + khôn nhất vẫn là **Khó v3** (v4 ngang v3, không hơn).

Ví dụ (`tactics_probe.gd -- games=4 salt=9200001 base=v4 opp=v3 ref=v3 exk=buy examples=6`; cùng thế cờ đầu lượt, `hard_v3` vs `hard_v4`; "chết được nhờ quân mua" = tổng đòn (roll giữa) của quân địch + quân địch mua được lượt sau ≥ máu, không tính quân mua thì < máu):
- Đồng bằng lượt 14 (ghế p): v3 để 3 lính (#2 53 máu ở (2,6), #7 (2,8), #10 (3,6)) chỉ chết được khi tính quân địch mua lượt sau; v4: lính #10 đánh từ (3,8), #7 đứng (2,7) đánh cùng -> 0 quân như vậy.
- Cửa biển lượt 16 (ghế p): v3 cho lính #16 còn 46 máu đánh từ (10,4) rồi đứng đó; v4 cho #16 lùi về (7,5), các quân khác đánh như cũ.
- Đồng bằng lượt 8 (ghế p): cả 2 dồn đánh tướng địch; v3 cho lính #12 (78 máu) đánh từ (10,4) (chết được nếu địch mua thêm), v4 cho #12 đánh từ (11,3), #13 (đầy máu) vào (10,4).

Vì sao không lên (khác v3):
- v3 sửa 1 lỗi chung của v1 (quân lẻ vào tầm địch) -> +0,13. Mẹo v4 nhắm tình huống hiếm trong tự đấu: quân địch vừa mua đánh ngay chỉ ~2,8 đòn / ván, giết 0,4 quân / ván; điểm quyết định (cướp thành / giết tướng) 30% lần lập nhưng tìm thêm 1 lượt (ply3 tham lam, không địch đáp sau) không chọn khác đi đáng kể; XP / thứ tự trống-sói gần như không xảy ra (AI chỉ mua lính / cung / thuyền: tự đấu v3 6 ván = 121 lính, 40 cung, 15 thuyền, 3 thầy mo, 0 trống / sói / voi / máy bắn đá / chim — đo của phiên chính).
- Lệch ghế theo map (25 / 128 vs 108 / 128 ở núi rừng) lớn hơn mọi hiệu ứng knob: 192 ván dev chỉ thấy được chênh ≥ ~0,07.

Thêm sau khi chốt held-out (T12, phiên chính báo: tự đấu v3 không mua trống / sói / voi / chim lần nào): `buy_sup` = n (`AI.DEFAULT`, `AI._support_want`): quân thường ≥ n mà chưa có trống / sói -> chỉ mua loại đó, để dành nếu vàng + 2 lượt thu nhập đủ. Dev vs `hard_v3` (salt 1000–1007, 192 ván): `buy_sup` 4: **0,224**; + `pl_chain` 1: **0,214** (mua trống / sói 0 -> ~1 / ván, mua tổng 14 -> 12,8 / ván, quân ta chết 9,7 -> 12 / ván, giết 10 -> 8,5). -> **để dành = mất nhịp, thua đậm**: với kinh tế này (300 vàng đầu, ~100–200 / lượt) quân rẻ ra ngay đáng hơn quân hỗ trợ ra muộn 2 lượt. Knob để 0 (test: `sim/tests/planner.gd` "buy_sup").

Tiếp (nếu muốn "siêu khó" / khôn hơn):
- Đội hình: AI mua theo `aiWeight` + `buy_cost_exp` và mua ngay khi đủ tiền -> trống / sói / chim không xuất hiện, mẹo T4 / T5 / T13 không có đất dùng. Để dành (`buy_sup`) thua đậm (0,22) -> nếu muốn AI dùng quân hỗ trợ "cho vui / cho người chơi thấy", chỉ mua khi đã dư vàng (không để dành), đo riêng hành vi; sức thắng tự đấu khó lên bằng đường này.
- Tìm sâu thật ở lượt quyết định: lượt sau của ta phải có địch đáp (ply 4) hoặc dùng dồn đòn giết làm lượt sau, không phải tham lam ply3.
- Người thật chơi thử Khó v3 trước khi đầu tư thêm (AI-vs-AI ≠ người).

### Đội hình linh hoạt = Khó v5 (2026-11-07, phiên 5)
Mục tiêu: AI mua loại quân theo tình huống + dùng đúng việc từng quân hỗ trợ (thầy mo gọi ma, thuyền đi sông, trống, sói, máy bắn đá, voi, chim), không chỉ lính + cung; chỉ ship nếu không yếu đi. Mốc = spec cố định `hard_v3`. Mã: `scripts/core/ai_buy.gd` (`AIBuy`, tách từ `ai.gd`, y nguyên hành vi: trace không đổi).

**Seed giữ riêng (ghi trước khi xem kết quả)**: `hard_v5` vs `hard_v3` salt 9700000–007 `games=16` (768 ván); vs `hard_v2_0` / Khó v1 / Thường salt 9700100–107 / 9700200–207 / 9700300–307 `games=9` (432 ván), cùng seed cho hàng `hard_v3`; thử spam: `hard_v3+_spam:1` (chỉ được mua lính + cung) vs `hard_v5` và vs `hard_v3`, salt 9700400–407 `games=4` (192 ván). Luật ship: `AI.PRESETS.hard` = v5 chỉ khi (v5 vs `hard_v3`) ≥ 0,50 trên 768 ván **và** v5 vs `hard_v2_0` / Khó v1 / Thường không kém hàng `hard_v3` quá ~1 SE **và** đội hình đa dạng hơn rõ (quân hỗ trợ được mua + làm việc thật) **và** thời gian trong ngân sách (lượt TB ≤ ~0,3 s, tệ nhất ≤ 1,5 s). Không thì giữ v3, knob v5 để 0, `hard_v5` cố định để so.

"Đa dạng hơn rõ" (ghi trước lượt dev cuối, đo bằng `sim/probes/army_probe.gd`, A vs `hard_v3`): ≥ 3 loại trong {thầy mo, trống, sói, voi, máy bắn đá, chim} được mua ≥ 0,2 / ván với tỉ lệ việc thật ≥ 30% **và** ma được gọi ≥ 2× v3 **và** thuyền kết thúc trên nước ≥ 2× v3.

Đo v3 trước (`army_probe.gd`, v3 vs v3, 96 ván, salt 2000–2007): mua / ván lính 9,1, cung 3,5, thuyền 1,2, thầy mo 0,4, sói / voi 0,02, trống / máy bắn đá / chim 0. Thầy mo: 19% lượt làm việc (gọi ma / đánh), 26% đứng yên; gọi ma 0,33 / ván; thuyền chỉ 15% lượt kết thúc trên nước. **Vàng lúc mua đầu lượt TB 264, ≥ 400 chỉ 7% số lượt, ≥ 600 0,2%** -> quân ≥ 600 gần như không bao giờ mua được nếu không để dành.

Bảng sát thương (ô trống, roll giữa) -> hiệu quả mỗi vàng kiểu Lanchester tuyến tính (sát thương / đòn × giá địch × số đòn chịu được / giá mình) khi địch toàn lính: lính 1,0, voi 0,81, cung 0,6 (×~1,5 vì bắn xa không bị phản), chim 0,44, sói 0,41, máy bắn đá 0,29; địch toàn voi: lính 1,24 (vẫn nhất). Chỉ khi địch có chim thì cung > lính (đã có `buy_aa`). -> **với bảng quân hiện tại, lính + cung là mua tốt nhất mỗi vàng trước mọi đội hình**: "mua khắc chế" không thể trừng phạt người dồn quân rẻ; cần đổi cân bằng (giá / chỉ số, việc của nội dung), không phải AI.

Knob (`AI.DEFAULT`, mặc định 0 = tắt -> Dễ / Thường / chiến dịch / golden y nguyên; trace 160 dòng không đổi):

| Knob | Cách làm |
|---|---|
| `role_w` (dùng đúng việc) | thầy mo không gọi được ma thì **đi sau cùng** (`greedy_step`: chờ đòn của quân khác tạo mộ), ô đứng cạnh mộ mới (còn gọi được lượt sau) + `role_w` × `raise` × 0,5; trống phủ ≥ 2 quân chưa đi còn đánh tới địch -> **đi trước**; sói: đòn không giết + `role_w` × 10 × số quân ta còn đánh tới mục tiêu × giá trị mục tiêu / 100 (cắn trước); thuyền: ô nước tính thêm `waterDef` 15 vào thủ ô (trước đây điểm vị trí bỏ qua -> thuyền đứng trên cạn) |
| `mix_w` (mua theo tình huống, chỉ loại mua được ngay) | `AIBuy._mix_bonus` cộng vào trọng số mua: thầy mo +2 / mộ trong tầm (mv + 1) từ thành mua (mua xong đi + gọi ma ngay lượt đó), +1,5 nếu chưa có thầy mo và có mộ / đang giáp trận; thuyền +1 nếu đường sông tới thành địch ngắn hơn đi bộ ≥ 2; trống +1,5 khi ≥ 4 quân ta trong bán kính 2 đang giáp trận; sói +1 khi địch có quân thủ ≥ 15 / cấp ≥ 2; voi +1 khi địch ≥ 3 quân bắn xa; máy bắn đá +1 khi ≥ 2 địch đứng trên công trình; chim +0,5 khi địch không có quân chống chim |
| `mix_save` k | vật chất ta (giá × máu + vàng) ≥ (1 + k) × địch -> để dành **1 lượt** thu nhập cho loại ≥ 500 vàng đang được gọi (thưởng lớn nhất, rồi rẻ nhất). Không bao giờ để dành khi đang thua (bài học v4 `buy_sup`) |
| `sham_save` 1 | `mix_save` cũng để dành cho thầy mo khi có mộ trong tầm từ thành |
| `pl_chain` 1 (có từ v4) | trống / sói đánh trước trong chuỗi dồn đòn giết |

Đo dev (A vs `hard_v3`, 192 ván / thử, ± 0,036 SE; mốc cùng chỉ số = v3 vs v3 ở trên):

| Thử (salt) | điểm | mua / ván: thầy mo · trống · sói · voi · máy bắn đá · chim | ma gọi / ván | thuyền trên nước | trống phủ quân chưa đi / ván | sói cắn / ván |
|---|---|---|---|---|---|---|
| v3 (mốc, 2000–007, 96 ván) | 0,500 | 0,40 · 0 · 0,02 · 0,02 · 0 · 0 | 0,33 | 15% | 0 | 0 |
| `role_w` 1 + `mix_w` 1 + `pl_chain` 1 (3000–007) | 0,518 | 0,51 · 0,01 · 0,01 · 0,01 · 0 · 0 | 0,35 | 31% | 0,80 | 0,01 |
| + `mix_save` 0,25 (3000–007) | 0,505 | 0,38 · 0,21 · 0,18 · 0,02 · 0,08 · 0,04 | 0,43 | 36% | 2,69 | 0,29 |
| như dòng 2, thầy mo +1,5 khi chưa có + sói cắn trước (3000–007) | 0,521 | 0,52 · 0,01 · 0 · 0 · 0 · 0,01 | 0,40 | 31% | 0,37 | 0 |
| + `mix_save` 0,1 (3100–107) | 0,487 | 0,41 · 0,21 · 0,11 · 0,05 · 0,05 · 0,07 | 0,44 | 31% | 3,59 | 0,20 |
| + `mix_save` 0,1 + `sham_save` 1 = **`hard_v5`** (3100–107) | 0,458 | **0,71 · 0,27** · 0,14 · 0,02 · 0,05 · 0,06 | **1,60** (4,8×) | 30% (2×) | 4,28 | 0,35 |

- Code đổi giữa các dòng (dòng 2: thầy mo bản đầu; dòng 3: chưa có sói cắn trước; từ dòng 4: bản cuối) -> không phải tách lỗi sạch; 3 dòng cuối cùng code.
- Tỉ lệ lượt làm việc thật (`hard_v5`, dev 3100): thầy mo 44% (v3 19%), ma 37% (v3 11%), trống 64%, sói 42%, chim 33%, máy bắn đá 23%, voi 22%.
- Không để dành: mạnh ngang v3 (0,52) nhưng đội hình gần như không đổi (quân ≥ 400 vàng không mua được ngay). Có để dành: đa dạng hơn, nhưng điểm tụt dần theo mức để dành (0,505 -> 0,487 -> 0,458).
- Luật "đa dạng hơn rõ" với `hard_v5` (dev): ma 4,8× ✓, thuyền trên nước 2× ✓, nhưng chỉ 2 loại hỗ trợ ≥ 0,2 / ván (thầy mo, trống; sói 0,14) ✗ -> **trượt ngay ở dev**. Vẫn chạy held-out để có số (`hard_v5` cố định = ứng viên đa dạng nhất).
- Thời gian (`tune.gd -- time a=<spec> b=hard_v1 games=4 salt=9100000`, 24 ván, v5 và v3 chạy cùng lúc, tải ~4–5): **v5 lượt TB 211 ms, p95 503 ms, tệ nhất 848 ms**; bước TB 21 ms, tệ nhất 834 ms. v3 cùng lúc: lượt 193 / 399 / 632 ms -> trong ngân sách (+9% TB).

**Kết quả seed giữ riêng** (`tools/match_par.sh`, 8 tiến trình, chạy từ bản chụp code `0d21793` (riêng `hard_v3` vs `hard_v2_0`: `3e66a9b`); kiểm: `hard_v3` ra đúng cùng 6 ván ở code master `a127c25` và code mới, `hard_v5` = `hard_v3+role_w:1+mix_w:1+pl_chain:1+mix_save:0,1+sham_save:1` cùng ván (salt 9410003); cùng seed cho 2 hàng ở mỗi cột; ± SE nhị thức; không lần nào chạm `pl_ms`):

| A | vs `hard_v3` (768, 9700000–007) | vs `hard_v2_0` (432, 9700100–107) | vs Khó v1 (432, 9700200–207) | vs Thường (432, 9700300–307) |
|---|---|---|---|---|
| `hard_v5` | **0,431 ± 0,018** | 0,734 ± 0,021 | 0,934 ± 0,012 | 0,909 ± 0,014 |
| `hard_v3` | 0,500 | 0,766 ± 0,020 | 0,935 ± 0,012 | 0,917 ± 0,013 |

- v5 vs v3 theo map (v5 ghế p / e, / 128): đồng bằng 75,5 / 53; cửa biển 57 / 56; núi rừng **17** / 72,5 -> thua nặng nhất ở núi rừng ghế p.
- Vs bot yếu hơn: ngang v3 (−0,001 Khó v1, −0,008 Thường, trong 1 SE); vs `hard_v2_0` −0,032 (~1,5 SE).

**Thử spam** (salt 9700400–407, 192 ván / dòng; A = `hard_v3+_spam:1` = Khó v3 chỉ được mua lính + cung):

| A (chỉ lính + cung) vs | điểm A |
|---|---|
| `hard_v5` | 0,607 ± 0,035 |
| `hard_v3` (đủ loại) | **0,586 ± 0,036** |

- Dồn quân rẻ không bị trừng phạt — còn **mạnh hơn** chính nó khi được mua đủ loại (+0,09, ~2,4 SE): Khó v3 phí vàng cho thuyền / thầy mo. v5 không đổi điều đó (0,607 vs 0,586: trong nhiễu). Khớp bảng sát thương ở trên: với chỉ số / giá hiện tại, lính + cung là tối ưu mỗi vàng -> trừng phạt spam là việc **cân bằng nội dung** (ghi `docs/TODO.md`).

**Kết luận: không ship.** Trượt cả 2 luật: v5 vs v3 = 0,431 (cần ≥ 0,50) và "đa dạng hơn rõ" (dev: 2 / 3 loại hỗ trợ ≥ 0,2 / ván). `AI.PRESETS.hard` giữ = Khó v3; knob v5 để 0; `hard_v5` (`sim/tune.gd` `V5_ARMY`) cố định để so. Màn g11 / g17 / g20 (`"ai": "hard"`) không đổi -> không cần đo lại.

Vì sao:
- Vàng lúc mua TB ~270: quân ≥ 400 chỉ mua được ngay ở 7–12% lượt. Đa dạng thật cần để dành, và mỗi lượt để dành = 1–2 lính ra trận muộn 1 lượt; AE2 tính sát thương × máu / 100 + dồn đòn -> số quân (Lanchester bậc 2) thắng chất lượng. Cùng bài học v4 `buy_sup` (0,22), nhẹ hơn vì chỉ để dành 1 lượt và chỉ khi đang hơn.
- Sau held-out (không ghi trước, chỉ để hiểu): v5 **không để dành** (`hard_v3+role_w:1+mix_w:1+pl_chain:1`) cùng seed 9700000–007: **0,497 ± 0,018** vs v3 (768 ván; núi rừng ghế e 108 / 128, ghế p 21,5 / 128) = hòa. -> dùng đúng việc + mua theo tình huống (mua được ngay) trung tính; phần làm yếu là để dành (`mix_save` / `sham_save`): ~−0,07.
- Phần "dùng đúng việc" (`role_w`) có tác dụng rõ (ma gọi 0,33 -> 1,60 / ván, thầy mo làm việc 19% -> 44%, ma 11% -> 37%, thuyền trên nước 15% -> 30%, trống phủ ~4 quân chưa đi / ván) nhưng quân hỗ trợ hiếm nên không đổi được kết quả ván.

Ví dụ (`army_probe.gd -- a=hard_v5 b=hard_v3 games=1 salt=<s> examples=12`, v5 dùng quân hỗ trợ):
- Núi rừng, salt 9200000 (v5 ghế e): thầy mo #21 (400 vàng) gọi 5 ma ở lượt 8, 10, 11, 16, 17 — lượt 8: tới (9,0), gọi ma trên mộ (10,0); v3 cả ván 96 ván chỉ gọi 0,33 ma / ván.
- Đồng bằng lượt 31, salt 9200001 (v5 ghế e): trống #39 đi trước tới (2,3), +10 công cho 8 quân chưa đi rồi cả nhóm mới đánh (lượt 25–30: mỗi lượt phủ 3–4 quân).
- Núi rừng lượt 5–11, salt 9200001 (v5 ghế e): thầy mo #15 gọi ma ở lượt 5 (mộ (10,3)), 7, 9, 10, 11 -> 5 quân miễn phí, không tính vào giới hạn quân.

Tiếp (nếu muốn đội hình đa dạng mà không yếu):
- Cân bằng nội dung trước (phiên nội dung): giá / chỉ số để quân đắt đáng tiền mỗi vàng (vd voi 450, sói 450, trống 350; hoặc lính yếu đi). Rồi đo lại `hard_v5` + bản không để dành — AI đã sẵn mua theo tình huống + dùng đúng việc.
- Ship riêng `role_w` (không mua thêm) như "chơi đúng việc" cho màn có sẵn quân hỗ trợ / đấu với người hay mua trống, sói, thầy mo: cần held-out riêng (≥ 768 ván) + test màn.
- Tò mò: Khó v3 chỉ mua lính + cung thắng Khó v3 đủ loại 0,586 -> bỏ thuyền / thầy mo khỏi danh sách mua của Khó có thể **mạnh hơn** (ngược mục tiêu đa dạng; chỉ ghi lại).

## Độ khó (phác thảo, chưa nối vào game)
Cho chế độ 1v1 sau này (người vs người tại chỗ, hoặc người vs AI Dễ / Thường / Khó). Nối: lúc tạo ván, `s.aiParams = { "e": PRESET }` (lưu cùng ván -> nạp lại vẫn đúng mức).

| Mức | Params | Ghi chú |
|---|---|---|
| Dễ | `noise` 60, `caution` 0, `caution_hero` 0.3, `home_hp` 0, `heal_hp` 0, `maydie_w` 0.1 | liều: không sợ chết, không về hồi máu, chọn nước thô |
| Dễ + ½ vàng | Dễ + vàng đầu ván ×0.5 (`skirmish_def(..., easy=true)` đã có cho phe e) | chấp thêm |
| Thường | `DEFAULT` | AI hiện tại |
| Khó (v1, tới 2026-11-06) | `sim/tuned_params.txt` (`noise` giữ 8) | tham số tự đấu. Bản ít nhiễu (`noise` 2, `hard_n2`) đo ra **yếu hơn** Thường -> bỏ. Nay Khó = v2 (mục "Khó v2" ở trên) |

Đo (`sim/tune.gd -- presets games=8`, 4 bộ seed salt 9000000/10/20/30, 192 ván / cặp; điểm hàng vs cột, thắng 1 hòa 0,5):

| | Dễ+½ vàng | Dễ | Thường | Khó | Khó noise 2 |
|---|---|---|---|---|---|
| Dễ+½ vàng | – | 0,318 | 0,125 | 0,146 | 0,120 |
| Dễ | 0,682 | – | 0,326 | 0,234 | 0,260 |
| Thường | 0,875 | 0,674 | – | 0,448 | 0,542 |
| Khó | 0,854 | 0,766 | 0,552 | – | 0,539 |
| Khó noise 2 | 0,880 | 0,740 | 0,458 | 0,461 | – |

- Thứ tự đúng: Dễ+½ vàng < Dễ < Thường < Khó. Khó vs Thường 0,552 (riêng 3 bộ seed không dùng để chọn đảo: 0,549).
- Khoảng cách Thường–Khó nhỏ (~55%): muốn Khó rõ hơn -> tune lâu hơn / nhiều ván hơn mỗi thế hệ, hoặc cho Khó thêm vàng.
- Dễ còn thắng Thường ~1/3 (AI-vs-AI); với người thật, Dễ nên thử chơi trước khi chốt số.
