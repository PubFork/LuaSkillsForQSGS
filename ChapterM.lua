--[[
	代码速查手册（M区）
	技能索引：
		马术、蛮裔、漫卷、猛进、秘计、秘计、密信、密诏、灭计、名士、名士、明策、明鉴、明哲、谋断、谋溃、谋诛
]]--
--[[
	技能名：马术（锁定技）
	相关武将：标准·马超、火·庞德、SP·庞德、SP·关羽、SP·最强神话、SP·暴怒战神、SP·马超、一将成名2012·马岱、怀旧-一将2·马岱-旧、国战·马腾、2013-3v3·吕布、SP·台版马超
	描述：你计算的与其他角色的距离-1。
	引用：LuaMashu
	状态：验证通过
]]--
LuaMashu = sgs.CreateDistanceSkill{
	name = "LuaMashu",
	correct_func = function(self, from, to)
		if from:hasSkill("LuaMashu") then
			return -1
		end
	end,
}
--[[
	技能名：蛮裔
	相关武将：1v1·孟获1v1、1v1·祝融1v1
	描述：你登场时，你可以视为使用一张【南蛮入侵】。锁定技，【南蛮入侵】对你无效。
	状态：验证通过（kof1v1模式下通过）
]]--
LuaSavageAssaultAvoid = sgs.CreateTriggerSkill{
	name = "#LuaSavageAssaultAvoid",
	events = {sgs.CardEffected},
	on_trigger = function(self, event, player, data)
		local effect = data:toCardEffect()
		if effect.card:isKindOf("SavageAssault") then
			return true
		else
			return false
		end
	end
}
LuaManyi = sgs.CreateTriggerSkill{
	name = "LuaManyi",
	events = {sgs.Debut},
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local opponent = player:getNext()
		if not opponent:isAlive() then return end
		local nm = sgs.Sanguosha:cloneCard("savage_assault", sgs.Card_NoSuit, 0)
		nm:setSkillName(self:objectName())
		if not nm:isAvailable(player) then nm = nil return end
		if player:askForSkillInvoke(self:objectName()) then
			room:useCard(sgs.CardUseStruct(nm, player, nil))
			return
		end
	end
}
--[[
	技能名：漫卷
	相关武将：☆SP·庞统
	描述：每当你将获得任何一张手牌，将之置于弃牌堆。若此情况处于你的回合中，你可依次将与该牌点数相同的一张牌从弃牌堆置于你的手上。
	引用：LuaManjuan
	状态：验证通过
]]--
DoManjuan = function(player, id, skillname)
	local room = player:getRoom()
	player:setFlags("ManjuanInvoke")
	local DiscardPile = room:getDiscardPile()
	local toGainList = sgs.IntList()
	local card = sgs.Sanguosha:getCard(id)
	for _,cid in sgs.qlist(DiscardPile) do
		local cd = sgs.Sanguosha:getCard(cid)
		if cd:getNumber() == card:getNumber() then
			toGainList:append(cid)
		end
	end
	room:fillAG(toGainList, player)
	local card_id = room:askForAG(player, toGainList, false, skillname)
	if card_id ~= -1 then
		local gain_card = sgs.Sanguosha:getCard(card_id)
		room:moveCardTo(gain_card, player, sgs.Player_PlaceHand, true)
	end
	player:invoke("clearAG")
