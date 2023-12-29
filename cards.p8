pico-8 cartridge // http://www.pico-8.com
version 38
__lua__
-- klondike
-- by lark

-- v1.1
-- dec 28 2023
-- save record,resign,undo

-- v1.0
-- feb 16-apr 20 2020
-- sep 2022

played = 0
won = 0
if cartdata("klondike_lark") then
 played = dget(0)
 won = dget(1)
else
	dset(0,0)
	dset(1,0)
end

function reset_record()
 played = 0
 won = 0
 dset(0,0)
 dset(1,0)
end

function record_win()
 played += 1
 won += 1
 dset(0,played)
 dset(1,won)
end

function record_loss()
 played += 1
 dset(0,played)
 dset(1,won)
end

-- make dark green transparent
palt(3, true)
palt(0, false)

-- sound map
--  1 = source select left a
--  2 = source select left b
--  3 = source select right a
--  4 = source select right b
--  5 = select source
--  6 = deselect source
--  7 = draw from deck
--  8 = replenesh deck
--  9 = target select left a
-- 10 = target select left b
-- 11 = target select right a
-- 12 = target select right b
-- 13 = target stack
-- 14 = target endzone
-- 15 = source select up a
-- 16 = source select up b
-- 17 = source select down a
-- 18 = source select down b
-- 19 = victory (also music 0)
-- 20 = resign
-- 21 = draw from deck 2

function play_source_move()
 v = flr(rnd(4))+1
 sfx(v)
end

function play_source_move_vert()
 v = flr(rnd(4))+15
 sfx(v)
end

function play_target_move()
 v = flr(rnd(4))+9
 sfx(v)
end

function play_deck_draw()
 if flr(rnd(2)) == 0 then
  sfx(7)
 else
  sfx(21)
 end
end

-- put 1 or 3 draw in menu
draw_size = 1
function setup_menu()
 if 3 == draw_size then
		menuitem(1, "set draw to 1", 
		 function() 
		  draw_size = 1 
		  setup_menu() 
		 end)
 else
		menuitem(1, "set draw to 3", 
		 function() 
		  draw_size = 3 
		  setup_menu() 
		 end) 
 end
end
setup_menu()

function resign()
 -- were any moves made?
 -- todo check the undo stack
 record_loss()
 sfx(20) -- resign
 reshuffle()
end

-- put reset game in menu
menuitem(2, "reshuffle",
 function() resign() end)

-- put reset score in menu
menuitem(3, "reset score",
 function() reset_record() end)

status = ""

stacks = {}
deck = {}
endzones = {}
face_up = {}

-- select state
-- 1 == selecting source card
-- 2 == selecting target card
s_state = 1
-- selection 1 (source)
s_1 = "s4"
s_y_index = 4  -- y in stack
-- selection 2 (destination)
-- in s_state = 2,
-- ⬅️➡️ cycles through these
s_2 = nil

function shuffle(t)
  -- do a fisher-yates shuffle
  for i = #t, 1, -1 do
    local j = flr(rnd(i)) + 1
    t[i], t[j] = t[j], t[i]
  end
end

function flip_deck(s,t)
 while #s != 0 do
  c = pop(s)
  add(t,c)
 end
end

function make_deck()
 d = {}
 for s=0,3 do
  for r=0,12 do
   add(d,{s=s,r=r,u=false})
  end
 end
 shuffle(d)
 return d
end

-- true if deck depleted and
-- cant be replenished
function deck_empty()
 return #deck == 0 and
        #face_up == 0
end

function pop(t)
 v = t[1]
 del(t,v)
 return v
end

-- returns index of item or 0
function find(t, item)
 index = 0
 for i in all(t) do
  index += 1
  if i == item then
   return index
  end
 end
 return 0
end

-- rtn copy of table, reversed
function reverse(t)
 r = {}
 for i=#t,1,-1 do
  add(r,t[i])
 end
 return r
end

-- set up nested lists, 7, each
-- with 1..n cards
function setup_stacks()
 new_stacks = {}
 for s=1,7 do
  stack = {}
  add(new_stacks,stack)
  for t=1,s do
   c = pop(deck)
   add(stack,c)
  end
 end
 return new_stacks
end

