extends RefCounted
## how to play each unit type (same mechanics for both sides, so one text per type; names come from the theme).
## Shown by the new-unit intro, the ⓘ popup on every unit and the codex. Trait lines are generated from the stats
## in Content.traits(); this file only holds the hand-written "role" + "how to use" lines.

const ROLE := {
	"hero": "Tướng chỉ huy",
	"soldier": "Lính chủ lực",
	"archer": "Bắn xa",
	"drum": "Trợ chiến",
	"shaman": "Pháp sư · cứu thương",
	"elephant": "Xung kích · chịu đòn",
	"bird": "Kỵ binh cơ động",
	"catapult": "Công thành tầm xa",
	"ghost": "Quân cứu dậy",
}

const PLAY := {
	"hero": "Tướng mạnh nhất trận và là người duy nhất chiếm được thành. Đánh kết liễu để lên sao, nhưng đừng để bị vây: mất tướng thường là thua.",
	"soldier": "Rẻ và đông. Đi đầu chiếm làng để có vàng, xếp thành hàng che cho lính bắn xa đứng phía sau.",
	"archer": "Đứng sau hàng lính, bắn từ ô thứ 2 để lính cận chiến không đánh trả được. Ưu tiên bắn kỵ binh.",
	"drum": "Đánh yếu, đừng đưa lên đầu. Đứng ngay sau hàng lính: mọi quân ta kề bên +10 công, cho chúng ra đòn trước.",
	"shaman": "Bắn bỏ qua thủ địa hình: dùng để hạ địch núp trong rừng, trên đồi, trong thành. Đứng cạnh mộ để cứu lính ngã dậy.",
	"elephant": "Thủ dày, đánh mạnh nhưng chậm. Đưa lên chặn cầu, cửa ải hoặc húc thẳng vào chỗ địch đông.",
	"bird": "Đi rất nhanh, vượt sông núi. Vòng ra sau đánh lính bắn xa và máy bắn đá, cướp làng xa. Tránh lính bắn tên.",
	"catapult": "Đứng yên mới bắn được, tầm 2–4 ô, không đánh trả. Giữ thật xa phía sau và luôn có lính che trước mặt.",
	"ghost": "Được cứu dậy miễn phí. Dùng làm lá chắn, chặn đường hoặc đánh phụ cho lính khác.",
}