end
LuaManjuan = sgs.CreateTriggerSkill{
	name = "LuaManjuan",
	frequency = sgs.Skill_Frequent,
	events = {sgs.CardsMoveOneTime, sgs.CardDrawing},
	on_trigger = function(self, event, player, data)
		if player:hasFlag("ManjuanInvoke") then
			player:setFlags("-ManjuanInvoke")
			return false
		end
		local card_id = -1
		local reason = sgs.CardMoveReason(sgs.CardMoveReason_S_REASON_PUT, player:objectName(), self:objectName(), "")
		local room = player:getRoom()
		if event == sgs.CardsMoveOneTime then
			local move = data:toMoveOneTime()
			local dest = move.to
			local flag = true
			if dest then
				if dest:objectName() == player:objectName() then
					if move.to_place == sgs.Player_PlaceHand then
						if move.from and dest:objectName() ~= move.from:objectName() then
							for _,card_id in sgs.qlist(move.card_ids) do
								local card = sgs.Sanguosha:getCard(card_id)
								room:moveCardTo(card, nil, nil, sgs.Player_DiscardPile, reason)
								flag = false
							end
						end
					end
				end
			end
			if flag then
				return false
			end
		elseif event == sgs.CardDrawing then
			local tag = room:getTag("FirstRound")
			if tag:toBool() then
				return false
			else
				card_id = data:toInt()
				local card = sgs.Sanguosha:getCard(card_id)
				room:moveCardTo(card, nil, nil, sgs.Player_DiscardPile, reason)
			end
		end
		if player:getPhase() ~= sgs.Player_NotActive then
			if player:askForSkillInvoke(self:objectName(), data) then
				if event == sgs.CardsMoveOneTime then
					local move = data:toMoveOneTime()
					for _,card_id in sgs.qlist(move.card_ids) do
						DoManjuan(player, card_id, self:objectName())
					end
				else
					DoManjuan(player, card_id, self:objectName())
				end
				return event ~= sgs.CardsMoveOneTime
			end
		end
		return event ~= sgs.CardsMoveOneTime
	end,
	priority = 2
}
--[[
	技能名：猛进
	相关武将：火·庞德、SP·庞德
	描述：当你使用的【杀】被目标角色的【闪】抵消时，你可以弃置其一张牌。
	引用：LuaMengjin
	状态：验证通过
]]--
LuaMengjin = sgs.CreateTriggerSkill{
	name = "LuaMengjin",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.SlashMissed},
	on_trigger = function(self, event, player, data)
		local effect = data:toSlashEffect()
		local dest = effect.to
		if dest:isAlive() then
			if not dest:isNude() then
				if player:askForSkillInvoke(self:objectName(), data) then
					local room = player:getRoom()
					local to_throw = room:askForCardChosen(player, dest, "he", self:objectName())
					local card = sgs.Sanguosha:getCard(to_throw)
					room:throwCard(card, dest, player);
				end
			end
		end
		return false
	end,
	priority = 2
}
--[[
	技能名：秘计
	相关武将：一将成名2012·王异
	描述：结束阶段开始时，若你已受伤，你可以摸一至X张牌（X为你已损失的体力值），然后将相同数量的手牌以任意分配方式交给任意数量的其他角色。
	引用：LuaMiji
	状态：1217验证通过
]]--
LuaMiji = sgs.CreateTriggerSkill{
	name = "LuaMiji" ,
	events = {sgs.EventPhaseStart} ,
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		if (player:getPhase() == sgs.Player_Finish) and player:isWounded() then
			if player:askForSkillInvoke(self:objectName()) then
				local draw_num = {}
				for i = 1, player:getLostHp(), 1 do
					table.insert(draw_num, tostring(i))
				end
				local num = tonumber(room:askForChoice(player, "LuaMiji_draw", table.concat(draw_num, "+")))
				player:drawCards(num, self:objectName())
				if not player:isKongcheng() then
					local n = 0
					while true do
						local original_handcardnum = player:getHandcardNum()
						if (n < num) and (not player:isKongcheng()) then
							local handcards = player:handCards()
							if (not room:askForYiji(player,handcards,self:objectName(),false, false, false, num - n)) then break end
							n = n + (original_handcardnum - player:getHandcardNum())
						else
							break
						end
					end
					if (n < num) and (not player:isKongcheng()) then
						local rest_num = num - n
						while true do
							local handcard_list = player:handCards()
							--qShuffle(handcard_list);
							math.randomseed(os.time)
							local give = math.random(1, rest_num)
							rest_num = rest_num - give
							local to_give
							if handcard_list:length() < give then
								to_give = handcard_list
							else
								to_give = handcard_list:mid(0, give)
							end
							local receiver = room:getOtherPlayers(player):at(math.random(0, player:aliveCount() - 1))
							local dummy = sgs.Sanguosha:getCard("slash", sgs.Card_NoSuit, 0)
							for _, id in sgs.qlist(to_give) do
								dummy:addSubcard(id)
							end
							room:obtainCard(receiver, dummy, false)
							if (rest_num == 0) or player:isKongcheng() then break end
						end
					end
				end
			end
		end
		return false
	end
}
--[[
	技能名：秘计
	相关武将：怀旧-一将2·王异-旧
	描述：回合开始/结束阶段开始时，若你已受伤，你可以进行一次判定，若判定结果为黑色，你观看牌堆顶的X张牌（X为你已损失的体力值），然后将这些牌交给一名角色。
	引用：LuaMiji
	状态：1111验证通过
]]--
LuaMiji = sgs.CreateTriggerSkill{
	name = "LuaMiji",
	frequency = sgs.Skill_Frequent,
	events = {sgs.EventPhaseStart},
	on_trigger = function(self, event, player, data)
		if player:isWounded() then
			local phase = player:getPhase()
			if phase == sgs.Player_Start or phase == sgs.Player_Finish then
				if player:askForSkillInvoke(self:objectName()) then
					local room = player:getRoom()
					local judge = sgs.JudgeStruct()
					judge.pattern = sgs.QRegExp("(.*):(club|spade):(.*)")
					judge.good = true
					judge.reason = self:objectName()
					judge.who = player
					room:judge(judge)
					if judge:isGood() then
						local x = player:getLostHp()
						local miji_cards = sgs.CardList()
						miji_cards = room:getNCards(x,false)
						local miji_card = sgs.Sanguosha:cloneCard("Slash",sgs.Card_Spade,13)
						for _,card in sgs.qlist(miji_cards) do
							miji_card:addSubcard(card)
						end
						room:obtainCard(player, miji_card, false)
						local playerlist = room:getAllPlayers()
						local target = room:askForPlayerChosen(player, playerlist, self:objectName())
						room:obtainCard(target, miji_card, false)
					end
				end
			end
		end
		return false
	end,
}
--[[
	技能名：密信
	相关武将：铜雀台·伏皇后
	描述：出牌阶段限一次，你可以将一张手牌交给一名其他角色，该角色须对你选择的另一名角色使用一张【杀】（无距离限制），否则你选择的角色观看其手牌并获得其中任意一张。
	引用：LuaXMixin
	状态：验证通过
]]--
LuaXMixinCard = sgs.CreateSkillCard{
	name = "LuaXMixinCard",
	target_fixed = false,
	will_throw = false,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			return to_select:objectName() ~= sgs.Self:objectName()
		end
		return false
	end,
	on_effect = function(self, effect)
		local source = effect.from
		local target = effect.to
		local room = source:getRoom()
		target:obtainCard(self, false)
		local others = sgs.SPlayerList()
		local list = room:getOtherPlayers(target)
		for _,p in sgs.qlist(list) do
			if target:canSlash(p, nil, false) then
				others:append(p)
			end
		end
		if not others:isEmpty() then
			local target2 = room:askForPlayerChosen(source, others, "LuaXMixin")
			room:setPlayerFlag(target, "jiefanUsed")
			if room:askForUseSlashTo(target, target2, "#mixin") then
				room:setPlayerFlag(target, "-jiefanUsed")
			else
				room:setPlayerFlag(target, "-jiefanUsed")
				local card_ids = target:handCards()
				room:fillAG(card_ids, target2)
				local cdid = room:askForAG(target2, card_ids, false, self:objectName())
				room:obtainCard(target2, cdid, false)
				target2:invoke("clearAG")
			end
			return
		end
	end
}
LuaXMixin = sgs.CreateViewAsSkill{
	name = "LuaXMixin",
	n = 1,
	view_filter = function(self, selected, to_select)
		return not to_select:isEquipped()
	end,
	view_as = function(self, cards)
		if #cards == 1 then
			local card = LuaXMixinCard:clone()
			card:addSubcard(cards[1])
			return card
		end
	end,
	enabled_at_play = function(self, player)
		return not player:hasUsed("#LuaXMixinCard")
	end
}
--[[
	技能名：密诏
	相关武将：铜雀台·汉献帝、SP·刘协
	描述：出牌阶段限一次，你可以将所有手牌（至少一张）交给一名其他角色：若如此做，你令该角色与另一名由你指定的有手牌的角色拼点：若一名角色赢，视为该角色对没赢的角色使用一张【杀】。
	引用：LuaXMizhao
	状态：验证通过
]]--
LuaXMizhaoCard = sgs.CreateSkillCard{
	name = "LuaXMizhaoCard",
	target_fixed = false,
	will_throw = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			return to_select:objectName() ~= sgs.Self:objectName()
		end
		return false
	end,
	on_effect = function(self, effect)
		local source = effect.from
		local target = effect.to
		target:obtainCard(effect.card, false)
		local room = source:getRoom()
		local targets = sgs.SPlayerList()
		local others = room:getOtherPlayers(target)
		for _,p in sgs.qlist(others) do
			if not p:isKongcheng() then
				targets:append(p)
			end
		end
		if not target:isKongcheng() then
			if not targets:isEmpty() then
				local dest = room:askForPlayerChosen(source, targets, "LuaXMizhao")
				target:pindian(dest, "LuaXMizhao", nil)
			end
		end
	end
}
LuaXMizhaoVS = sgs.CreateViewAsSkill{
	name = "LuaXMizhao",
	n = 999,
	view_filter = function(self, selected, to_select)
		return not to_select:isEquipped()
	end,
	view_as = function(self, cards)
		local count = sgs.Self:getHandcardNum()
		if #cards == count then
			local card = LuaXMizhaoCard:clone()
			for _,cd in pairs(cards) do
				card:addSubcard(cd)
			end
			return card
		end
	end,
	enabled_at_play = function(self, player)
		if not player:isKongcheng() then
			return not player:hasUsed("#LuaXMizhaoCard")
		end
		return false
	end
}
LuaXMizhao = sgs.CreateTriggerSkill{
	name = "LuaXMizhao",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.Pindian},
	view_as_skill = LuaXMizhaoVS,
	on_trigger = function(self, event, player, data)
		local pindian = data:toPindian()
		if pindian.reason == self:objectName() then
			local fromNumber = pindian.from_card:getNumber()
			local toNumber = pindian.to_card:getNumber()
			if fromNumber ~= toNumber then
				local winner
				local loser
				if fromNumber > toNumber then
					winner = pindian.from
					loser = pindian.to
				else
					winner = pindian.to
					loser = pindian.from
				end
				if winner:canSlash(loser, nil, false) then
					local room = player:getRoom()
					local slash = sgs.Sanguosha:cloneCard("slash", sgs.Card_NoSuit, 0)
					slash:setSkillName("LuaXMizhao")
					local card_use = sgs.CardUseStruct()
					card_use.from = winner
					card_use.to:append(loser)
					card_use.card = slash
					room:useCard(card_use, false)
				end
			end
		end
		return false
	end,
	can_trigger = function(self, target)
		return target
	end,
	priority = -1
}
--[[
	技能名：灭计（锁定技）
	相关武将：一将成名2013·李儒
	描述：你使用黑色非延时类锦囊牌的目标数上限至少为二。
	引用：LuaMieji、LuaMiejiTargetMod
	状态：1217验证通过
]]--
---------------------Ex借刀杀人技能卡---------------------
function targetsTable2QList(thetable)
	local theqlist = sgs.PlayerList()
	for _, p in ipairs(thetable) do
		theqlist:append(p)
	end
	return theqlist
