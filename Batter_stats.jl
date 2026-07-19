using JSON3,JSONTables,DataFrames,Unicode,BenchmarkTools,NativeFileDialog,Dates

const names = ["Shy Guy", "Noki","Pianta","Koopa","Dry Bones","Magikoopa","Paratroopa","Bro","Toad","Total","Mario","Monty","Baby Mario", "Luigi", "Baby Luigi", "Peach", "Daisy","Yoshi","Bowser","DK","Diddy","Dixie","Wario","Waluigi","Birdo","Bowser Jr","King Boo","Boo","Petey","Toadette","Toadsworth","Goomba","Paragoomba","Shy Guy(R)","Shy Guy(B)","Shy Guy(Y)","Shy Guy(G)","Shy Guy(Bk)","Noki(R)","Noki(G)","Noki(B)","Pianta(B)","Pianta(R)","Pianta(Y)","Koopa(R)","Koopa(G)","Dry Bones(Gy)","Dry Bones(R)","Dry Bones(G)","Dry Bones(B)","Magikoopa(R)","Magikoopa(G)","Magikoopa(B)","Magikoopa(Y)","Paratroopa(R)","Paratroopa(G)","Bro(F)","Bro(B)","Bro(H)","Toad(R)","Toad(B)","Toad(Y)","Toad(G)","Toad(P)"]

const O_stats_name = ["AB","H","HR","RBI","SB","2B","3B","K","BB","HBP","SF","PA","R","SH","GP"]

const P_stats_name =["ER","R","BF","SO","BB","OutsPP","H","HR","PC","SPC","GP","PO","GS","HBP","IP"]

const D_stats_name = ["PO","OutsPP","BF","GP","INN"]

const T_stats_name = ["W","L","D","Pct","GP"]

function json_to_dict(statpath::AbstractString,RIO_ID::AbstractString)
    path = "$statpath/$RIO_ID"
    game_dict = JSON3.parsefile(path*"/Batting_data.json")
    return game_dict
end

function Bat_stat_with_spec(Bats::AbstractDict,SS::Int64,Outs=[0,1,2],Balls=[0,1,2,3],Strikes=[0,1,2],Bases=[0,0,0])
    #Gets BA,OBP,SLG,OPS,ISO for specific at bat conditons
    AB = 0
    Hits = 0
    Singles = 0
    Doubles = 0
    Triples = 0
    HR = 0
    SO = 0
    BB = 0
    HBP = 0
    SF = 0
    for bat in keys(Bats)
        Atbat = Bats[bat]
        if Atbat["Outs"] in Outs && Atbat["Balls"] in Balls && Atbat["Strikes"] in Strikes && Atbat["1B"] >= Bases[1] && Atbat["2B"] >= Bases[2] && Atbat["3B"] >= Bases[3] && Atbat["BSS"] == SS
            result = Atbat["Result"]
            if result == "Strikeout"
                SO +=1
                AB+=1
            elseif result == "Single"
                Hits += 1
                AB+=1
                Singles += 1
            elseif result == "Double"
                Hits += 1
                AB+=1
                Doubles += 1
            elseif result == "Triple"
                Hits += 1
                AB+=1
                Triples += 1
            elseif result == "HR"
                Hits += 1
                AB+=1
                HR += 1
            elseif result == "Walk (BB)"
                BB += 1
            elseif result == "Walk (HBP)"
                HBP += 1
            elseif result == "SacFly"
                SF += 1
                AB+=1
            end
        end
    end
    if AB != 0
        BA = round(Hits/AB,digits=3)
        SLG = round((Hits + Doubles + Triples*2 + HR*3)/AB,digits=3)
        ISO = round((Doubles + Triples*2 + HR*3)/AB,digits=3)
        OBP = round((Hits + BB + HBP)/(AB+BB+HBP+SF),digits=3)
    elseif AB == 0 && (BB !=0 || HBP != 0 || SF != 0)
        BA = 0
        SLG = 0
        ISO = 0
        OBP = round((Hits + BB + HBP)/(AB+BB+HBP+SF),digits=3)
    else
        BA = 0
        SLG = 0
        ISO = 0
        OBP = 0
    end
    OPS = round(OBP + SLG,digits=3)
    return BA,SLG,OBP,OPS,ISO
end

bat_data = json_to_dict("Stats/Gobster9","Gobster9")

BA,SLG,OBP,OPS,ISO = Bat_stat_with_spec(bat_data["Luigi"],0)
