using JSON3,JSONTables,DataFrames,Unicode,BenchmarkTools,NativeFileDialog,Dates

const names = ["Shy Guy", "Noki","Pianta","Koopa","Dry Bones","Magikoopa","Paratroopa","Bro","Toad","Total","Mario","Monty","Baby Mario", "Luigi", "Baby Luigi", "Peach", "Daisy","Yoshi","Bowser","DK","Diddy","Dixie","Wario","Waluigi","Birdo","Bowser Jr","King Boo","Boo","Petey","Toadette","Toadsworth","Goomba","Paragoomba","Shy Guy(R)","Shy Guy(B)","Shy Guy(Y)","Shy Guy(G)","Shy Guy(Bk)","Noki(R)","Noki(G)","Noki(B)","Pianta(B)","Pianta(R)","Pianta(Y)","Koopa(R)","Koopa(G)","Dry Bones(Gy)","Dry Bones(R)","Dry Bones(G)","Dry Bones(B)","Magikoopa(R)","Magikoopa(G)","Magikoopa(B)","Magikoopa(Y)","Paratroopa(R)","Paratroopa(G)","Bro(F)","Bro(B)","Bro(H)","Toad(R)","Toad(B)","Toad(Y)","Toad(G)","Toad(P)"]

const O_stats_name = ["AB","H","HR","RBI","SB","2B","3B","K","BB","HBP","SF","PA","R","SH","GP"]

const P_stats_name =["ER","R","BF","SO","BB","OutsPP","H","HR","PC","SPC","GP","PO","GS","HBP","IP"]

const D_stats_name = ["PO","OutsPP","BF","GP","INN"]

const T_stats_name = ["W","L","D","Pct","GP"]

const Positions = ["P","C","1B","2B","3B","SS","LF","RF","CF"]