end
LuaExtraCollateralCard = sgs.CreateSkillCard{
	name = "LuaExtraCollateralCard" ,
	filter = function(self, targets, to_select)
		local coll = sgs.Card_Parse(sgs.Self:property("extra_collateral"):toString())
		if (not coll) then return false end
		local tos = sgs.Self:property("extra_collateral_current_targets"):toString():split("+")
		if (#targets == 0) then
			return (not table.contains(tos, to_select:objectName())) 
					and (not sgs.Self:isProhibited(to_select, coll)) and coll:targetFilter(targetsTable2QList(targets), to_select, sgs.Self)
		else
			return coll:targetFilter(targetsTable2QList(targets), to_select, sgs.Self)
		end
	end ,
	about_to_use = function(self, room, cardUse)
		local killer = cardUse.to:first()
		local victim = cardUse.to:last()
		killer:setFlags("ExtraCollateralTarget")
		local _data = sgs.QVariant()
		_data:setValue(victim)
		killer:setTag("collateralVictim", _data)
	end
}
----------------------------------------------------------
LuaMiejiTargetMod = sgs.CreateTargetModSkill{
	name = "#LuaMieji" ,
	pattern = "SingleTargetTrick|black" ,
	extra_target_func = function(self, from)
		if (from:hasSkill("LuaMieji")) then
			return 1
		end
		return 0
	end
}
LuaMiejiVS = sgs.CreateZeroCardViewAsSkill{
	name = "LuaMieji" ,
	response_pattern = "@@LuaMieji" ,
	view_as = function()
		return LuaExtraCollateralCard:clone()
	end
}
LuaMieji = sgs.CreateTriggerSkill{
	name = "LuaMieji" ,
	frequency = sgs.Skill_Compulsory ,
	events = {sgs.PreCardUsed} ,
	view_as_skill = LuaMiejiVS ,
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local use = data:toCardUse()
		if (use.card:isBlack() and (use.card:isKindOf("ExNihilo") or use.card:isKindOf("Collateral"))) then
			local targets = sgs.SPlayerList()
			local extra = nil
			if (use.card:isKindOf("ExNihilo")) then
				for _, p in sgs.qlist(room:getAlivePlayers()) do
					if (not use.to:contains(p)) and (not room:isProhibited(player, p, use.card)) then
						targets:append(p)
					end
				end
				if (targets:isEmpty()) then return false end
				extra = room:askForPlayerChosen(player, targets, self:objectName(), "@qiaoshui-add:::" + use.card:objectName(), true)
			elseif (use.card:isKindOf("Collateral")) then
				for _, p in sgs.qlist(room:getAlivePlayers()) do
					if (use.to:contains(p) or room:isProhibited(player, p, use.card)) then continue end
					if use.card:targetFilter(sgs.PlayerList(), p, player) then
						targets:append(p)
					end
				end
				if (targets:isEmpty()) then return false end
				local tos = {}
				for _, t in sgs.qlist(use.to) do
					table.insert(tos, t:objectName())
				end
				room:setPlayerProperty(player, "extra_collateral", sgs.QVariant(use.card:toString()))
				room:setPlayerProperty(player, "extra_collateral_current_targets", sgs.QVariant(table.concat(tos, "+")))
				local used = room:askForUseCard(player, "@@LuaMieji", "@qiaoshui-add:::collateral")
				room:setPlayerProperty(player, "extra_collateral", sgs.QVariant(""))
				room:setPlayerProperty(player, "extra_collateral_current_targets", sgs.QVariant("+"))
				if not used then return false end
				for _, p in sgs.qlist(room:getOtherPlayers(player)) do
					if p:hasFlag("ExtraCollateralTarget") then
						p:setFlags("-ExtraColllateralTarget")
						extra = p
						break
					end
				end
			end
			if extra == nil then return false end
			use.to:append(extra)
			room:sortByActionOrder(use.to)
			data:setValue(use)
		end
		return false
	end
}
--[[
	技能名：名士（锁定技）（0224及以前版）
	相关武将：国战·孔融
	描述：每当你受到伤害时，若伤害来源有手牌，需展示所有手牌，否则此伤害-1。
	引用：LuaXMingshi
	状态：0224验证通过
]]--
LuaXMingshi = sgs.CreateTriggerSkill{
	name = "LuaXMingshi",
	frequency = sgs.Skill_Compulsory,
	events = {sgs.DamageInflicted},
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local damage = data:toDamage()
		local source = damage.from
		if source then
			local choice
			if not source:isKongcheng() then
				choice = room:askForChoice(source, self:objectName(), "yes+no", data)
			else
				choice = "yes"
			end
			if choice == "no" then
				damage.damage = damage.damage - 1
				if damage.damage < 1 then
					return true
				end
				data:setValue(damage)
			else
				room:showAllCards(source)
			end
		end
		return false
	end
}
--[[
	技能名：名士（锁定技）（0610版）
	相关武将：国战·孔融
	描述：每当你受到伤害时，若伤害来源装备区的牌数不大于你的装备区的牌数，此伤害-1。
	引用：
	状态：
]]--
--[[
	技能名：明策
	相关武将：一将成名·陈宫
	描述：出牌阶段限一次，你可以将一张装备牌或【杀】交给一名其他角色，该角色需视为对其攻击范围内你选择的另一名角色使用一张【杀】，若其未如此做或其攻击范围内没有使用【杀】的目标，其摸一张牌。
	引用：LuaMingce
	状态：0610验证通过
]]--
LuaMingceCard = sgs.CreateSkillCard{
	name = "LuaMingceCard" ,
	will_throw = false ,
	handling_method = sgs.Card_MethodNone ,
	on_effect = function(self, effect)
		local room = effect.to:getRoom()
		local targets = sgs.SPlayerList()
		if sgs.Slash_IsAvailable(effect.to) then
			for _, p in sgs.qlist(room:getOtherPlayers(effect.to)) do
				if effect.to:canSlash(p) then
					targets:append(p)
				end
			end
		end
		local target
		local choicelist = {"draw"}
		if (not targets:isEmpty()) and effect.from:isAlive() then
			target = room:askForPlayerChosen(effect.from, targets, self:objectName(), "@dummy-slash2:" .. effect.to:objectName())
			target:setFlags("LuaMingceTarget")
			table.insert(choicelist, "use")
		end
		effect.to:obtainCard(self)
		local choice = room:askForChoice(effect.to, self:objectName(), table.concat(choicelist, "+"))
		if target and target:hasFlag("LuaMingceTarget") then target:setFlags("-LuaMingceTarget") end
		if choice == "use" then
			if effect.to:canSlash(target, nil, false) then
				local slash = sgs.Sanguosha:cloneCard("slash", sgs.Card_NoSuit, 0)
				slash:setSkillName("_LuaMingce")
				room:useCard(sgs.CardUseStruct(slash, effect.to, target), false)
			end
		elseif choice == "draw" then
			effect.to:drawCards(1)
		end
	end
}
LuaMingce = sgs.CreateViewAsSkill{
	name = "LuaMingce" ,
	n = 1 ,
	view_filter = function(self, selected, to_select)
		return to_select:isKindOf("EquipCard") or to_select:isKindOf("Slash")
	end ,
	view_as = function(self, cards)
		if #cards ~= 1 then return nil end
		local mingcecard = LuaMingceCard:clone()
		mingcecard:addSubcard(cards[1])
		return mingcecard
	end ,
	enabled_at_play = function(self, player)
		return not player:hasUsed("#LuaMingceCard")
	end
}
--[[
	技能名：明鉴
	相关武将：贴纸·辛宪英
	描述：任一角色回合开始时，你可以立即优先执行下列两项中的一项：
		1.弃置一张牌，跳过该角色的判定阶段。
		2.竖置一张手牌于其武将牌上，该角色本回合内的判定均不受任何人物技能影响，该角色回合结束后将该牌置入弃牌堆。
	引用：LuaMingjian、luaXMingjianStop
	状态：验证通过
]]--
LuaXMingjianCard = sgs.CreateSkillCard{
	name = "LuaXMingjianCard",
	target_fixed = true,
	will_throw = false,
	on_use = function(self, room, source, targets)
		local target = room:getCurrent()
		target:addToPile("jian", self)
	end
}
LuaXMingjianVS = sgs.CreateViewAsSkill{
	name = "LuaXMingjian",
	n = 1,
	view_filter = function(self, selected, to_select)
		return not to_select:isEquipped()
	end,
	view_as = function(self, cards)
		if #cards == 1 then
			local card = cards[1]
			local vs_card = LuaXMingjianCard:clone()
			vs_card:setSkillName(self:objectName())
			vs_card:addSubcard(card)
			return vs_card
		end
	end,
	enabled_at_play=function()
		return false
	end,
	enabled_at_response = function(self,player,pattern)
		return pattern == "@@LuaXMingjian"
	end
}
LuaXMingjian = sgs.CreateTriggerSkill{
	name = "LuaXMingjian",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.EventPhaseStart},
	view_as_skill = LuaXMingjianVS,
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local phase = player:getPhase()
		local xin = room:findPlayerBySkillName(self:objectName())
		if phase == sgs.Player_NotActive then
			player:removePileByName("jian")
			return
		end
		if xin then
			if phase == sgs.Player_RoundStart then
				if not xin:isNude() then
					local string = not player:getJudgingArea():isEmpty() and "ming+jian+cancel" or "jian+cancel"
					local choice = room:askForChoice(xin, self:objectName(), string)
					if  choice == "cancel" then
						return false
					elseif choice == "ming" then
						local data = sgs.QVariant()
						data:setValue(player)
						local card = room:askForCard(xin, ".|.|.|.|.", "@mingjiana", data, "LuaXMingjian")
						if card then
							player:skip(sgs.Player_Judge)
						end
					elseif choice == "jian"  then
						room:askForUseCard(xin, "@@LuaXMingjian", "@mingjianb", -1, sgs.Card_MethodNone)
					end
				end
			end
		end
		return false
	end,
	can_trigger = function(self, target)
		return target
	end
}
luaXMingjianStop = sgs.CreateTriggerSkill{
	name = "#luaXMingjianStop",
	priority = 5,
	events = sgs.AskForRetrial ,
	on_trigger = function(self, event, player, data)
		local judge = data:toJudge()
		local jianpile = judge.who:getPile("jian")
		return not jianpile:isEmpty()
	end,
	can_trigger = function()
		return true
	end
}
--[[
	技能名：明哲
	相关武将：新3V3·诸葛瑾
	描述：你的回合外，当你因使用、打出或弃置而失去一张红色牌时，你可以摸一张牌。
	引用：LuaXMingzhe
	状态：通过
]]--
LuaXMingzhe=sgs.CreateTriggerSkill{
	name="LuaXMingzhe",
	frequency=sgs.Skill_Frequent,
	events={sgs.BeforeCardsMove, sgs.CardsMoveOneTime},
	on_trigger=function(self, event, player, data)
		local room = player:getRoom()
		if (player:getPhase() ~= sgs.Player_NotActive) then
			return
		end
		local move = data:toMoveOneTime()
		if move.from:objectName() ~= player:objectName() then
			return
		end
		if event == sgs.BeforeCardsMove then
			local reason = move.reason.m_reason
			local reasonx = bit32.band(reason, sgs.CardMoveReason_S_MASK_BASIC_REASON)
			local Yes = reasonx == sgs.CardMoveReason_S_REASON_DISCARD
			or reasonx == sgs.CardMoveReason_S_REASON_USE or reasonx == sgs.CardMoveReason_S_REASON_RESPONSE
			if Yes then
				local card
				local i = 0
				for _,id in sgs.qlist(move.card_ids) do
					card = sgs.Sanguosha:getCard(id)
					if move.from_places:at(i) == sgs.Player_PlaceHand
						or move.from_places:at(i) == sgs.Player_PlaceEquip then
						if card and room:getCardOwner(id):getSeat() == player:getSeat() then
							player:addMark(self:objectName())
						end
					end
					i = i + 1
				end
			end
		else
			for i = 0, player:getMark(self:objectName()) - 1 do
				if player:askForSkillInvoke(self:objectName(),data) then
					player:drawCards(1)
				else
					break
				end
			end
			player:setMark(self:objectName(), 0)
		end
	end,
}
--[[
	技能名：谋断（转化技）
	相关武将：☆SP·吕蒙
	描述：通常状态下，你拥有标记“武”并拥有技能“激昂”和“谦逊”。当你的手牌数为2张或以下时，你须将你的标记翻面为“文”，将该两项技能转化为“英姿”和“克己”。任一角色的回合开始前，你可弃一张牌将标记翻回。
	引用：LuaMouduanStart、LuaMouduan、LuaMouduanClear
	状态：1217验证通过
]]--
LuaMouduanStart = sgs.CreateTriggerSkill{
	name = "#LuaMouduan-start" ,
	events = {sgs.GameStart} ,
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		player:gainMark("@wu")
		room:acquireSkill(player, "jiang")
		room:acquireSkill(player, "qianxun")
	end ,
}
LuaMouduan = sgs.CreateTriggerSkill{
	name = "LuaMouduan" ,
	events = {sgs.EventPhaseStart, sgs.CardsMoveOneTime} ,
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local lvmeng = room:findPlayerBySkillName(self:objectName())
		if event == sgs.CardsMoveOneTime then
			local move = data:toMoveOneTime()
			if move.from and (move.from:objectName() == player:objectName()) and (player and player:isAlive() and player:hasSkill(self:objectName()))
					and (player:getMark("@wu") > 0) and (player:getHandcardNum() <= 2) then
				player:loseMark("@wu")
				player:gainMark("@wen")
				room:handleAcquireDetachSkills(player, "-jiang|-qianxun|yingzi|keji")
			end
		elseif (player:getPhase() == sgs.Player_RoundStart) and lvmeng and (lvmeng:getMark("@wen") > 0)
				and lvmeng:canDiscard(lvmeng, "he") then
			if room:askForCard(lvmeng, "..", "@LuaMouduan", sgs.QVariant(), self:objectName()) then
				if lvmeng:getHandcardNum() > 2 then
					lvmeng:loseMark("@wen")
					lvmeng:gainMark("@wu")
					room:handleAcquireDetachSkills(lvmeng, "-yingzi|-keji|jiang|qianxun")
				end
			end
		end
		return false
	end ,
	can_trigger = function(self, target)
		return target
	end
}
LuaMouduanClear = sgs.CreateTriggerSkill{
	name = "#LuaMouduan-clear" ,
	events = {sgs.EventLoseSkill} ,
	on_trigger = function(self, event, player, data)
		if data:toString() == "LuaMouduan" then
			local room = player:getRoom()
			if player:getMark("@wu") > 0 then
				player:loseMark("@wu")
				room:detachSkillFromPlayer(player, "jiang")
				room:detachSkillFromPlayer(player, "qianxun")
			elseif player:getMark("@wen") > 0 then
				player:loseMark("@wen")
				room:detachSkillFromPlayer(player, "yingzi")
				room:detachSkillFormPlayer(player, "keji")
			end
		end
		return false
	end ,
	can_trigger = function(self, target)
		return target
	end
}
--[[
	技能名：谋溃
	相关武将：铜雀台·穆顺、SP·伏完
	描述：当你使用【杀】指定一名角色为目标后，你可以选择一项：摸一张牌，或弃置其一张牌。若如此做，此【杀】被【闪】抵消时，该角色弃置你的一张牌。
	引用：LuaXMoukui
	状态：验证通过
]]--
LuaXMoukui = sgs.CreateTriggerSkill{
	name = "LuaXMoukui",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.TargetConfirmed, sgs.SlashMissed, sgs.CardFinished},
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		if event == sgs.TargetConfirmed then
			local use = data:toCardUse()
			if player:objectName() == use.from:objectName() then
				if player:isAlive() and player:hasSkill(self:objectName()) then
					local slash = use.card
					if slash:isKindOf("Slash") then
						for _,p in sgs.qlist(use.to) do
							local ai_data = sgs.QVariant()
							ai_data:setValue(p)
							if player:askForSkillInvoke(self:objectName(), ai_data) then
								local choice
								if p:isNude() then
									choice = "draw"
								else
									choice = room:askForChoice(player, self:objectName(), "draw+discard")
								end
								if choice == "draw" then
									player:drawCards(1)
								else
									local disc = room:askForCardChosen(player, p, "he", self:objectName())
									room:throwCard(disc, p, player)
								end
								local mark = string.format("%s%s", self:objectName(), slash:getEffectIdString())
								local count = p:getMark(mark) + 1
								room:setPlayerMark(p, mark,	count)
							end
						end
					end
				end
			end
		elseif event == sgs.SlashMissed then
			local effect = data:toSlashEffect()
			local dest = effect.to
			local source = effect.from
			local slash = effect.slash
			local mark = string.format("%s%s", self:objectName(), slash:getEffectIdString())
			if dest:getMark(mark) > 0 then
				if source:isAlive() and dest:isAlive() and not source:isNude() then
					local disc = room:askForCardChosen(dest, source, "he", self:objectName())
					room:throwCard(disc, source, dest)
					local count = dest:getMark(mark) - 1
					room:setPlayerMark(dest, mark, count)
				end
			end
		elseif event == sgs.CardFinished then
			local use = data:toCardUse()
			if use.card:isKindOf("Slash") then
				local players = room:getAllPlayers()
				for _,p in sgs.qlist(players) do
					local mark = string.format("%s%s", self:objectName(), use.card:getEffectIdString())
					room:setPlayerMark(p, mark, 0)
				end
			end
		end
		return false
	end,
	can_trigger = function(self, target)
		return target
	end
}
--[[
	技能名：谋诛
	相关武将：1v1·何进
	描述：出牌阶段限一次，你可以令对手交给你一张手牌，然后若你的手牌数大于对手的手牌数，对手选择一项：视为对你使用一张【杀】，或视为对你使用一张【决斗】。
]]--
