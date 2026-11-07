extends RefCounted
# prose / map rows: one line each reads better
# gdlint: disable=max-line-length
## how to play each unit type (same mechanics for both sides, so one text per type; names come from the theme).
## Shown by the new-unit intro, the ⓘ popup on every unit and the codex. Trait lines are generated from the stats
## in Content.traits(); this file only holds the hand-written "role" + "how to use" lines.

const ROLE := {
	"hero": "Tướng chỉ huy",
	"soldier": "Lính chủ lực",
	"archer": "Bắn xa · diệt rồng",
	"boat": "Thủy chiến",
	"shaman": "Gọi hồn",
	"drum": "Trợ chiến",
	"wolf": "Đánh nhanh · làm yếu địch",
	"elephant": "Xung kích · chịu đòn",
	"catapult": "Công thành tầm xa",
	"bird": "Bay · mạnh nhất",
	"ghost": "Xác lính gọi dậy",
}

const PLAY := {
	"hero": "Người duy nhất chiếm được lâu đài, cũng chiếm được làng. Đánh kết liễu để lên cấp. Ngã thì mua lại ở lâu đài (200 vàng, mỗi lần ngã +200, tối đa 1000), giữ nguyên cấp. Mất cả tướng lẫn lâu đài là thua.",
	"soldier": "Rẻ và đông. Đi đầu chiếm làng để có vàng, xếp thành hàng khiên che cho lính bắn xa đứng phía sau.",
	"archer": "Đứng sau hàng lính, bắn từ ô thứ 2 thì địch không đánh trả được. Bắn rồng +15 công: luôn giữ cung thủ khi địch có rồng.",
	"boat": "Đi trên sông chỉ 1 bước, đứng dưới nước +10 công, +15 thủ. Giữ khúc sông, chặn chỗ lội, đánh địch đang lội (dưới nước chúng không được thủ). Lên bờ thì đi như vệ binh.",
	"shaman": "Đánh yếu, đừng đưa lên đầu. Đứng cạnh lính ngã (cả lính địch) rồi bấm Gọi hồn: thêm một bộ xương miễn phí. Lính ngã mất sau lượt kế của mỗi bên, nên đứng gần chỗ đang đánh.",
	"drum": "Ra lệnh cho tu sĩ trước (đánh hoặc chờ): quân ta trong 2 ô +10 công tới lượt sau, rồi mới cho cả đội đánh. Đánh bộ xương +15 công.",
	"wolf": "Chạy 6 bước. Cắn trúng thì địch −10 công, −10 thủ tới lượt sau của ta: cho sói cắn trước, quân khác đánh sau. Hợp săn cung thủ, máy bắn đá đứng lẻ.",
	"elephant": "Thủ rất dày, đánh mạnh, lên được cả núi. Đưa lên chặn cầu, cửa ải hoặc đấm thẳng vào chỗ địch đông. Đắt: đừng để bị vây.",
	"catapult": "Đứng yên mới ném được, tầm 2–4 ô, không đánh trả. Phá được làng địch. Giữ thật xa phía sau và luôn có lính che trước mặt.",
	"bird": "Bay qua sông, núi chỉ tốn 1 bước, đi 7 ô. Mạnh nhất, đắt nhất (1000 vàng). Vòng ra sau đánh máy bắn đá, cung thủ đứng lẻ, cướp làng xa. Tránh cung thủ địch.",
	"ghost": "Pháp sư gọi hồn dựng dậy, không mua được, không tính vào trần quân, không chiếm được làng. Dùng làm lá chắn, chặn đường hoặc đánh phụ. Sợ tu sĩ ánh sáng.",
}