-- draw stack of index 's'
function draw_stack(s)
 n = "s"..tostr(s)
 x = 2+(s-1)*18
 y_base = 22
 y_step = 8
 count = 1
 y = y_base+count*y_step
 if #(stacks[s]) == 0 then
  draw_no_card(x,y)
  if 2 == s_state then
   if s_2 == n then
    draw_select_2(x,y)
   elseif dest_selectable(n) then
    draw_select_3(x,y)   
   end
  end
 else
  -- draw stack's shadow
  h = 8*(#stacks[s]-1)+24
  shadow_line(x+2,y+h,x+14,y+h)
  shadow_line(x+15,y+h-1,
              x+15,y+h-1)
  shadow_line(x+16,y+2,
              x+16,y+h-2)
 end
 for c in all(stacks[s]) do
  if count == #stacks[s] then 
   c.u = true
  end
  y = y_base+count*y_step
  if c.u then
   draw_card(x,y,c.s,c.r,c.u,
             false)
  else
   draw_under_card(x,y)
  end  
  if #(stacks[s]) == count and
     s_state == 2 then
   if s_2 == n then  
    draw_select_2(x,y)
   elseif dest_selectable(n) then
    draw_select_3(x,y)   
   end
  end
  count += 1
 end

 if s_1 == n then
  if s_y_index == 0 then
   offset = 1
  else 
   offset = s_y_index
  end
  y = y_base+offset*y_step
  c = stacks[s][offset]
  if c!=nil then
   draw_card(x,y,c.s,c.r,c.u,false)
  end
  draw_select_1(x,y) 
 end	
end

-- replace pixel at x,y with
-- a shadow value
function make_shadow(x,y)
 c = pget(x,y)
 if 7 == c then -- white
  pset(x,y,6) -- light grey
 elseif 0 == c then -- black
  -- nop
 elseif 8 == c then -- red
  pset(x,y,2) -- purple
 elseif 12 == c then -- lt blue
  pset(x,y,2) -- purple
 elseif 13 == c then -- grey
  pset(x,y,5) -- dark grey
 elseif 6 == c then -- lt grey
  pset(x,y,5) -- dark grey
 elseif 3 == c then -- dk green
  pset(x,y,5) -- dark grey
 elseif 14 == c then -- pink
  pset(x,y,2) -- purple
 elseif 7 == c then -- white
  pset(x,y,6) -- lt grey
 elseif 3 == c then -- dk green
  pset(x,y,5) -- dark grey
 end
end

-- draw a line of shadow
function shadow_line(x,y,x2,y2)
 for a=x,x2 do
  for b=y,y2 do
   make_shadow(a,b)
  end
 end
end

function _draw_sel_shadow(x,y)
 for i=0,21 do
  make_shadow(x+1,y+1+i)
 end
 for i=0,12 do
  make_shadow(x+2+i,y+1)
 end
 for i=0,15 do
  make_shadow(x+1+i,y+25)
 end
 for i=0,22 do
  make_shadow(x+17,y+1+i)
 end 
end

function draw_select_1(x,y)
 sspr(75,2,19,27,x-1,y-1)
 _draw_sel_shadow(x,y)
end

function draw_select_2(x,y)
 sspr(98,2,19,27,x-1,y-1)
 _draw_sel_shadow(x,y)
end

function draw_select_3(x,y)
 sspr(66,98,19,27,x-1,y-1)
 _draw_sel_shadow(x,y)
end

-- outline of a card
function draw_no_card(x,y)
 sspr(56,0,16,24,x,y)
end

-- shadow around a card
function draw_shadow(x,y)
 line(x+2,y+24,x+14,y+24,5)
 line(x+15,y+23,x+15,y+23,5)
 line(x+16,y+2,x+16,y+22,5)
end

-- draw end collections
function draw_endzone(e)
 n = "e"..e
 x_step = 18
 y = 4
 x = 2+(e-1)*x_step
 endzone = endzones[e]
 c = endzone[#endzone]
 if c == nil then
  draw_no_card(x,y)
 else 
  c.u = true
  draw_shadow(x,y)
  draw_card(x,y,c.s,c.r,c.u,false)
 end
 if 2 == s_state then
  if s_2 == n then
		 draw_select_2(x,y)
		elseif dest_selectable(n) then
		 draw_select_3(x,y)
  end
 end
end

-- draw the top 3 face up cards
function draw_face_up()
 x_step = 9
 x = 74
 y = 4
 if 1 == draw_size then
  if #face_up != 0 then
   c = face_up[#face_up]
   draw_shadow(x+x_step*2,y)
   draw_card(x+x_step*2,y,c.s,c.r,c.u,false)
   if "face_up" == s_1 then
    draw_select_1(x+x_step*2,y)
   end
  else
   draw_no_card(x+x_step*2,y)
  end 
 else
  sspr(88,96,34,24,x,y)
  if #face_up > 2 then
   c = face_up[#face_up-2]
   draw_card(x, y, c.s,c.r,
             c.u,true)
  end
  if #face_up > 1 then
   c = face_up[#face_up-1]
   draw_card(x+x_step, y, c.s,c.r,
             c.u,true)
  end
  if #face_up != 0 then
   c = face_up[#face_up]
   draw_card(x+x_step*2,y,c.s,c.r,c.u,false)
   if "face_up" == s_1 then
    draw_select_1(x+x_step*2,y)
   end
  end
 end
end

-- draw up to three cards off
-- the deck and into face_up
function deck_draw()
 for x=1,draw_size do
  if #deck != 0 then
   c = pop(deck)
   c.u = true
   add(face_up,c)
  end
 end
end

-- draw the deck we draw from
function draw_deck()
 x = 110
 y = 4
 if #deck == 0 then
  draw_no_card(x,y)
 else
  draw_shadow(x,y)
  draw_card(x,y,0,0,false)
 end
 if s_1 == "deck" then
  draw_select_1(x,y)
 end
end

-- suits hearts: 0, diamonds: 1
--       clubs: 2, spades: 3
-- ranks a: 0, 2:1,... 10: 9,
--       j: 10, q: 11, k: 12

function rank_to_text(r)
 if r == 0 then
  return " a"
 elseif r == 1 then
  return " 2"
 elseif r == 2 then
  return " 3"
 elseif r == 3 then
  return " 4"
 elseif r == 4 then
  return " 5"
 elseif r == 5 then
  return " 6"
 elseif r == 6 then
  return " 7"
 elseif r == 7 then
  return " 8"
 elseif r == 8 then
  return " 9"
 elseif r == 9 then
  return "10"
 elseif r == 10 then
  return " j"
 elseif r == 11 then
  return " q"
 elseif r == 12 then
  return " k"
 end
 return " x"
end

-- draw_sm_pip
-- s (suit),
-- x,y (coords)
-- f (flip) true to flip yaxis
function draw_sm_pip(s,x,y,f)
 -- these shift to the right
 -- one to line up with full
 -- sized pip
 sspr(s*4,0,4,4,x+1,y,4,4,
      false,f)
end

-- draw_pip
-- s (suit),
-- x,y (coords)
-- f (flip) true to flip yaxis
function draw_pip(s,x,y,f)
 if s < 2 then
  sspr(s*5,4,5,5,x,y,5,5,
       false,f)
 else
  sspr((s-2)*5,9,5,5,x,y,5,5,
       false,f)
 end
end

-- draw top of card back with
-- a tiny bit of shadow
function draw_under_card(x,y)
 sspr(96,64,16,9,x,y)
end

-- draw_card
-- x,y (coords),
-- s (suit), r (rank),
-- u (false if back showing)
-- side_text true for side rank
function draw_card(x,y,s,r,u,
                   side_text)
 if not u then
  -- card back
  sspr(112,64,16,24,x,y)
  return
 end
 -- card front
 sspr(24,0,16,24,x,y)
 draw_pip(s,x+1,y+1,false)
 if s == 0 or s == 1 then
  c = 8
 else 
  c = 0
 end
 if side_text then
  if r == 9 then
   print("10",x+1,y+7,c)  
  else
 		print(rank_to_text(r), 
         x-1,y+7,c)
  end
  return
 else
 	print(rank_to_text(r), 
        x+7,y+1,c)
 end
 -- card graphic
 if r == 0 then
  if s == 0 then -- aces
   sspr(0,64,10,10,x+3,y+10)  
  elseif s == 1 then
   sspr(0,74,10,11,x+3,y+9)
  elseif s == 2 then
   sspr(9,64,10,10,x+3,y+9)
  elseif s == 3 then
   sspr(18,64,10,10,x+3,y+9)
  end
 elseif r == 1 then
  draw_pip(s,x+6,y+8,false)
  draw_pip(s,x+6,y+15,true)
 elseif r == 2 then
  draw_sm_pip(s,x+6,y+7,false)
  draw_sm_pip(s,x+6,y+12,false)
  draw_sm_pip(s,x+6,y+17,true)
 elseif r == 3 then
  draw_pip(s,x+2,y+8,false)
  draw_pip(s,x+2,y+15,true)
  draw_pip(s,x+9,y+8,false)
  draw_pip(s,x+9,y+15,true) 
 elseif r == 4 then
  draw_sm_pip(s,x+3,y+8,false)
  draw_sm_pip(s,x+3,y+16,true)
  draw_sm_pip(s,x+6,y+12,false)
  draw_sm_pip(s,x+9,y+8,false)
  draw_sm_pip(s,x+9,y+16,true) 
 elseif r == 5 then
  draw_sm_pip(s,x+3,y+8,false)
  draw_sm_pip(s,x+3,y+13,false)
  draw_sm_pip(s,x+3,y+18,true)
  draw_sm_pip(s,x+9,y+8,false)
  draw_sm_pip(s,x+9,y+13,false)
  draw_sm_pip(s,x+9,y+18,true)
 elseif r == 6 then
  draw_sm_pip(s,x+3,y+7,false)
  draw_sm_pip(s,x+9,y+7,false)
  
  draw_sm_pip(s,x+6,y+10,false)
  
  draw_sm_pip(s,x+3,y+13,false)
  draw_sm_pip(s,x+9,y+13,false)

  draw_sm_pip(s,x+3,y+17,true)
  draw_sm_pip(s,x+9,y+17,true) 
 elseif r == 7 then
  draw_sm_pip(s,x+3,y+7,false)
  draw_sm_pip(s,x+9,y+7,false)

  draw_sm_pip(s,x+6,y+10,false)

  draw_sm_pip(s,x+3,y+13,false)
  draw_sm_pip(s,x+9,y+13,false)

  draw_sm_pip(s,x+6,y+16,false)

  draw_sm_pip(s,x+3,y+18,true)
  draw_sm_pip(s,x+9,y+18,true) 
 elseif r == 8 then
  draw_sm_pip(s,x+3,y+7,false)
  draw_sm_pip(s,x+9,y+7,false)

  draw_sm_pip(s,x+6,y+9,false)

  draw_sm_pip(s,x+3,y+11,false)
  draw_sm_pip(s,x+9,y+11,false)

  draw_sm_pip(s,x+3,y+14,true)
  draw_sm_pip(s,x+9,y+14,true)

  draw_sm_pip(s,x+3,y+18,true)
  draw_sm_pip(s,x+9,y+18,true)
 elseif r == 9 then
  draw_sm_pip(s,x+3,y+7,false)
  draw_sm_pip(s,x+9,y+7,false)

  draw_sm_pip(s,x+6,y+9,false)

  draw_sm_pip(s,x+3,y+11,false)
  draw_sm_pip(s,x+9,y+11,false)

  draw_sm_pip(s,x+3,y+14,true)
  draw_sm_pip(s,x+9,y+14,true)

  draw_sm_pip(s,x+6,y+16,true)

  draw_sm_pip(s,x+3,y+18,true)
  draw_sm_pip(s,x+9,y+18,true)
 elseif r == 10 then -- jack
  if s == 0 then 
   sspr(3,96,14,15,x+4,y+8)
  elseif s == 1 then
   sspr(20,97,11,15,x+3,y+9)
  elseif s == 2 then
   sspr(36,97,11,15,x+3,y+9)     
  elseif s == 3 then
   sspr(52,97,11,15,x+3,y+9)
  end 
 
 elseif r == 11 then -- queen
  if s == 0 then 
   sspr(36,81,14,15,x+4,y+8)
  elseif s == 1 then
   sspr(51,81,11,15,x+5,y+8)
  elseif s == 2 then
   sspr(68,81,11,15,x+3,y+9)     
  elseif s == 3 then
   sspr(84,81,11,15,x+3,y+9)
  end 
 elseif r == 12 then -- king
  if s == 0 then
   sspr(35,65,11,15,x+3,y+9)
  elseif s == 1 then
   sspr(51,64,12,16,x+3,y+8)
  elseif s == 2 then
   sspr(67,65,11,15,x+2,y+9)     
  elseif s == 3 then
   sspr(83,65,12,15,x+3,y+9)
  end
 end
end

function draw_pico8(x,y)
 sspr(93,32,35,12,x,y)
end

function draw_logo()
 sspr(0,32,90,32,2,94)
 --draw_pico8(14,92)
end

-- red
-- true if card is red
function red(c)
 return c.s == 0 or c.s == 1
end

-- can_stack
-- true if card 's' can be
-- placed on card 't'
function can_stack(s,t)
 if (s == nil) return false
 if (t == nil) return s.r == 12
	return red(s) != red(t) and 
	       t.r-1 == s.r
end

-- e_can_stack
-- true if card 's' can be
-- on endzone 1-4
function e_can_stack(s,e)
 if (s == nil) return false
 if (s.s != e - 1) return false
 z = endzones[e] --zone
 l = z[#z] --last
 if l == nil then
  return s.r == 0
 else
  return s.r - 1 == l.r
 end
end

-- remove a card from a stack
-- and return it, else nil
function pop_next_anim_card()
 candidates = {}
 for i=1,7 do
  if #stacks[i] > 0 then
   add(candidates, "stack")
   break
  end
 end
 if #deck > 0 then
  add(candidates, "deck")
 end
 if #face_up > 0 then
  add(candidates, "face_up")
 end
  
 if #candidates == 0 then
  return nil
 end

 next_source = rnd(candidates)
 
 c = {}
 if next_source == "stack" then
  -- get card from longest stack  
	 max_len = 0
	 max_i = nil
	 stack_count = 0
	 for i=1,7 do
	  stack_count += #stacks[i]
	  if #stacks[i] > max_len then
	   max_len = #stacks[i]
	   max_i = i
	  end
	 end
  s = stacks[max_i]
  found_card = s[#s]
  -- start coordinates
  c.x = 2+(max_i-1)*x_step
  y_base = 22
  y_step = 8
  c.y = y_base+#s*y_step
  deli(s,#s)
 elseif next_source == "deck" then
  -- anim card from deck
  found_card = deck[#deck]
  c.x = 110
  c.y = 4
  deli(deck,#deck)
 elseif next_source == "face_up" then
  found_card = face_up[#face_up]
  c.x = 92
  c.y = 4
  deli(face_up,#face_up)
 end	  

 x_step = 18 -- endzone spacing
 -- endzone coordinates
 target_x = 2+(found_card.s)*x_step
 target_y = 4
 -- normalize speed
 dx = (target_x - c.x)
 dy = (target_y - c.y)
 h = sqrt(dx^2+dy^2)
 
 -- later cards start faster
 card_count = 0
 for i=1,7 do
  card_count += #stacks[i]
 end
 card_count += #deck
 card_count += #face_up
 speed = .5 + 14/card_count

	return {x=c.x,y=c.y,
	        target_x=target_x,
	        target_y=target_y,
	      	 speed=speed,
         dx=dx/h,
         dy=dy/h,
         s=found_card.s,
         r=found_card.r,
         u=false}
end

function move_card(c)
 c_next_x = c.x + c.speed * c.dx
 c_next_y = c.y + c.speed * c.dy

 x_done = 
  (c.x <= c.target_x and
   c.target_x <= c_next_x) or
  (c.x >= c.target_x and
   c.target_x >= c_next_x)
 if x_done then
  c.x = c.target_x
 end
  
 y_done = 
  (c.y <= c.target_y and
   c.target_y <= c_next_y) or
  (c.y >= c.target_y and
   c.target_y >= c_next_y)
 if y_done then
  c.y = c.target_y
 end   
 
 if x_done and y_done then
  return false
 else
  c.x = c_next_x
  c.y = c_next_y
  c.speed += .7
  return true
 end
end

-- source selections in order
source_names = {"s1","s2","s3",
 "s4","s5","s6","s7","face_up",
 "deck"}

-- dest selections in order
dest_names = {"s1","s2","s3",
 "s4","s5","s6","s7","e1","e2",
 "e3","e4"}

-- the targets in order starting
-- from current_target and wrap
-- around
-- d == direction, 
--      0==left, 1==right
function sources(d)
 return _t_order(source_names,
                 s_1,d)
end

function targets_order_2(d)
 return _t_order(dest_names,
                 s_2,d)
end

function _t_order(targets,
                  current,d)
 if 0 == d then
  targets = reverse(targets)
 end
 index = find(targets, current)
 if 0 == index then
  return targets
 end
 ret_targets = {}
 if index != #targets then
  for x=index+1,#targets do
   add(ret_targets,targets[x])
  end
 end
 for x=1,index do
  add(ret_targets,targets[x])
 end
 return ret_targets
end

-- true if t is selectable
function source_selectable(t)
 if t == nil then
  return false
 end
 if "deck" == t then
  return not deck_empty()
 elseif "face_up" == t then
  return 0 != #face_up
 else
  -- convert, ex "s4" to num 4 
  i = tonum(sub(t,2))
  return 0 != #stacks[i]
 end
end

-- return card selected as src
function source_card()
 if "deck" == s_1 then
  return deck[#deck]
 elseif "face_up" == s_1 then
  return face_up[#face_up]
 else
  return get_stack_card(s_1,
                     s_y_index)
 end
end

-- get the card from stack with
-- name == n, at y index i
function get_stack_card(n,i)
	return get_stack(n)[i]
end

-- true if t legal destination
-- for source s_1
function dest_selectable(t)
 if t == nil then
  return false
 end
 c = source_card()
	if is_end(t) then
	 if is_stack(s_1) then
	  s = get_stack(s_1)
	  if s_y_index != #s then
	   return false
	  end
	  i = end_index(t)
 		return e_can_stack(c,i)
	 elseif "face_up" == s_1 then
	  i = end_index(t)
 		return e_can_stack(c,i)	  
	 end
 elseif is_stack(t) then
  s = get_stack_top_card(t)
  return can_stack(c,s)
 end
 return false
end

-- left: d==0, right: d==1
function next_valid_source(d)
 for t in all(sources(d)) do
  if source_selectable(t) then
   return t
  end
 end
end

-- left: d==0, right: d==1
function next_valid_dest(d)
 ts = targets_order_2(d)
 for t in all(ts) do
  if dest_selectable(t) then
   return t
  end
 end
end

-- if an unselected element is
-- selected, select the next
-- selectable element
function fix_invalid_selection()
 if source_selectable(s_1) then
  t = s_1
	else
  t = next_valid_source(1)
 end
 set_source(t)
end

function is_stack(t)
 return sub(t,1,1) == "s"
end

function is_end(t)
 return sub(t,1,1) == "e"
end

function get_stack(t)
 if is_stack(t) then
  i = tonum(sub(t,2))
  return stacks[i]
 end
end

function get_stack_top_card(t)
 s = get_stack(t)
 return s[#s]
end

-- ex: stack_index("s2") => 2
function stack_index(t)
 return tonum(sub(t,2))
end

-- ex: end_index("e2") => 2
function end_index(t)
 return tonum(sub(t,2))
end

function get_end(t)
 return endzones[end_index(t)]
end

function set_source(t)
 s_1 = t
 if is_stack(t) then
  index = stack_index(t)
  s_y_index = #stacks[index]
 end
end

function set_dest(t)
 s_2 = t
end

function move_source(d)
 t = next_valid_source(d)
 if t != s_1 then
  play_source_move()
  set_source(t)
 end
end

function move_dest(d)
 t = next_valid_dest(d)
 if t != s_2 then
  play_target_move()
  set_dest(t)
 end
end

function game_over()
 for stack in all(stacks) do
  for card in all(stack) do
   if not card.u then
    return false
   end
  end
 end
 return true
end

-- setup state for selections
function select_reset()
 s_state = 1
 set_dest(nil)

 if game_over() then
  return
 end

 fix_invalid_selection()
end

function control_player(pl)
 -- state 1: no source card
 -- x: select source card
 if s_state == 1 and 
    btnp(4) then
  if "deck" == s_1 then 
   if #deck == 0 then
    sfx(8) -- replenesh deck
    flip_deck(face_up,deck)
   else
    play_deck_draw()
    deck_draw()
   end
   select_reset()
  elseif next_valid_dest() != nil then
   -- now selecting target
   s_state = 2
   sfx(5) -- select source
   set_dest(next_valid_dest(0))
  end
 --x: select target card
 --z: back to select source card
 elseif s_state == 2 then
  if btnp(5) then
   sfx(6) -- deselect source
   s_state = 1
  end
  if btnp(4) then
   -- execute source-to-dest
   c = source_card()
   if is_end(s_2) then
    sfx(14) -- target endzone
    if is_stack(s_1) then
     s = get_stack(s_1)
     del(s,c)
    elseif "face_up" == s_1 then
     del(face_up,c)
    end
    e = get_end(s_2)
    add(e,c)
    select_reset()
   elseif is_stack(s_2) then
    sfx(13) -- target stack
	   t = get_stack(s_2)
    if "face_up" == s_1 then
     del(face_up,c)
     add(t,c)
    elseif is_stack(s_1) then
     s = get_stack(s_1)
     for i=s_y_index,#s do
      c = s[i]
      add(t,c)
     end
     for i=s_y_index,#s do
	     del(s,s[s_y_index])
				 end
    end
    select_reset()
   end
  
   if game_over() then
    -- this is same as sfx(19)
    music(0) -- victory
    record_win()
    is_ending = true
   end
  end       
 end

 -- 1 == source card select
 if 1 == s_state then
  if btnp(0) then  -- left
   move_source(0) -- 0==left
  elseif btnp(1) then -- right
   move_source(1) -- 1==right
  elseif btnp(2) then -- up
   if is_stack(s_1) and
      s_y_index > 1 and
      get_stack(s_1)[s_y_index-1].u then
    play_source_move_vert()
    s_y_index -= 1
   end
  elseif btnp(3) then
   if is_stack(s_1) and
      s_y_index < #get_stack(s_1) then
    play_source_move_vert()
    s_y_index += 1
   end
  end
 end
 if 2 == s_state then
  if btnp(0) then  -- left
   move_dest(0) -- 0==left
  elseif btnp(1) then -- right
   move_dest(1) -- 1==right
  end
 end
end

-- set up a new game
function reshuffle()
 deck = make_deck()
 stacks = setup_stacks()
 face_up = {}
 endzones = {{},{},{},{}}
 select_reset() 
end
reshuffle()

-- set up a game near the end
function end_test()
 deck = {}
 endzones = {{},{},{},{}}
 -- don't put these in endzones
 reserve = {{0,1,2,3,4,5,6,7,8,9,10,11,12},
            {12},
            {0,1,2,3,4,5,6,7,8,9,10,11,12},
            {12}}
 for s=0,3 do
  for r=0,12 do
   if 0 == find(reserve[s+1],r) then
    add(endzones[s+1],
        {s=s,r=r,u=false})
   end
  end
 end

 stacks = {}
 for s=1,7 do
  stack = {}
  add(stacks,stack)
 end
 stacks[6] = {
  {s=0,r=12,u=true},
  {s=2,r=11,u=true},
  {s=0,r=10,u=true},
  {s=2,r=9,u=true},
  {s=0,r=8,u=true},
  {s=2,r=7,u=true}
 }
 stacks[4] = {
  {s=1,r=12,u=true}
 }
 deck = {
  {s=0,r=6,u=true},
  {s=2,r=5,u=true},
  {s=0,r=4,u=true}
 }
 face_up = {
  {s=0,r=0,u=true},
  {s=2,r=3,u=true},
  {s=0,r=2,u=true},
  {s=2,r=1,u=true}
 }
 
 s_y_index=1
 select_reset() 
end
--end_test()

-- left pad v with p to n chars
function pad(v,n,p)
 local s = ""..v
 local t = #s
 for i=1,n-t do
  s=p..s
 end
 return s
end

-- draw played/wins in lower right
function draw_record()
 s = tostr(played).."/"..tostr(won)
 s = pad(s,7," ")
 print(s,99,121,7)
end

function update_status()
-- c = source_card()
-- status = "s_state: "..s_state.." t1: "..tostr(s_1).." t2: "..tostr(s_2).."\nsc: "..tostr(c.s).." "..tostr(c.r)
end

-- how long to wait before
-- adding next card to victory
-- animation
card_delay = 8
-- when zero, animate next card
card_delay_count = 0
anim_cards = {}
function _update()
 if is_ending then
  if card_delay_count <= 0 then
		 c = pop_next_anim_card()
		 if c != nil then
		  add(anim_cards,c)
		 end
		 card_delay = max(1,card_delay-.65)
		 card_delay_count = card_delay
	 end
	 card_delay_count -= 1
	 done = true
		for c in all(anim_cards) do
   if move_card(c) then
    done = false
   end
		end
		card_count = 0
		for s=1,7 do
		 card_count += #stacks[s]
		end
		card_count += #deck
		card_count += #face_up
  if done and card_count == 0 then
   card_delay = 8
   card_delay_count = 0
   anim_cards = {}
   is_ending = false
   reshuffle()
  end
 else
  control_player(pl)
 end
end

draw_counter = 0
function _draw()
 rectfill(0,0,127,127,3)
 draw_logo()
 draw_record()
 draw_face_up()
 draw_deck()
 update_status()
 print(status,5,110,7)
 for s=1,7 do
  draw_stack(s)
 end
 for e=1,4 do
  draw_endzone(e)
 end

 if is_ending then
  for c in all(anim_cards) do
   draw_card(c.x,c.y,c.s,c.r,
             true,false)
  end
 end
end

__gfx__
83833833303330333333333337777777777777733cccccccccccccc3366666666666666333333333333333333333333333333333333333333333333333333333
8883888300030003333333337777777777777777ccddddddddddddcc633333333333333633333333333333333333333333333333333333333333333333333333
3833383303033033333333337777777777777777cdccccccccccccdc63333333333333363333a4444444444444443333333e2222222222222283333333333333
3333333333333333333333337777777777777777cdcccccccc8cccdc6333333333333336333a4999999999999999433333e28888888888888882333333333333
3838333833333333333333337777777777777777cdccccccc974ccdc6333333333333336333a433333333333333a433333e233333333333333e2333333333333
8888838883333333333333337777777777777777c6cc8ccca777ecdc6333333333333336333a433333333333333a433333e233333333333333e2333333333333
8888888888333333333333337777777777777777c6c974cccb7dccdc6333333333333336333a433333333333333a433333e233333333333333e2333333333333
3888338883333333333333337777777777777777c6a777eccc1cccdc6333333333333336333a433333333333333a433333e233333333333333e2333333333333
3383333833333333333333337777777777777777c6cb7dccccccccdc6333333333333336333a433333333333333a433333e233333333333333e2333333333333
3303330003333333333333337777777777777777c6cc1cccccc8ccdc6333333333333336333a433333333333333a433333e233333333333333e2333333333333
3303303030333333333333337777777777777777cdcccccccc974cdc6333333333333336333a433333333333333a433333e233333333333333e2333333333333
3000300000333333333333337777777777777777cdcccc8cca777edc6333333333333336333a433333333333333a433333e233333333333333e2333333333333
0000003030333333333333337777777777777777c6ccc974ccb7dcdc6333333333333336333a433333333333333a433333e233333333333333e2333333333333
3303333033333333333333337777777777777777cdcca777ecc1ccdc6333333333333336333a433333333333333a433333e233333333333333e2333333333333
3333333333333333333333337777777777777777cdcccb7dccccccdc6333333333333336333a433333333333333a433333e233333333333333e2333333333333
3333333333333333333333337777777777777777cdcccc1cccccccdc6333333333333336333a433333333333333a433333e233333333333333e2333333333333
3333333333333333333333337777777777777777cdcc8cccc7777cdc6333333333333336333a433333333333333a433333e233333333333333e2333333333333
3333333333333333333333337777777777777777cdc974ccc7cc7cdc6333333333333336333a433333333333333a433333e233333333333333e2333333333333
37777773366666633cccccc37777777777777777cda777ec77777c6c6333333333333336333a433333333333333a433333e233333333333333e2333333333333
7777777763333336cccccccc7777777777777777cdcb7dcc77cc7cdc6333333333333336333a433333333333333a433333e233333333333333e2333333333333
7777777763333336ccaaaacc7777777777777777cdcc1ccc77777cdc6333333333333336333a433333333333333a433333e233333333333333e2333333333333
7777777763333336ccaccacc7777777777777777cdccccccccccccdc6333333333333336333a433333333333333a433333e233333333333333e2333333333333
7777777763333336ccaccacc7777777777777777ccddddddddddddcc6333333333333336333a433333333333333a433333e233333333333333e2333333333333
7777777763333336ccaccacc37777777777777733cccccccccccccc33666666666666663333a433333333333333a433333e233333333333333e2333333333333
7777777763333336ccaccacc333333333333333333333333333333333333333333333333333a433333333333333a433333e233333333333333e2333333333333
7777777763333336ccaccacc333333333333333333333333333333333333333333333333333a433333333333333a433333e233333333333333e2333333333333
7777777763333336ccaccacc333333333333333333333333333333333333333333333333333a9444444444444444433333e82222222222222222333333333333
7777777763333336ccaccacc33333333333333333333333333333333333333333333333333339999999999999999233333388888888888888881333333333333
7777777763333336ccaaaacc33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
7777777763333336cccccccc33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
37777773366666633cccccc333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
00003333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333833
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333339733
333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333a777e
3c33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333b7d3
ccc33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333337777377773377733777733333777733133
ccc33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333377377337733773337737733333733733333
ccc333333333333333333333333333333333333333333333c3333333333333333333333333333333333333333333377777337733773337737737737777733333
ccc33333333333333333333333333333333333333333333ccc333333333333333333333333333333333333333333377333337733773337737733337733733333
ccc33333333333333333333333333333333333333333333ccc333333333333333333333333333333333333333333377333377773777737777333337777733333
ccc33333333333333333333333333333333333333333333ccc333333333333333333333333333333333333333333333333333333333333333333333333333333
ccc333c333333333333333333333333333333333c333333ccc333333333333333333333333333333333333333333333333333333333333333333333333333333
ccc33ccc3333333333333333333333333333333ccc33c33ccc333333333333333333333333333333333333333333333333333333333333333333333333333333
ccc33ccc333c333333333333333333333333333ccc3c6c3ccc333333333333333333333333333333333333333333333333333333333333333333333333333333
ccc3ccc333ccc33333333333333333333333333ccc3ccc3ccc333333333333333333333333333333333333333333333333333333333333333333333333333333
ccc3ccc333ccc33333333333333333333333333ccc33c33ccc333333333333333333333333333333333333333333333333333333333333333333333333333333
cccccc3333ccc33333333333333333333333333ccc33333ccc333333333333333333333333333333333333333333333333333333333333333333333333333333
cccccc3333ccc33333333333333333333333333ccc33c33ccc333333333333333333333333333333333333333333333333333333333333333333333333333333
ccccc33333ccc33333333333333333333333333ccc3ccc3ccc333333333333333333333333333333333333333333333333333333333333333333333333333333
ccccc33333ccc333cccccc333c33ccc3333ccccccc3ccc3ccc333c3333ccc3333333333333333333333333333333333333333333333333333333333333333333
cccc333333ccc33cccccccc3cc3ccccc33cccccccc3ccc3ccc33ccc33ccccc333333333333333333333333333333333333333333333333333333333333333333
c6c3333333c6c33cc6ccccc3c6cccccc33cc6ccccc3c6c3c6c33ccc3ccccccc33333333333333333333333333333333333333333333333333333333333333333
c7cc333333c7c33c7cc3ccc3c7cccc7cc3c7cc3ccc3c7c3c7c3c7c33c6c33cc33333333333333333333333333333333333333333333333333333333333333333
ccccc33333ccc33ccc33ccc3cccc3cccc3ccc33ccc3ccc3ccc3ccc3c7c3333cc3333333333333333333333333333333333333333333333333333333333333333
c6cccc3333c6c33c6c33ccc3c6cc33ccc3c6c33ccc3c6c3c6cccc33ccccccccc3333333333333333333333333333333333333333333333333333333333333333
cccccc3335ccc33ccc33ccc3cccc33ccc3ccc33ccc3ccc3ccccc333c6ccccccc3333333333333333333333333333333333333333333333333333333333333333
ccc3ccc355ccc33ccc33ccc3cccc33ccc3ccc33ccc5ccc3cccccc35cccccccc55333333333333333333333333333333333333333333333333333333333333333
ccc3ccc553ccc33ccc33ccc3cccc33ccc3ccc33ccc5ccc5cccccc55cc35555553333333333333333333333333333333333333333333333333333333333333333
ccc33ccc55ccc35ccc35ccc5cccc35ccc5ccc35ccc5ccc5ccc3ccc5cc55533333333333333333333333333333333333333333333333333333333333333333333
ccc35ccc53ccc55ccc55ccc5cccc55ccc5ccc55ccc5ccc5ccc5ccc3ccc5333cc3333333333333333333333333333333333333333333333333333333333333333
cec555cec5cecc5cecccccc5cecc55cec5cecccccc5cec5cec55cecceccccccc5333333333333333333333333333333333333333333333333333333333333333
cec533cec5ccec5ccedcccc5ccec53ccc5ccedcccc5ccc5ccc53ccc5cedcccc53333333333333333333333333333333333333333333333333333333333333333
3c53333c533ccc33cccccc533cc5333c533cccc5c533c533c5333c533ccccc533333333333333333333333333333333333333333333333333333333333333333
3883338833333033333330000033333333333333333333333333333333336333333333333333333333333333333333303cccccccccccccc33cccccccccccccc3
888838888333303333333300003333333339393933934333333939393396463333393939339346333339393933934630ccddddddddddddccccddddddddddddcc
8888888883330003333333303333333333339a999994333333339a999994673333339a999994673333339a9999946730cdccccccccccccdccdccccccccccccdc
88888888833300033330003030003333333339aa92133333333339aa92163533333339aa92136533333339aa92136530cdcc8cccc7777cdccdcc8cccc7777cdc
38888888333000003330000000003333333335777554333333333377ddd63633333333d7777366333333357775536630cdcb7eccc7cc7cdccdcb7eccc7cc7cdc
338888833300000003300330330033333333650707549953333333707dd33d33333336d757536d333333350707536d33cdcc1ccc77777cdcc6cc1ccc77777cdc
3338883333303030333333303333333333366577775498533333337776dd3533333336d77dd365333333657777556533cdcccccc77cc7cdcc6cccccc77cc7cdc
33338333333330333333330003333333333335777554e833333333d7766d3533333336d7777365333333d55776d56533c5dddddd66666d5cc6cccccc77777cdc
33338333333300033333300000333333333355566553e833333333e8661d353333333dd666336533333355d666656533d77777777777777dc6ccccccccccccdc
33333333333333333333333333333333333333e22188883333333a98228d5dd333333dc511955dd3333336c111955dd37777777777777777c6cc9c9cccccccdc
3333833333333333333333333333333333333ea98888883333333ea988887783333366ccc99c77c333336cccc99c77c37777777777777777cdc8ccc8ccccccdc
333383333333333333333333333333333333e88a9885333333333e8a9888758333336ccca9cc75c333336ccca9cc75c37777777777777777cdccfcfcfcfcfcdc
333888333333333333333333333333333333e888998d333333333e889988888333336cca9cccccc333336cca9ccdccc37777777777777777c6ccceccceccccdc
333888333333333333333333333333333333e888899d333333333e888998533333336ca9cccc533333336ca9cccd53337777777777777777cdcc5c5c5c5c5cdc
3388888333333333333333333333333333333d888dd33333333333d8889d333333333d9ccccd33333333369cccc533337777777777777777cdc1ccc1ccc1ccdc
3888888833333333333333333333333333333333333333333333333333333333333333333333333333333333333333337777777777777777cdccbcbcbcbcbcdc
3388888333333333333333333333333333333333333333333333333333333333333333333333333333333333333333337777777777777777cdcccacccaccccdc
3338883333333333333333333333333333333339333333333333339333333333333333393333363333333339333333337777777777777777cdcc9c9c9c9c9cdc
3338883333333333333333333333333333333339993333333333339993333333333333999933675333333399993333337777777777777777cdc8ccc8ccc8cc6c
33338333333333333333333333333333333333aa9213333333339aa999333333333339a99dd33533333339a99dd333337777777777777777cdccfcfcfcfcfcdc
3333833333333333333333333333333333333d77dd533333333357775533333333333ad7777d363333333ad7777d33337777777777777777cdccceccceccccdc
3333333333333333333333333333333333333d707d533333333350707533333333336d57070d3d3333336d57070d33337777777777777777cdccccccccccccdc
3333333333333333333333333333333333333d7777553333333357777533333333336d57777d353333336d57777d33337777777777777777ccddddddddddddcc
33333333333333333333333333333333333335577685e333333357777593333333336d57777d353333336d57777d233337777777777777733cccccccccccccc3
33333333333333333333333333333333333355ed228eee3333355566599933333333355666dd35333333355666d2223300000000000000000000000000000000
3333333333333333333333333333333333335a988885e3333333e822189833333333d5c111955d333333d5c111952d3300000000000000000000000000000000
3333333333333333333333333333333333333ea988877833333e98888877333333336cccc99c773333336cccc99c773300000000000000000000000000000000
3333333333333333333333333333333333333e8a98872833333ea9888871333333336ccca9cc753333336ccca9cc753300000000000000000000000000000000
3333333333333333333333333333333333333e8899888833333e8a988883333333336cca9cccc33333336cca9cccc33300000000000000000000000000000000
3333333333333333333333333333333333333e8889985333333e88998853333333336ca9cccc533333336ca9cccc533300000000000000000000000000000000
33333333333333333333333333333333333333d8889d33333333d8899d33333333333d9ccccd333333333d9ccccd333300000000000000000000000000000000
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333300000000000000000000000000000000
33333333336333333333333333333333333333333333333333333333333333333333333333333333333333333666666663666666663666666666666663333333
33333333366363333333333333333333333333333333333333333333333334333333333333333333333333336333333336333333336333333333333336333333
33339999966673333333399999333333333333999993313333333999993345333336dddddddddddddd4333336333333336333333336333333333333336333333
3333999995635333333339999933333333333399999323133333399999334533336d444444444444444d33336333333336333333336333333333333336333333
33336777d5636333333335777d53443333333dd777d3231333333677ddd34d33336d333333333333336d33336333333336333333336333333333333336333333
333367577533d333333335575d539a3333336dd7757d313333336d575dd34233336d333333333333336d33336333333336333333336333333333333336333333
3333677775535333333335777d559a3333336dd7777d231333336d7776dd4233336d333333333333336d33336333333336333333336333333333333336333333
3333577776535333333335577654444333336dd7777d231333336dd7766d4533336d333333333333336d33336333333336333333336333333333333336333333
3333556655577333333335566655663333333dd666ddf133333333d6666d4533336d333333333333336d33336333333336333333336333333333333336333333
3333e8228887233333333e222185663333333dc112955dd3333336c1129545d3336d333333333333336d33336333333336333333336333333333333336333333
333ea988888883333333ea988888778333336cccc99c77c333336cccc99c77c3336d333333333333336d33336333333336333333336333333333333336333333
333e8a98888883333333e8a98888758333336ccc99cc75c333336ccc99cc75c3336d333333333333336d33336333333336333333336333333333333336333333
333e8899885333333333e88a9888668333336cca9cccccc333336cca9ccc45c3336d333333333333336d33336333333336333333336333333333333336333333
333e888998d333333333e8889985663333336ca9cccc533333336ca9ccc14d33336d333333333333336d33336333333336333333336333333333333336333333
3333d8889d33333333333d88899d663333333a9ccccd33333333359ccc534533336d333333333333336d33336333333336333333336333333333333336333333
3333333333333333333333333333333333333333333333333333333333333533336d333333333333336d33336333333336333333336333333333333336333333
0000000000000000000000000000000000000000000000000000000000000000336d333333333333336d33336333333336333333336333333333333336333333
0000000000000000000000000000000000000000000000000000000000000000336d333333333333336d33336333333336333333336333333333333336333333
0000000000000000000000000000000000000000000000000000000000000000336d333333333333336d33336333333336333333336333333333333336333333
0000000000000000000000000000000000000000000000000000000000000000336d333333333333336d33336333333336333333336333333333333336333333
0000000000000000000000000000000000000000000000000000000000000000336d333333333333336d33336333333336333333336333333333333336333333
0000000000000000000000000000000000000000000000000000000000000000336d333333333333336d33336333333336333333336333333333333336333333
0000000000000000000000000000000000000000000000000000000000000000336d333333333333336d33336333333336333333336333333333333336333333
0000000000000000000000000000000000000000000000000000000000000000336d333333333333336d33333666666663666666663666666666666663333333
0000000000000000000000000000000000000000000000000000000000000000336d333333333333336d33333333333333333333333333333333333333333333
0000000000000000000000000000000000000000000000000000000000000000336d333333333333336d33333333333333333333333333333333333333333333
00000000000000000000000000000000000000000000000000000000000000003364dddddddddddddddd33333333333333333333333333333333333333333333
00000000000000000000000000000000000000000000000000000000000000003334444444444444444533333333333333333333333333333333333333333333
00000000000000000000000000000000000000000000000000000000000000003333333333333333333333333333333333333333333333333333333333333333
00000000000000000000000000000000000000000000000000000000000000003333333333333333333333333333333333333333333333333333333333333333
00000000000000000000000000000000000000000000000000000000000000003333333333333333333333333333333333333333333333333333333333333333
00000000000000000000000000000000000000000000000000000000000000003333333333333333333333333333333333333333333333333333333333333333
__label__
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
333777777777777773333777777777777773333666666666666663333777777777777773333333333333333333333777777777777773333cccccccccccccc333
33778787777778887733777877777778887733633333333333333633770007777770007733333333333333333333778787777778787733ccddddddddddddcc33
33788888777778787753778887777778787753633333333333333633707070777770707753333333333333333333788888777778787753cdccccccccccccdc53
33788888777778887753788888777778887753633333333333333633700000777770007753333333333333333333788888777778877753cdcc8cccc7777cdc53
33778887777778787753778887777778787753633333333333333633707070777770707753333333333333333333778887777778787753cdcb7eccc7cc7cdc53
33777877777778787753777877777778787753633333333333333633777077777770707753333333333333333333777877777778787753c6cc1ccc77777cdc53
33777777777777777753777777777777777753633333333333333633777777777777777753333333333333333333777777777777777753c6cccccc77cc7cdc53
33777777777777777753777777777777777753633333333333333633777777777777777753333333333333333333777777777777777753c6cccccc77777cdc53
33777777777777777753777777777777777753633333333333333633777777777777777753333333333333333333777777777777777753c6ccccccccccccdc53
33777777777777777753777777787777777753633333333333333633777777000007777753333333333333333333777979797797477753c6cc9c9cccccccdc53
3377778877788777775377777778777777775363333333333333363377777770000777775333333333333333333377779a999994777753cdc8ccc8ccccccdc53
33777888878888777753777777888777777753633333333333333633777777770777777753333333333333333333777779aa9217777753cdccfcfcfcfcfcdc53
33777888888888777753777777888777777753633333333333333633777700070700077753333333333333333333777775777554777753c6ccceccceccccdc53
33777888888888777753777778888877777753633333333333333633777700000000077753333333333333333333777765070754997753cdcc5c5c5c5c5cdc53
33777788888887777753777788888887777753633333333333333633777700770770077753333333333333333333777665777754987753cdc1ccc1ccc1ccdc53
33777778888877777753777778888877777753633333333333333633777777770777777753333333333333333333777775777554e87753cdccbcbcbcbcbcdc53
33777777888777777753777777888777777753633333333333333633777777700077777753333333333333333333777755566557e87753cdcccacccaccccdc53
33777777787777777753777777888777777753633333333333333633777777000007777753333333333333333333777777e22188887753cdcc9c9c9c9c9cdc53
3377777778777777775377777778777777775363333333333333363377777777777777775333333333333333333377777ea98888887753cdc8ccc8ccc8cc6c53
337777777777777777537777777877777777536333333333333336337777777777777777533333333333333333337777e88a9885777753cdccfcfcfcfcfcdc53
337777777777777777537777777777777777536333333333333336337777777777777777533333333333333333337777e888998d777753cdccceccceccccdc53
337777777777777777537777777777777777536333333333333336337777777777777777533333333333333333337777e888899d777753cdccccccccccccdc53
3377777777777777775377777777777777775363333333333333363377777777777777775333333333333333333377777d888dd7777753ccddddddddddddcc53
333777777777777775333777777777777775333666666666666663333777777777777775333333333333333333333777777777777775333cccccccccccccc533
33335555555555555333335555555555555333333333333333333333335555555555555333333333333333333333335555555555555333335555555555555333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
333777777777777773333777777777777773333cccccccccccccc3333cccccccccccccc3333cccccccccccccc3333cccccccccccccc3333cccccccccccccc333
33777877777778787733777877777778887733ccddddddddddddcc33ccddddddddddddcc33ccddddddddddddcc33ccddddddddddddcc33ccddddddddddddcc33
33778887777778787753778887777777877753cdccccccccccccdc53cdccccccccccccdc53cdccccccccccccdc53cdccccccccccccdc53cdccccccccccccdc53
33788888777778877753788888777777877753cdcc8cccc7777cdc53cdcc8cccc7777cdc53cdcc8cccc7777cdc53cdcc8cccc7777cdc53cdcc8cccc7777cdc53
33778887777778787753778887777777877753cdcb7eccc7cc7cdc53cdcb7eccc7cc7cdc53cdcb7eccc7cc7cdc53cdcb7eccc7cc7cdc53cdcb7eccc7cc7cdc53
33777877777778787753777877777778877753cdcc1ccc77777cdc53cdcc1ccc77777cdc53cdcc1ccc77777cdc53cdcc1ccc77777cdc53cdcc1ccc77777cdc53
33777777777777777753777777777777777753cdcccccc77cc7cdc53cdcccccc77cc7cdc53cdcccccc77cc7cdc53cdcccccc77cc7cdc53cdcccccc77cc7cdc53
33777777777777777753777777777777777753c5dddddd66666d5c53c5dddddd66666d5c53c5dddddd66666d5c53c5dddddd66666d5c53c5dddddd66666d5c53
33777777777777777753777777777777777753dccccccccccccccd53dccccccccccccccd53dccccccccccccccd53dccccccccccccccd53dccccccccccccccd53
33770007777777077753777777777777777753ccddddddddddddcc53ccddddddddddddcc53ccddddddddddddcc53ccddddddddddddcc53ccddddddddddddcc53
33707070777770707753777799999777777753cdccccccccccccdc53cdccccccccccccdc53cdccccccccccccdc53cdccccccccccccdc53cdccccccccccccdc53
33700000777770707753777799999777777753cdcc8cccc7777cdc53cdcc8cccc7777cdc53cdcc8cccc7777cdc53cdcc8cccc7777cdc53cdcc8cccc7777cdc53
3370707077777007775377775777d574477753cdcb7eccc7cc7cdc53cdcb7eccc7cc7cdc53cdcb7eccc7cc7cdc53cdcb7eccc7cc7cdc53cdcb7eccc7cc7cdc53
3377707777777700775377775575d579a77753cdcc1ccc77777cdc53cdcc1ccc77777cdc53cdcc1ccc77777cdc53cdcc1ccc77777cdc53cdcc1ccc77777cdc53
3377777777777777775377775777d559a77753cdcccccc77cc7cdc53cdcccccc77cc7cdc53cdcccccc77cc7cdc53cdcccccc77cc7cdc53cdcccccc77cc7cdc53
33777777777777777753777755776544447753c5dddddd66666d5c53c5dddddd66666d5c53c5dddddd66666d5c53c5dddddd66666d5c53c5dddddd66666d5c53
33777777777777777753777755666556677753d77777777777777d53d77777777777777d53dccccccccccccccd53dccccccccccccccd53dccccccccccccccd53
337777779777777777537777e2221856677753778787777778887753778787777777877753ccddddddddddddcc53ccddddddddddddcc53ccddddddddddddcc53
33777779999777777753777ea9888887787753788888777778787753788888777778787753cdccccccccccccdc53cdccccccccccccdc53cdccccccccccccdc53
3377779a99dd77777753777e8a988887587753788888777778887753788888777778787753cdcc8cccc7777cdc53cdcc8cccc7777cdc53cdcc8cccc7777cdc53
337777ad7777d7777753777e88a98886687753778887777777787753778887777778877753cdcb7eccc7cc7cdc53cdcb7eccc7cc7cdc53cdcb7eccc7cc7cdc53
337776d57070d7777753777e88899856677753777877777777787753777877777777887753cdcc1ccc77777cdc53cdcc1ccc77777cdc53cdcc1ccc77777cdc53
337776d57777d77777537777d88899d6677753777777777777777753777777777777777753cdcccccc77cc7cdc53cdcccccc77cc7cdc53cdcccccc77cc7cdc53
337776d57777d2777753377777777777777533777787877787877753e22222222222222853c5dddddd66666d5c53c5dddddd66666d5c53c5dddddd66666d5c53
33777755666d2227775333555555555555533377778887778887775e288888888888888823dccccccccccccccd53dccccccccccccccd53dccccccccccccccd53
33777d5c111952d7775333333333333333333377777878787877775e266066666660006e25ccddddddddddddcc53ccddddddddddddcc53ccddddddddddddcc53
337776cccc99c777775333333333333333333377777778887777775e267077777777077e25cdccccccccccccdc53cdccccccccccccdc53cdccccccccccccdc53
337776ccca9cc757775333333333333333333377778787878787775e260007777777077e25cdcc8cccc7777cdc53cdcc8cccc7777cdc53cdcc8cccc7777cdc53
337776cca9cccc77775333333333333333333377778887778887775e200000777777077e25cdcb7eccc7cc7cdc53cdcb7eccc7cc7cdc53cdcb7eccc7cc7cdc53
337776ca9cccc577775333333333333333333377777877777877775e267077777770077e25cdcc1ccc77777cdc53cdcc1ccc77777cdc53cdcc1ccc77777cdc53
337777d9ccccd777775333333333333333333377777777777777775e267777777777777e25cdcccccc77cc7cdc53cdcccccc77cc7cdc53cdcccccc77cc7cdc53
3337777777777777753333333333333333333377777877777877775e267777777777777e25c5dddddd66666d5c53c5dddddd66666d5c53c5dddddd66666d5c53
3333555555555555533333333333333333333377778887778887775e267777777777777e25d77777777777777d53dccccccccccccccd53dccccccccccccccd53
3333333333333333333333333333333333333377778787778787775e267777777777777e25777877777778887753ccddddddddddddcc53ccddddddddddddcc53
3333333333333333333333333333333333333377777777777777775e267779999977177e25778887777777787753cdccccccccccccdc53cdccccccccccccdc53
3333333333333333333333333333333333333377777877777877775e267779999972717e25788888777777787753cdcc8cccc7777cdc53cdcc8cccc7777cdc53
3333333333333333333333333333333333333377778887778887775e2677dd777d72717e25778887777777787753cdcb7eccc7cc7cdc53cdcb7eccc7cc7cdc53
3333333333333333333333333333333333333377778787778787775e2676dd7757d7177e25777877777777787753cdcc1ccc77777cdc53cdcc1ccc77777cdc53
3333333333333333333333333333333333333377777777777777775e2676dd7777d2717e25777777777777777753cdcccccc77cc7cdc53cdcccccc77cc7cdc53
3333333333333333333333333333333333333337777777777777753e2676dd7777d2717e25777778777778777753a44444444444444453c5dddddd66666d5c53
3333333333333333333333333333333333333333555555555555533e2677dd666ddf177e2577778887778887775a499999999999999943dccccccccccccccd53
3333333333333333333333333333333333333333333333333333333e2677dc112955dd7e2577777877777877775a466266622662226a45ccddddddddddddcc53
3333333333333333333333333333333333333333333333333333333e2676cccc99c77c7e2577777777877777775a468887778778787a45cdccccccccccccdc53
3333333333333333333333333333333333333333333333333333333e2676ccc99cc75c7e2577777778887777775a428888778778787a45cdcc8cccc7777cdc53
3333333333333333333333333333333333333333333333333333333e2676cca9cccccc7e2577777777877777775a468887778778787a45cdcb7eccc7cc7cdc53
3333333333333333333333333333333333333333333333333333333e2676ca9cccc5777e2577777877777877775a467877788878887a45cdcc1ccc77777cdc53
3333333333333333333333333333333333333333333333333333333e2677a9ccccd7777e2577778887778887775a467777777777777a45cdcccccc77cc7cdc53
3333333333333333333333333333333333333333333333333333333e82222222222222222577777877777877775a467778777778777a45c5dddddd66666d5c53
3333333333333333333333333333333333333333333333333333333388888888888888881377777777777777775a467788877788877a45d77777777777777d53
3333333333333333333333333333333333333333333333333333333335555555555555555377777777777777775a467778778778777a45777077777770007753
3333333333333333333333333333333333333333333333333333333333333333333333333377777877777877775a467777788877777a45777077777777707753
3333333333333333333333333333333333333333333333333333333333333333333333333377778887778887775a467778778778777a45770007777770007753
3333333333333333333333333333333333333333333333333333333333333333333333333377777877777877775a467788877788877a45700000777770777753
3333333333333333333333333333333333333333333333333333333333333333333333333377777777777777775a467778777778777a45777077777770007753
3333333333333333333333333333333333333333333333333333333333333333333333333377777777777777775a467777777777777a45777777777777777753
3333333333333333333333333333333333333333333333333333333333333333333333333337777777777777753a467778777778777a45777777777777777753
3333333333333333333333333333333333333333333333333333333333333333333333333333555555555555533a467788877788877a45777777770777777753
3333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333a467778778778777a45777777770777777753
3333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333a467777788877777a45777777700077777753
3333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333a467778778778777a45777777000007777753
3333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333a467788877788877a45777777770777777753
3333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333a467778777778777a45777777777777777753
3333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333a467777777777777a45777777777777777753
3333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333a944444444444444445777777770777777753
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333999999999999999923777777000007777753
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333355555555555555553777777700077777753
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333777777770777777753
333c3333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333777777770777777753
33ccc333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333777777777777777753
33ccc333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333777777777777777753
33ccc333333333333333333333333333333333333333333333c33333333333333333333333333333333333333333333333333333333333777777777777777753
33ccc33333333333333333333333333333333333333333333ccc3333333333333333333333333333333333333333333333333333333333377777777777777533
33ccc33333333333333333333333333333333333333333333ccc3333333333333333333333333333333333333333333333333333333333335555555555555333
33ccc33333333333333333333333333333333333333333333ccc3333333333333333333333333333333333333333333333333333333333333333333333333333
33ccc333c333333333333333333333333333333333c333333ccc3333333333333333333333333333333333333333333333333333333333333333333333333333
33ccc33ccc3333333333333333333333333333333ccc33c33ccc3333333333333333333333333333333333333333333333333333333333333333333333333333
33ccc33ccc333c333333333333333333333333333ccc3c6c3ccc3333333333333333333333333333333333333333333333333333333333333333333333333333
33ccc3ccc333ccc33333333333333333333333333ccc3ccc3ccc3333333333333333333333333333333333333333333333333333333333333333333333333333
33ccc3ccc333ccc33333333333333333333333333ccc33c33ccc3333333333333333333333333333333333333333333333333333333333333333333333333333
33cccccc3333ccc33333333333333333333333333ccc33333ccc3333333333333333333333333333333333333333333333333333333333333333333333333333
33cccccc3333ccc33333333333333333333333333ccc33c33ccc3333333333333333333333333333333333333333333333333333333333333333333333333333
33ccccc33333ccc33333333333333333333333333ccc3ccc3ccc3333333333333333333333333333333333333333333333333333333333333333333333333333
33ccccc33333ccc333cccccc333c33ccc3333ccccccc3ccc3ccc333c3333ccc33333333333333333333333333333333333333333333333333333333333333333
33cccc333333ccc33cccccccc3cc3ccccc33cccccccc3ccc3ccc33ccc33ccccc3333333333333333333333333333333333333333333333333333333333333333
33c6c3333333c6c33cc6ccccc3c6cccccc33cc6ccccc3c6c3c6c33ccc3ccccccc333333333333333333333333333333333333333333333333333333333333333
33c7cc333333c7c33c7cc3ccc3c7cccc7cc3c7cc3ccc3c7c3c7c3c7c33c6c33cc333333333333333333333333333333333333333333333333333333333333333
33ccccc33333ccc33ccc33ccc3cccc3cccc3ccc33ccc3ccc3ccc3ccc3c7c3333cc33333333333333333333333333333333333333333333333333333333333333
33c6cccc3333c6c33c6c33ccc3c6cc33ccc3c6c33ccc3c6c3c6cccc33ccccccccc33333333333333333333333333333333333333333333333333333333333333
33cccccc3335ccc33ccc33ccc3cccc33ccc3ccc33ccc3ccc3ccccc333c6ccccccc33333333333333333333333333333333333333333333333333333333333333
33ccc3ccc355ccc33ccc33ccc3cccc33ccc3ccc33ccc5ccc3cccccc35cccccccc553333333333333333333333333333333333333333333333333333333333333
33ccc3ccc553ccc33ccc33ccc3cccc33ccc3ccc33ccc5ccc5cccccc55cc355555533333333333333333333333333333333333333333333333333333333333333
33ccc33ccc55ccc35ccc35ccc5cccc35ccc5ccc35ccc5ccc5ccc3ccc5cc555333333333333333333333333333333333333333333333773377733373773377733
33ccc35ccc53ccc55ccc55ccc5cccc55ccc5ccc55ccc5ccc5ccc5ccc3ccc5333cc33333333333333333333333333333333333333333373333733733373373733
33cec555cec5cecc5cecccccc5cecc55cec5cecccccc5cec5cec55cecceccccccc53333333333333333333333333333333333333333373377733733373373733
33cec533cec5ccec5ccedcccc5ccec53ccc5ccedcccc5ccc5ccc53ccc5cedcccc533333333333333333333333333333333333333333373373333733373373733
333c53333c533ccc33cccccc533cc5333c533cccc5c533c533c5333c533ccccc5333333333333333333333333333333333333333333777377737333777377733
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333

__sfx__
000100001500015000150001500015000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000f5100a520087200c7300e730147201671019710007000070000700007000070021300007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
000100000c5200f5200c7401274019730197201e7101e710003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
00010000085200b5200c7401274019730197201e7101e710003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
0001000005520095200c7401274019730197201e7101e710003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
0001000011530155301174013740187301b7202471027710007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
0001000018510145200e7200f7300f730137201671010710007000070000700007000070021300007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
000100000c5300f530187401a7401d730217202671028710007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
000200000a5300d5300f7400d5400e730177400c53013740157401a74018530197302074026740000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000c5300f5301a7401c7401c73020720297102a710007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
0001000018710147200f73011740167301a7201f71024710004000040000400004000040021400004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400
000100000e5301053017740197401c730217202b7102e710007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
00010000125100f5200e73010740147301c7202071021710004000040000400004000040021400004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400
000100000c5300f53018740197401a7301e720237102a7101e7000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
000600001a12021120000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000e7300f7301074014740167301c7301e7101f100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00010000097300c7301074013740187301c730207101f100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0001000015730157301574012740177301c7301c7101c700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00010000137701376013750107400f730167500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00100000181101c1101f11024110281102b1103011034110371103c11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00100000321102c1102911025110211101e1101c11018110131101011008110001100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00010000065300a5301174014740177301a7201b7101d710007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
__music__
00 13424344
00 4e424344

