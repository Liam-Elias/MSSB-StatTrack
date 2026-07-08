using JSON3,JSONTables,DataFrames,Unicode,BenchmarkTools,NativeFileDialog,Dates

const names = ["Total","Mario","Monty","Baby Mario", "Luigi", "Baby Luigi", "Peach", "Daisy","Yoshi","Bowser","DK","Diddy","Dixie","Wario","Waluigi","Birdo","Bowser Jr","King Boo","Boo","Petey","Toadette","Toadsworth","Goomba","Paragoomba","Shy Guy(R)","Shy Guy(B)","Shy Guy(Y)","Shy Guy(G)","Shy Guy(Bk)","Noki(R)","Noki(G)","Noki(B)","Pianta(B)","Pianta(R)","Pianta(Y)","Koopa(R)","Koopa(G)","Dry Bones(Gy)","Dry Bones(R)","Dry Bones(G)","Dry Bones(B)","Magikoopa(R)","Magikoopa(G)","Magikoopa(B)","Magikoopa(Y)","Paratroopa(R)","Paratroopa(G)","Bro(F)","Bro(B)","Bro(H)","Toad(R)","Toad(B)","Toad(Y)","Toad(G)","Toad(P)"]

const O_stats_name = ["AB","H","HR","RBI","SB","2B","3B","K","BB","HBP","SF","PA","R","SH","GP"]

const P_stats_name =["ER","R","BF","SO","BB","OutsPP","H","HR","PC","SPC","GP","PO","GS","HBP"]

const D_stats_name = ["PO","OutsPP","BF","GP","INN"]

const Positions = ["P","C","1B","2B","3B","SS","LF","RF","CF"]

function get_json(P1::AbstractString;  P2::Union{AbstractString,Nothing}=nothing, CPU = false)

    #Check for existing JSON file folder and creates one if needed, makes folder name according to if P2 is provided or not
    if isa(P2,AbstractString) 
        sub_dir = P1*"-"*P2
    elseif isnothing(P2) && CPU
        sub_dir = P1*" with CPU"
    else
        sub_dir = P1
    end

    if isdir("./JSON_files/"*sub_dir)
         nothing
    else
            mkpath("./JSON_files/"*sub_dir)
    end
    
    Stat_path = pick_folder() #allow user to select Rio Stat Files Path
    if isempty(Stat_path)
        println("Operation cancelled by the user") # prints if no dir is selected
        return
    else
        println("Selected directory: ", Stat_path)
    end
    #Iteratre through all files in source dir
    for file in readdir(Stat_path)
        src_path = joinpath(Stat_path,file)
        dest_path = joinpath("./JSON_files/"*sub_dir,file)

        if isnothing(P2)
            #Verify is a decoded JSON file and is a game containing Player 1 (RIO player Id's)
            if CPU
                if isfile(src_path) && endswith(lowercase(file), ".json") && contains(lowercase(file), lowercase("decoded")) && contains(lowercase(file), lowercase(P1)) 
                    #Copy file if not currently in JSON_files dir or is newer version of file in JSON_files dir
                    if !isfile(dest_path) || (mtime(src_path) > mtime(dest_path))
                        cp(src_path,dest_path; force=true)
                        println("Copied: $file")
                    end
                end
            else
                #Same as above but Does not allow CPU games
                if isfile(src_path) && endswith(lowercase(file), ".json") && contains(lowercase(file), lowercase("decoded")) && contains(lowercase(file), lowercase(P1)) && !contains(lowercase(file), lowercase("CPU"))
                    if !isfile(dest_path) || (mtime(src_path) > mtime(dest_path))
                        cp(src_path,dest_path; force=true)
                        println("Copied: $file")
                    end
                end
            end
        else
            #Verify is a decoded JSON file and is a game between Player 1 and Player 2 (RIO player Id's)
            if isfile(src_path) && endswith(lowercase(file), ".json") && contains(lowercase(file), lowercase("decoded")) && contains(lowercase(file), lowercase(P1)) && contains(lowercase(file), lowercase(P2))
                #Copy file if not currently in JSON_files dir or is newer version of file in JSON_files dir
                if !isfile(dest_path) || (mtime(src_path) > mtime(dest_path))
                    cp(src_path,dest_path; force=true)
                    println("Copied: $file")
                end
            end
        end
    end
end

function single_game_stats(stat_file::AbstractString,RIO_ID::AbstractString,)

    #JSON file for game in form of dictionary
    json_dict = JSON3.parsefile(stat_file)
    Home_Player = json_dict["Home Player"]
    Away_Player = json_dict["Away Player"]
    if isequal_normalized(Home_Player,RIO_ID,casefold=true)
        game = get_game_stats(json_dict)
        return game,json_dict
    elseif isequal_normalized(Away_Player,RIO_ID,casefold=true)
        game = get_game_stats(json_dict)
        return game,json_dict
    else
        return 0,json_dict
    end
end

function get_game_stats(json_dict::AbstractDict)
    #Gets all stats for a single game separated by defensive stats and offensive stats for a given game, returns a dict with all characters and their stats
    Game_stats = Dict{AbstractString,Any}()
    Game_stats["GameLog"] = Dict{AbstractString,Any}()
    Game_stats[json_dict["Home Player"]] = Dict{AbstractString,Any}()
    for team in ["Home","Away"]
        player = json_dict["$team Player"]
        Game_stats[player] = Dict{AbstractString,Any}()
        Off_dict = get_offensive_stats(json_dict,team)
        Def_dict = get_defensive_stats(json_dict,team)
        for char in keys(Off_dict)
            Game_stats[player][char] = Dict{AbstractString,Dict{AbstractString,Any}}()
            Game_stats[player][char]["O_Stats"] = Off_dict[char]
            Game_stats[player][char]["D_Stats"] = Def_dict[char]
        end
    end
    Gen_stats = get_gen_stats(json_dict)
    Game_stats["GameLog"] = Gen_stats
    return Game_stats
end

function get_gen_stats(json_dict::AbstractDict)
    #Gets general game stats such as date,stadium,time,score,winner,runs per inning
    game_stats = Dict{AbstractString,Any}()
    game_stats["Stadium"] =json_dict["StadiumID"]
    DateS = split(json_dict["Date - Start"])
    Time_start = Time(DateS[4])
    Time_end = Time(split(json_dict["Date - End"])[4])
    M = Dates.month(Date(DateS[2], DateFormat("u")))
    Y = parse(Int,DateS[5])
    D = parse(Int,DateS[3])
    #Puts date and time into strings of the form Y/M/D and H:M:S
    game_stats["Date"] = string(Date(Y,M,D))
    game_stats["Start Time"] = string(Time_start)
    game_stats["Time"] = string(Time(Time_end-Time_start))
    game_stats["GL"] = json_dict["Innings Selected"]
    game_stats["IP"] = json_dict["Innings Played"]
    game_stats["H_R"] = 0
    game_stats["A_R"] = 0
    #Box score counts runs gotten per inning
    game_stats["BoxScore"] = Dict{Int,Dict{AbstractString,Any}}()
    for inn in 1:game_stats["IP"]
        game_stats["BoxScore"][inn] = Dict{AbstractString,Any}()
        game_stats["BoxScore"][inn]["H"] = 0
        game_stats["BoxScore"][inn]["A"] = 0
    end
    for team in ["Home","Away"]
        game_stats["$team Score"] = json_dict["$team Score"]
        game_stats["$team Player"] = json_dict["$team Player"]
        game_stats["$team H"] = 0
    end
    return game_stats
end 

function get_offensive_stats(json_dict::AbstractDict,team::AbstractString)

    Stats_dict = Dict{AbstractString,Dict{AbstractString,Any}}()

    #Iterate over each $team Player
    for i in 0:8
        ID = json_dict["Character Game Stats"]["$team Roster $i"]["CharID"] #Char name

        Stats_dict[ID] = Dict{AbstractString,Any}() #Create a Key player using ID

        Stats_dict[ID]["SuperS"] = json_dict["Character Game Stats"]["$team Roster $i"]["Superstar"] #Check if Superstar was enabled on Char

        O_stats = json_dict["Character Game Stats"]["$team Roster $i"]["Offensive Stats"] #Offensive Stats dict

        Stats_dict[ID]["AB"] = O_stats["At Bats"] 
        Stats_dict[ID]["H"] = O_stats["Hits"] 
        Stats_dict[ID]["HR"] = O_stats["Homeruns"] 
        Stats_dict[ID]["RBI"] = O_stats["RBI"]
        Stats_dict[ID]["SH"] = O_stats["Star Hits"] 
        Stats_dict[ID]["SB"] = O_stats["Bases Stolen"] 
        Stats_dict[ID]["2B"] = O_stats["Doubles"] 
        Stats_dict[ID]["3B"] = O_stats["Triples"] 
        Stats_dict[ID]["K"] = O_stats["Strikeouts"] 
        Stats_dict[ID]["BB"] = O_stats["Walks (4 Balls)"]
        Stats_dict[ID]["HBP"] = O_stats["Walks (Hit)"]
        Stats_dict[ID]["SF"] = O_stats["Sac Flys"]   
        Stats_dict[ID]["WC"] = json_dict["Character Game Stats"]["$team Roster $i"]["Captain"]
        Stats_dict[ID]["PA"] = Stats_dict[ID]["AB"] + Stats_dict[ID]["BB"] + Stats_dict[ID]["HBP"] + Stats_dict[ID]["SB"]
        Stats_dict[ID]["GP"] = 1

        if O_stats["At Bats"] != 0

            Stats_dict[ID]["BA"] = round(O_stats["Hits"]/O_stats["At Bats"],digits=3)
            Stats_dict[ID]["SLG"] = round((O_stats["Singles"] + 2*O_stats["Doubles"]+3*O_stats["Triples"]+4*O_stats["Homeruns"])/(O_stats["At Bats"]),digits=3)
            Stats_dict[ID]["OBP"] = round((O_stats["Hits"]+Stats_dict[ID]["BB"]+Stats_dict[ID]["HBP"])/(O_stats["At Bats"]+Stats_dict[ID]["BB"]+Stats_dict[ID]["HBP"]+Stats_dict[ID]["SF"]),digits=3)

        elseif O_stats["At Bats"] == 0 && ( O_stats["Walks (4 Balls)"] != 0 || O_stats["Walks (Hit)"] != 0 || O_stats["Sac Flys"] != 0)
        
            Stats_dict[ID]["BA"] = 0
             Stats_dict[ID]["SLG"] = 0
             Stats_dict[ID]["OBP"] = round((O_stats["Hits"]+Stats_dict[ID]["BB"]+Stats_dict[ID]["HBP"])/(O_stats["At Bats"]+Stats_dict[ID]["BB"]+Stats_dict[ID]["HBP"]+Stats_dict[ID]["SF"]),digits=3)

        else

             Stats_dict[ID]["BA"] = 0
             Stats_dict[ID]["SLG"] = 0
             Stats_dict[ID]["OBP"] = 0

        end

        Stats_dict[ID]["OPS"] = round(Stats_dict[ID]["SLG"] + Stats_dict[ID]["OBP"],digits=3)
        Stats_dict[ID]["R"] = 0      
    end
    return Stats_dict
end

function get_defensive_stats(json_dict::AbstractDict,team::AbstractString)

    Stats_dict = Dict{AbstractString,Dict{AbstractString,Any}}()

    #Iterate over each $team Player
    for i in 0:8
        ID = json_dict["Character Game Stats"]["$team Roster $i"]["CharID"] #Char name
        Stats_dict[ID] = Dict{AbstractString,Any}() #Create a Key player using ID

        #Stats_dict[ID]["SuperS"] = json_dict["Character Game Stats"]["$team Roster $i"]["Superstar"] #Check if Superstar was enabled on Char, we storre this along side the poition as it applies to all stats for that player in the game.

        D_stats = json_dict["Character Game Stats"]["$team Roster $i"]["Defensive Stats"] #Defensive Stats dict
        
        #We also store Big plays along side positions as it can only be know as a summed total of all positions
        Stats_dict[ID]["BigPlays"] = D_stats["Big Plays"]

        #Checks for a 1 inning devestating loss of a home team 1 batter HR
        if D_stats["Batters Per Position"] == []
            continue
        else
            #Gets keys relted to the positions this character played in the game
            for key in keys(D_stats["Batters Per Position"][1])

                #We convert the key to a string as it is stored as an symbol in the JSON file, but we want to store it as a string in our dict for easier access later
                dkey = string(key)

                Stats_dict[ID][dkey] = Dict{AbstractString,Any}()

                #If the character played as a pitcher, get all pitching stats
                if dkey == "P"
                    Stats_dict[ID][dkey]["ER"] = D_stats["Earned Runs"]
                    Stats_dict[ID][dkey]["R"] = D_stats["Runs Allowed"]
                    Stats_dict[ID][dkey]["BF"] = D_stats["Batters Faced"]
                    Stats_dict[ID][dkey]["SO"] = D_stats["Strikeouts"]
                    Stats_dict[ID][dkey]["BB"] = D_stats["Batters Walked"]
                    Stats_dict[ID][dkey]["HBP"] = D_stats["Batters Hit"]
                    Stats_dict[ID][dkey]["OutsPP"] = D_stats["Outs Pitched"]
                    Stats_dict[ID][dkey]["H"] = D_stats["Hits Allowed"]
                    Stats_dict[ID][dkey]["HR"] = D_stats["HRs Allowed"]
                    Stats_dict[ID][dkey]["PC"] = D_stats["Pitches Thrown"]
                    Stats_dict[ID][dkey]["SPC"] = D_stats["Star Pitches Thrown"]
                    Stats_dict[ID][dkey]["GP"] = 1
                    #Checks if and how many out the player got as a pitcher through direct put outs
                    if D_stats["Outs Per Position"] == []
                        Stats_dict[ID][dkey]["PO"] = 0
                    elseif haskey(D_stats["Outs Per Position"][1],"P")
                        Stats_dict[ID][dkey]["PO"] = D_stats["Outs Per Position"][1]["P"]
                    else
                        Stats_dict[ID][dkey]["PO"] = 0
                    end
                    #Checks if the pitcher was the Starting Pitcher and if so gives a game start stat
                    if team == "Home"
                        if json_dict["Events"][1]["Pitch"]["Pitcher Char Id"] == ID
                            Stats_dict[ID][dkey]["GS"] = 1
                        else
                            Stats_dict[ID][dkey]["GS"] = 0
                        end
                    else
                        for event in keys(json_dict["Events"])
                            if json_dict["Events"][event]["Half Inning"] == 1
                                if json_dict["Events"][event]["Pitch"]["Pitcher Char Id"] == ID
                                    Stats_dict[ID][dkey]["GS"] = 1
                                    break
                                else
                                    Stats_dict[ID][dkey]["GS"] = 0
                                    break
                                end
                            end
                        end
                    end
                    #calulates Innings Pitched stat in decimal form, where 1 out = .1 and 2 outs = .2
                    Stats_dict[ID][dkey]["IP"] = div(D_stats["Outs Pitched"],3) + (D_stats["Outs Pitched"]%3)/10
                    #Calculates WHIP, ERA, K/9, FIP, DICE, IP stats
                    if Stats_dict[ID][dkey]["IP"] != 0
                        Stats_dict[ID][dkey]["WHIP"] = round((Stats_dict[ID][dkey]["BB"] + Stats_dict[ID][dkey]["H"])/Stats_dict[ID][dkey]["IP"],digits=3)
                        Stats_dict[ID][dkey]["ERA"] = round((Stats_dict[ID][dkey]["ER"]/Stats_dict[ID][dkey]["IP"])*9,digits=3)
                        Stats_dict[ID][dkey]["K/9"] = round((Stats_dict[ID][dkey]["SO"]/Stats_dict[ID][dkey]["IP"])*9,digits=3)
                        Stats_dict[ID][dkey]["FIP"] = round(((13*Stats_dict[ID][dkey]["HR"] + 3*Stats_dict[ID][dkey]["BB"] - 2*Stats_dict[ID][dkey]["SO"])/Stats_dict[ID][dkey]["IP"]) + 3.1,digits=3)
                        Stats_dict[ID][dkey]["DICE"] = round(((13*Stats_dict[ID][dkey]["HR"] + 3*(Stats_dict[ID][dkey]["BB"]+Stats_dict[ID][dkey]["HBP"]) - 2*Stats_dict[ID][dkey]["SO"])/Stats_dict[ID][dkey]["IP"]) + 3,digits=3)
                    else
                        Stats_dict[ID][dkey]["WHIP"] = 0
                        Stats_dict[ID][dkey]["ERA"] = 0
                        Stats_dict[ID][dkey]["K/9"] = 0
                        Stats_dict[ID][dkey]["FIP"] = 0
                        Stats_dict[ID][dkey]["DICE"] = 0
                    end
                else
                    #Gets the stats for any other postion 
                    if D_stats["Outs Per Position"] == []
                        Stats_dict[ID][dkey]["PO"] = 0
                    elseif haskey(D_stats["Outs Per Position"][1],key)
                        Stats_dict[ID][dkey]["PO"] = D_stats["Outs Per Position"][1][key]
                    else
                        Stats_dict[ID][dkey]["PO"] = 0
                    end
                    Stats_dict[ID][dkey]["OutsPP"] = D_stats["Batter Outs Per Position"][1][dkey]
                    Stats_dict[ID][dkey]["BF"] = D_stats["Batters Per Position"][1][dkey]
                    Stats_dict[ID][dkey]["GP"] = 1
                    #Calulates Innings played stat in decimal form, where 1 out = .1 and 2 outs = .2
                    Stats_dict[ID][dkey]["INN"] = div(Stats_dict[ID][dkey]["OutsPP"],3) + (Stats_dict[ID][dkey]["OutsPP"]%3)/10
                end
            end
        end
    end
    return Stats_dict
end

function get_all_games(Path::AbstractString,RIO_ID::AbstractString)

    #Makes a empth dict for all characters and all stats to be filled in later
    #File goes, character name -> superstar state -> Offensive -> stat name -> stat value or 
    #File goes, character name -> superstar state -> Defensive -> Position -> stat name -> stat value
    #File also at the character level has a "Team" call that hops "GP","W","L" and "Pct"
    User_stats = Dict{AbstractString,Any}()
    User_stats["Team"] = Dict{AbstractString,Any}()
    for stat in ["GP","W","L","D","Pct"]
        User_stats["Team"][stat] = 0
    end
    for char in names
        User_stats[char] = Dict{Int,Dict{AbstractString,Dict{AbstractString,Any}}}()
        for SuperS in 0:1
        User_stats[char][SuperS] = Dict{AbstractString,Dict{AbstractString,Any}}()
            for key in ["O_Stats","D_Stats"]
                User_stats[char][SuperS][key] = Dict{AbstractString,Any}()
            end
            for stat in O_stats_name
                User_stats[char][SuperS]["O_Stats"][stat] = 0
            end
            User_stats[char][SuperS]["D_Stats"]["BigPlays"] = 0
            for pos in Positions
                User_stats[char][SuperS]["D_Stats"][pos] = Dict{AbstractString,Any}()
                if pos == "P"
                    for stat in P_stats_name
                        User_stats[char][SuperS]["D_Stats"][pos][stat] = 0
                    end
                else
                    for stat in D_stats_name
                        User_stats[char][SuperS]["D_Stats"][pos][stat] = 0
                    end
                end
            end
        end
    end
    # User_stats["Total"] = Dict{Int,Dict{AbstractString,Dict{AbstractString,Any}}}()
    # for SuperS in 0:1
    #     User_stats["Total"][SuperS] = Dict{AbstractString,Dict{AbstractString,Any}}()
    #     for key in ["O_Stats","D_Stats"]
    #         User_stats["Total"][SuperS][key] = Dict{AbstractString,Any}()
    #     end
    #     for stat in O_stats_name
    #         User_stats["Total"][SuperS]["O_Stats"][stat] = 0
    #     end
    #     User_stats["Total"][SuperS]["D_Stats"]["BigPlays"] = 0
    #     for pos in Positions
    #         User_stats["Total"][SuperS]["D_Stats"][pos] = Dict{AbstractString,Any}()
    #         if pos == "P"
    #             for stat in P_stats_name
    #                 User_stats["Total"][SuperS]["D_Stats"][pos][stat] = 0
    #             end
    #         else
    #             for stat in D_stats_name
    #                 User_stats["Total"][SuperS]["D_Stats"][pos][stat] = 0
    #             end
    #         end
    #     end
    # end
    function Add_stats(User_stats::AbstractDict,game_dict::AbstractDict,char::AbstractString,SuperS::Int,alt_char::AbstractString=char)
        for stat in O_stats_name
            User_stats[alt_char][SuperS]["O_Stats"][stat] += game_dict[char]["O_Stats"][stat]
        end
        for pos in keys(game_dict[char]["D_Stats"])
            if pos == "P"
                for stat in P_stats_name
                    User_stats[alt_char][SuperS]["D_Stats"][pos][stat] += game_dict[char]["D_Stats"][pos][stat]
                end
            elseif pos == "BigPlays"
                User_stats[alt_char][SuperS]["D_Stats"][pos] += game_dict[char]["D_Stats"][pos]
            else
                for stat in D_stats_name
                    User_stats[alt_char][SuperS]["D_Stats"][pos][stat] += game_dict[char]["D_Stats"][pos][stat]
                end
            end
        end
        return User_stats
    end

    function add_game(GameLog::AbstractDict,game_stats::AbstractDict,game::AbstractString)
        #adds played games to the game log indexed by date and time
        # Date = game_stats["GameLog"]["Date"]
        # Time = game_stats["GameLog"]["Start Time"]
        # key = Date*" "*Time
        GameLog[game] = Dict{AbstractString,Any}()
        GameLog[game] = game_stats
        return GameLog
    end

    function Add_self_stats(User_stats::AbstractDict,char::AbstractString,SuperS::Int,alt_char::AbstractString=char)
        for stat in O_stats_name
            User_stats[alt_char][SuperS]["O_Stats"][stat] += User_stats[char][SuperS]["O_Stats"][stat]
        end
        for pos in keys(User_stats[char][SuperS]["D_Stats"])
            if pos == "P"
                for stat in P_stats_name
                    User_stats[alt_char][SuperS]["D_Stats"][pos][stat] += User_stats[char][SuperS]["D_Stats"][pos][stat]
                end
            elseif pos == "BigPlays"
                User_stats[alt_char][SuperS]["D_Stats"][pos] += User_stats[char][SuperS]["D_Stats"][pos]
            else
                for stat in D_stats_name
                    User_stats[alt_char][SuperS]["D_Stats"][pos][stat] += User_stats[char][SuperS]["D_Stats"][pos][stat]
                end
            end
        end
        return User_stats
    end

    #Iteratre through all games with given RIO_ID
    GameLog = Dict{AbstractString,Any}()
    Batter_ABS = Dict{AbstractString,Dict{Int,Any}}()
    Pitcher_Throws = Dict{AbstractString,Dict{Int,Any}}()
    for name in names
        Batter_ABS[name] = Dict{Int,Any}()
        Pitcher_Throws[name] = Dict{Int,Any}()
    end
    TIP = 0
    for game in readdir(Path)
        if contains(game, "decoded") && contains(game, ".json")
            src_path = joinpath(Path,game)
            game_stats,game_dict = single_game_stats(src_path,RIO_ID)
            #Skips game if RIO_ID did not participate in the game
            if game_stats == 0
                continue
            elseif game_dict["Events"][1]["Inning"] != 1
                continue
            elseif game_dict["Events"][1]["Inning"] == 1 && game_dict["Events"][1]["Away Score"] != 0 && game_dict["Events"][1]["Home Score"] != 0
                continue
            else 
                Batter_ABS,Pitcher_Throws, game_stats,IPPG = get_events_stats(Batter_ABS,Pitcher_Throws,game_stats,game_dict,RIO_ID)
                User_stats["Team"]["GP"] += 1
                if game_stats["GameLog"]["Home Player"] == RIO_ID
                    if game_stats["GameLog"]["Home Score"] > game_stats["GameLog"]["Away Score"]
                        User_stats["Team"]["W"] += 1
                    elseif game_stats["GameLog"]["Home Score"] == game_stats["GameLog"]["Away Score"]
                        User_stats["Team"]["D"] += 1
                    else
                        User_stats["Team"]["L"] += 1
                    end
                else
                    if game_stats["GameLog"]["Home Score"] < game_stats["GameLog"]["Away Score"]
                        User_stats["Team"]["W"] += 1
                    elseif game_stats["GameLog"]["Home Score"] == game_stats["GameLog"]["Away Score"]
                        User_stats["Team"]["D"] += 1
                    else
                        User_stats["Team"]["L"] += 1
                    end
                end
                #Appends stats from game_stats to User_stats
                RIO_stats = game_stats[RIO_ID]
                for char in keys(RIO_stats)
                    SuperS = pop!(RIO_stats[char]["O_Stats"], "SuperS")
                    User_stats = Add_stats(User_stats,RIO_stats,char,SuperS)
                end
            end
            GameLog = add_game(GameLog,game_stats,game)
            TIP += IPPG
        end
    end
    #Averages like character stats. first adds the to the team
    for char in ["Shy Guy", "Noki","Pianta","Koopa","Dry Bones","Magikoopa","Paratroopa","Bro","Toad"]
        User_stats[char] = Dict{Int,Dict{AbstractString,Dict{AbstractString,Any}}}()
        for SuperS in 0:1
        User_stats[char][SuperS] = Dict{AbstractString,Dict{AbstractString,Any}}()
            for key in ["O_Stats","D_Stats"]
                User_stats[char][SuperS][key] = Dict{AbstractString,Any}()
            end
            for stat in O_stats_name
                User_stats[char][SuperS]["O_Stats"][stat] = 0
            end
            User_stats[char][SuperS]["D_Stats"]["BigPlays"] = 0
            for pos in Positions
                User_stats[char][SuperS]["D_Stats"][pos] = Dict{AbstractString,Any}()
                if pos == "P"
                    for stat in P_stats_name
                        User_stats[char][SuperS]["D_Stats"][pos][stat] = 0
                    end
                else
                    for stat in D_stats_name
                        User_stats[char][SuperS]["D_Stats"][pos][stat] = 0
                    end
                end
            end
        end
    end
    for char in ["Shy Guy(R)","Shy Guy(B)","Shy Guy(Y)","Shy Guy(G)","Shy Guy(Bk)"]
        for SuperS in 0:1
            User_stats = Add_self_stats(User_stats,char,SuperS,"Shy Guy")
        end
    end
    for char in ["Noki(R)","Noki(G)","Noki(B)"]
        for SuperS in 0:1
            User_stats = Add_self_stats(User_stats,char,SuperS,"Noki")
        end
    end
    for char in ["Pianta(B)","Pianta(R)","Pianta(Y)"]
        for SuperS in 0:1
            User_stats = Add_self_stats(User_stats,char,SuperS,"Pianta")
        end
    end
    for char in ["Koopa(R)","Koopa(G)"]
        for SuperS in 0:1
            User_stats = Add_self_stats(User_stats,char,SuperS,"Koopa")
        end
    end
    for char in ["Dry Bones(Gy)","Dry Bones(R)","Dry Bones(G)","Dry Bones(B)"]
        for SuperS in 0:1
            User_stats = Add_self_stats(User_stats,char,SuperS,"Dry Bones")
        end
    end
    for char in ["Magikoopa(R)","Magikoopa(G)","Magikoopa(B)","Magikoopa(Y)"]
        for SuperS in 0:1
            User_stats = Add_self_stats(User_stats,char,SuperS,"Magikoopa")
        end
    end
    for char in ["Paratroopa(R)","Paratroopa(G)"]
        for SuperS in 0:1
            User_stats = Add_self_stats(User_stats,char,SuperS,"Paratroopa")
        end
    end
    for char in ["Bro(F)","Bro(B)","Bro(H)"]
        for SuperS in 0:1
            User_stats = Add_self_stats(User_stats,char,SuperS,"Bro")
        end
    end
    for char in ["Toad(R)","Toad(B)","Toad(Y)","Toad(G)","Toad(P)"]
        for SuperS in 0:1
            User_stats = Add_self_stats(User_stats,char,SuperS,"Toad")
        end
    end
    for char in names
        for SuperS in 0:1
            User_stats = Add_self_stats(User_stats,char,SuperS,"Total")
        end
    end
    INN = 0
    for key in keys(GameLog)
        INN += GameLog[key]["GameLog"]["GL"]
    end
    #Calulates BA, SLG, OBP, OPS for each character and each superstar state
    for char in keys(User_stats)
        if char == "Team"
            continue
        else    
            User_stats = calc_stats(User_stats,char)
        end
    end
    if User_stats["Team"]["GP"] != 0
        User_stats["Team"]["Pct"] = round(User_stats["Team"]["W"]/User_stats["Team"]["GP"],digits=3)
    else
        User_stats["Team"]["Pct"] = 0
    end
    for SS in 0:1
        User_stats["Total"][SS]["O_Stats"]["GP"] = User_stats["Team"]["GP"]
        for pos in Positions
            if pos == "P"
                User_stats["Total"][SS]["D_Stats"][pos]["GP"] = User_stats["Team"]["GP"]
                User_stats["Total"][SS]["D_Stats"][pos]["IP"] = div(TIP,3) + (TIP%3)/10
            else
                User_stats["Total"][SS]["D_Stats"][pos]["GP"] = User_stats["Team"]["GP"]
                User_stats["Total"][SS]["D_Stats"][pos]["INN"] = INN
            end
        end
    end
    #Returns. tuple of the users full stats, log of all games, teams AB's,Pitchers throws
    return User_stats,GameLog,Batter_ABS,Pitcher_Throws
end

function calc_stats(User_stats::AbstractDict,char::AbstractString)
    for key in keys(User_stats[char])
        O_stats = User_stats[char][key]["O_Stats"]
        D_stats = User_stats[char][key]["D_Stats"]
        #Skips if no AB to avoid division by zero, but still calculates OBP if there are BB, HBP, or SF
        if O_stats["AB"] != 0

        User_stats[char][key]["O_Stats"]["BA"] = round(O_stats["H"]/O_stats["AB"],digits=3)
        User_stats[char][key]["O_Stats"]["SLG"] = round((O_stats["H"] + O_stats["2B"] + 2*O_stats["3B"] + 3*O_stats["HR"])/(O_stats["AB"]),digits=3)
        User_stats[char][key]["O_Stats"]["OBP"] = round((O_stats["H"]+O_stats["BB"]+O_stats["HBP"])/(O_stats["AB"]+O_stats["BB"]+O_stats["HBP"]+O_stats["SF"]),digits=3)

        elseif O_stats["AB"] == 0 && ( O_stats["BB"] != 0 || O_stats["HBP"] != 0 || O_stats["SF"] != 0)
                
        User_stats[char][key]["O_Stats"]["BA"] = 0
        User_stats[char][key]["O_Stats"]["SLG"] = 0
        User_stats[char][key]["O_Stats"]["OBP"] = round((O_stats["H"]+O_stats["BB"]+O_stats["HBP"])/(O_stats["AB"]+O_stats["BB"]+O_stats["HBP"]+O_stats["SF"]),digits=3)

        else

        User_stats[char][key]["O_Stats"]["BA"] = 0
        User_stats[char][key]["O_Stats"]["SLG"] = 0
        User_stats[char][key]["O_Stats"]["OBP"] = 0

        end

        User_stats[char][key]["O_Stats"]["OPS"] = round(O_stats["SLG"] + O_stats["OBP"],digits=3)

        for pos in Positions
            if pos == "P"
                OutsPP = pop!(D_stats[pos],"OutsPP")
                User_stats[char][key]["D_Stats"][pos]["IP"] = div(OutsPP,3) + (OutsPP%3)/10
                #Calulates pitching stats so long as IP is not zero
                if User_stats[char][key]["D_Stats"][pos]["IP"] != 0
                    User_stats[char][key]["D_Stats"][pos]["WHIP"] = round((D_stats[pos]["BB"] + D_stats[pos]["H"])/D_stats[pos]["IP"],digits=3)
                    User_stats[char][key]["D_Stats"][pos]["ERA"] = round((D_stats[pos]["ER"]/D_stats[pos]["IP"])*9,digits=3)
                    User_stats[char][key]["D_Stats"][pos]["K/9"] = round((D_stats[pos]["SO"]/D_stats[pos]["IP"])*9,digits=3)
                    User_stats[char][key]["D_Stats"][pos]["FIP"] = round(((13*D_stats[pos]["HR"] + 3*D_stats[pos]["BB"] - 2*D_stats[pos]["SO"])/D_stats[pos]["IP"]) + 3.1,digits=3)
                    User_stats[char][key]["D_Stats"][pos]["DICE"] = round(((13*D_stats[pos]["HR"] + 3*(D_stats[pos]["BB"] + D_stats[pos]["HBP"]) - 2*D_stats[pos]["SO"])/D_stats[pos]["IP"]) + 3,digits=3)
                else
                    User_stats[char][key]["D_Stats"][pos]["WHIP"] = 0
                    User_stats[char][key]["D_Stats"][pos]["ERA"] = 0
                    User_stats[char][key]["D_Stats"][pos]["K/9"] = 0
                    User_stats[char][key]["D_Stats"][pos]["FIP"] = 0
                    User_stats[char][key]["D_Stats"][pos]["DICE"] = 0
                end
            else
                OutsPP = pop!(D_stats[pos],"OutsPP")
                User_stats[char][key]["D_Stats"][pos]["INN"] = div(OutsPP,3) + (OutsPP%3)/10
            end
        end
    end
    return User_stats
end

function Collect_Stats(Path::AbstractString,RIO_ID::AbstractString,)
    #Collects all stats for a given RIO_ID and exports them into Json files
    User_stats,GameLog,Batter_ABS,Pitcher_Throws = get_all_games(Path,RIO_ID)
    if !isdir("Stats/$RIO_ID")
        mkpath("Stats/$RIO_ID") 
    end
    open("Stats/$RIO_ID/Team_stats.json","w") do file
        JSON3.pretty(file,User_stats)
    end
    open("Stats/$RIO_ID/GameLogs.json","w") do file
        JSON3.pretty(file,GameLog)
    end
    open("Stats/$RIO_ID/Batting_data.json","w") do file
        JSON3.pretty(file,Batter_ABS)
    end
    open("Stats/$RIO_ID/Pitch_data.json","w") do file
        JSON3.pretty(file,Pitcher_Throws)
    end
    return User_stats,GameLog,Batter_ABS,Pitcher_Throws
end

function get_events_stats(Batter_ABS::AbstractDict,Pitcher_Throws::AbstractDict,game_stats::AbstractDict,game_dict::AbstractDict,RIO_ID::AbstractString)
    #function to get all at bats abd balls pitched by the team
    Events = game_dict["Events"]
    #makes dict's to store data
    Alt_ID = collect(keys(game_stats))
    filter!(x -> x != RIO_ID && x != "GameLog", Alt_ID)
    Alt_ID = Alt_ID[1]
    max = length(Events)
    AB = Dict{AbstractString,Any}()
    Throw = Dict{AbstractString,Any}()
    for i in keys(Events) #run through all events
        # display("Event: $(i-1)")
        # display("Home: $(game_stats["GameLog"]["H_R"])")
        # display("Away: $(game_stats["GameLog"]["A_R"])")
        if haskey(Events[i],"Pitch") #if a ball was pitched, get its info
            inn = Events[i]["Inning"]
            hinn = Events[i]["Half Inning"]
            Throw,AB,batter,pitcher = get_throw_data(Events[i],Throw,AB,hinn,game_dict)
            #appends data to the pitchers log
            key = length(Pitcher_Throws[pitcher]) +1
            Pitcher_Throws[pitcher][key] = Throw
            if Events[i]["Result of AB"] != "None" #since AB's can only result of pitched balls we now check to make sure we swung or not
                AB,game_stats = get_AB_data(Events,Throw,AB,game_stats,RIO_ID,Alt_ID,hinn,inn,batter,pitcher,max,i)
            #appends data to the batters log
            key = length(Batter_ABS[batter]) +1
            Batter_ABS[batter][key] = AB
            end
        end
        AB = Dict{AbstractString,Any}()
        Throw = Dict{AbstractString,Any}()
    end
    for key in keys(game_stats)
        if key == "GameLog"
            continue
        else
            if game_stats["GameLog"]["Home Player"] == key
                for char in keys(game_stats[key])
                    game_stats["GameLog"]["Home H"] += game_stats[key][char]["O_Stats"]["H"]
                end
            else
                for char in keys(game_stats[key])
                    game_stats["GameLog"]["Away H"] += game_stats[key][char]["O_Stats"]["H"]
                end
            end
        end
    end
    if RIO_ID == game_dict["Away Player"] && Events[max]["Half Inning"] == 1
        GL = game_dict["Innings Selected"]-1
        LIOP = Events[max]["Outs"] + Events[max]["Num Outs During Play"]
        IPPG = GL*3 + LIOP
    elseif RIO_ID == game_dict["Home Player"] && Events[max]["Half Inning"] == 0
        GL = game_dict["Innings Selected"]-1
        LIOP = 0
        IPPG = GL*3 + LIOP
    else
        IPPG = game_dict["Innings Selected"]*3
    end
    return Batter_ABS,Pitcher_Throws,game_stats, IPPG
end

function get_throw_data(Event::AbstractDict,Throw::AbstractDict,AB::AbstractDict,hinn::Int,game_dict::AbstractDict)
    if hinn == 0
        batter = Event["Runner Batter"]["Runner Char Id"]
        pitcher = Event["Pitch"]["Pitcher Char Id"]
        for char in 0:8
            if game_dict["Character Game Stats"]["Home Roster $char"]["CharID"] == pitcher
                Throw["Pitch Hand"] = game_dict["Character Game Stats"]["Home Roster $char"]["Fielding Hand"]
                AB["Pitch Hand"] = game_dict["Character Game Stats"]["Home Roster $char"]["Fielding Hand"]
                break
            elseif game_dict["Character Game Stats"]["Away Roster $char"]["CharID"] == batter
                AB["Bat Hand"] = game_dict["Character Game Stats"]["Away Roster $char"]["Batting Hand"]
                Throw["Bat Hand"] = game_dict["Character Game Stats"]["Away Roster $char"]["Batting Hand"]
                break
            end
        end
    else
        batter = Event["Runner Batter"]["Runner Char Id"]
        pitcher = Event["Pitch"]["Pitcher Char Id"]
        for char in 0:8
            if game_dict["Character Game Stats"]["Home Roster $char"]["CharID"] == batter
                Throw["Bat Hand"] = game_dict["Character Game Stats"]["Home Roster $char"]["Fielding Hand"]
                AB["Bat Hand"] = game_dict["Character Game Stats"]["Home Roster $char"]["Fielding Hand"]
                break
            elseif game_dict["Character Game Stats"]["Away Roster $char"]["CharID"] == pitcher
                Throw["Pitch Hand"] = game_dict["Character Game Stats"]["Away Roster $char"]["Batting Hand"]
                AB["Pitch Hand"] = game_dict["Character Game Stats"]["Away Roster $char"]["Batting Hand"]
                break
            end
        end
    end
    Throw["PT"] = Event["Pitch"]["Pitch Type"]
    Throw["CT"] = Event["Pitch"]["Charge Type"]
    Throw["ST"] = Event["Pitch"]["Star Pitch"]
    Throw["BC-X"] = Event["Pitch"]["Bat Contact Pos - X"]
    Throw["BC-Z"] = Event["Pitch"]["Bat Contact Pos - Z"]
    Throw["PS"] = Event["Pitch"]["Pitch Speed"]
    Throw["Erg"] = Event["Pitcher Stamina"]
    Throw["K"] = Event["Pitch"]["In Strikezone"]
    Throw["Chem Links"] = Event["Chemistry Links on Base"]
    Throw["Pos"] = Event["Pitch"]["Ball Position - Strikezone"]
    Throw["Swing Type"] = Event["Pitch"]["Type of Swing"]
    Throw["Batter"] = batter
    return Throw,AB,batter,pitcher
end

function get_AB_data(Events,Throw::AbstractDict,AB::AbstractDict,game_stats::AbstractDict,RIO_ID::AbstractString,Alt_ID::AbstractString,hinn::Int,inn::Int,batter::AbstractString,pitcher::AbstractString,max::Int,i::Int)
    AB["Result"] = Events[i]["Result of AB"]
    if haskey(game_stats[RIO_ID],batter)
        USER = RIO_ID
    else
        USER = Alt_ID
    end
    if AB["Result"] in ["Single","Double","Triple","HR"]
        AB["Hit"] =1
    else
        AB["Hit"] = 0
    end
    AB["Pitcher"] = pitcher
    function base_add_data(game_stats::AbstractDict,batter::AbstractString,hinn::Int,inn::Int,USER::AbstractString)
        game_stats[USER][batter]["O_Stats"]["R"] += 1
        if hinn == 0
            game_stats["GameLog"]["BoxScore"][inn]["A"] += 1
            game_stats["GameLog"]["A_R"] += 1
        else
            game_stats["GameLog"]["BoxScore"][inn]["H"] += 1
            game_stats["GameLog"]["H_R"] += 1
        end 
    end

    if AB["Result"] == "HR" && Events[i]["Runner Batter"]["Runner Result Base"] == 0
        base_add_data(game_stats,batter,hinn,inn,USER)
        if haskey(Events[i],"Runner 1B")
            AB["1B"] = 1
            base_add_data(game_stats,Events[i]["Runner 1B"]["Runner Char Id"],hinn,inn,USER)
        end
        if haskey(Events[i],"Runner 2B")
            AB["2B"] = 1
            base_add_data(game_stats,Events[i]["Runner 2B"]["Runner Char Id"],hinn,inn,USER)
        end
        if haskey(Events[i],"Runner 3B")
            AB["3B"] = 1
            base_add_data(game_stats,Events[i]["Runner 3B"]["Runner Char Id"],hinn,inn,USER)
        end
    elseif AB["Result"] in ["Single","Double","Triple","HR"]
        if Events[i]["Runner Batter"]["Runner Result Base"] == 4
            base_add_data(game_stats,batter,hinn,inn,USER)
        end
        if haskey(Events[i],"Runner 1B")
            AB["1B"] = 1
            if Events[i]["Runner 1B"]["Runner Result Base"] == 4
                base_add_data(game_stats,Events[i]["Runner 1B"]["Runner Char Id"],hinn,inn,USER)
            end
        end
        if haskey(Events[i],"Runner 2B")
            AB["2B"] = 1
            if Events[i]["Runner 2B"]["Runner Result Base"] == 4
                base_add_data(game_stats,Events[i]["Runner 2B"]["Runner Char Id"],hinn,inn,USER)
            end
        end
        if haskey(Events[i],"Runner 3B")
            AB["3B"] = 1
            if Events[i]["Runner 3B"]["Runner Result Base"] == 4
                base_add_data(game_stats,Events[i]["Runner 3B"]["Runner Char Id"],hinn,inn,USER)
            end
        end
    elseif AB["Result"] in ["Walk (HBP)","Walk (BB)"]
        if haskey(Events[i],"Runner 1B")
            AB["1B"] = 1
        end
        if haskey(Events[i],"Runner 2B")
            AB["2B"] = 1
        end
        if haskey(Events[i],"Runner 3B")
            AB["3B"] = 1
        end
        if haskey(Events[i],"Runner 1B") && haskey(Events[i],"Runner 2B") && haskey(Events[i],"Runner 3B")
            base_add_data(game_stats,Events[i]["Runner 3B"]["Runner Char Id"],hinn,inn,USER)
        end
    elseif i == max
        if hinn == 0 && game_stats["GameLog"]["A_R"] < game_stats["GameLog"]["Away Score"]
            display("MISSING AWAY RUN")
        elseif hinn == 1 && game_stats["GameLog"]["H_R"] < game_stats["GameLog"]["Home Score"]
            display("MISSING HOME RUN")
        elseif (Events[i]["Outs"] == 2 && Events[i]["Num Outs During Play"] == 1) || (Events[i]["Outs"] == 1 && Events[i]["Num Outs During Play"] == 2) || (Events[i]["Outs"] == 0 && Events[i]["Num Outs During Play"] == 3)
        else
            display(path)
        end
        #Check total runs vs runs found if there is a discrepancy, give a run to the batter and base runner accordingly
    else  
        if Events[i]["Runner Batter"]["Runner Result Base"] == 4 && hinn == 0 && Events[i]["Away Score"] < Events[i+1]["Away Score"]
            game_stats["GameLog"]["BoxScore"][inn]["A"] += 1
            game_stats["GameLog"]["A_R"] += 1
            game_stats[USER][batter]["O_Stats"]["R"] += 1
        elseif Events[i]["Runner Batter"]["Runner Result Base"] == 4 && hinn == 1 && Events[i]["Home Score"] < Events[i+1]["Home Score"]
            game_stats["GameLog"]["BoxScore"][inn]["H"] += 1
            game_stats["GameLog"]["H_R"] += 1
            game_stats[USER][batter]["O_Stats"]["R"] += 1
        end
        if haskey(Events[i],"Runner 1B") && hinn == 0&& Events[i]["Runner 1B"]["Runner Result Base"] == 4 && Events[i]["Away Score"] < Events[i+1]["Away Score"]
            AB["1B"] = 1
            game_stats["GameLog"]["BoxScore"][inn]["A"] += 1
            game_stats["GameLog"]["A_R"] += 1
            game_stats[USER][Events[i]["Runner 1B"]["Runner Char Id"]]["O_Stats"]["R"] += 1
        elseif haskey(Events[i],"Runner 1B") && hinn == 1 && Events[i]["Runner 1B"]["Runner Result Base"] == 4 && Events[i]["Home Score"] < Events[i+1]["Home Score"]
            AB["1B"] = 1
            game_stats["GameLog"]["BoxScore"][inn]["H"] += 1
            game_stats["GameLog"]["H_R"] += 1
            game_stats[USER][Events[i]["Runner 1B"]["Runner Char Id"]]["O_Stats"]["R"] += 1
        end
        if haskey(Events[i],"Runner 2B") && hinn == 0&& Events[i]["Runner 2B"]["Runner Result Base"] == 4 && Events[i]["Away Score"] < Events[i+1]["Away Score"]
            AB["2B"] = 1
            game_stats["GameLog"]["BoxScore"][inn]["A"] += 1
            game_stats["GameLog"]["A_R"] += 1
            game_stats[USER][Events[i]["Runner 2B"]["Runner Char Id"]]["O_Stats"]["R"] += 1
        elseif haskey(Events[i],"Runner 2B") && hinn == 1 && Events[i]["Runner 2B"]["Runner Result Base"] == 4 && Events[i]["Home Score"] < Events[i+1]["Home Score"]
            AB["2B"] = 1
            game_stats["GameLog"]["BoxScore"][inn]["H"] += 1
            game_stats["GameLog"]["H_R"] += 1
            game_stats[USER][Events[i]["Runner 2B"]["Runner Char Id"]]["O_Stats"]["R"] += 1
        end
        if haskey(Events[i],"Runner 3B") && hinn == 0 && Events[i]["Runner 3B"]["Runner Result Base"] == 4 && Events[i]["Away Score"] < Events[i+1]["Away Score"]
            AB["3B"] = 1
            game_stats["GameLog"]["BoxScore"][inn]["A"] += 1
            game_stats["GameLog"]["A_R"] += 1
            game_stats[USER][Events[i]["Runner 3B"]["Runner Char Id"]]["O_Stats"]["R"] += 1
        elseif haskey(Events[i],"Runner 3B") && hinn == 1 && Events[i]["Runner 3B"]["Runner Result Base"] == 4 && Events[i]["Home Score"] < Events[i+1]["Home Score"]
            AB["3B"] = 1
            game_stats["GameLog"]["BoxScore"][inn]["H"] += 1
            game_stats["GameLog"]["H_R"] += 1
            game_stats[USER][Events[i]["Runner 3B"]["Runner Char Id"]]["O_Stats"]["R"] += 1
        end
    end
    AB["RBI"] = Events[i]["RBI"]
    AB["PErg"] = Throw["Erg"]
    AB["Chem Links"] = Throw["Chem Links"]
    AB["Balls"] = Events[i]["Balls"]
    AB["Strikes"] = Events[i]["Strikes"]
    if haskey(Events[i]["Pitch"],"Contact") #Checks to make sure we made contact 
        contact = Events[i]["Pitch"]["Contact"]
        AB["Contact"] = 1
        AB["Type"] = contact["Type of Contact"]
        AB["Ball Power"] = contact["Ball Power"]
        AB["Vert Angle"] = contact["Vert Angle"]
        AB["Horiz Angle"] = contact["Horiz Angle"]
        for coord in ["X","Y","X"]
            AB["velo $coord"] = contact["Ball Velocity - $coord"]
            AB["Landing $coord"] = contact["Ball Landing Position - $coord"]
        end
        AB["Con X"] = contact["Ball Contact Pos - X"]
        AB["Con Z"] = contact["Ball Contact Pos - Z"]
        AB["Frame"] = contact["Frame of Swing Upon Contact"]
        AB["Hang"] = contact["Ball Hang Time"]
        AB["Height"] = contact["Ball Max Height"]
        AB["Quality"] = contact["Contact Quality"]
        AB["CAbs"] = contact["Contact Absolute"]
        AB["Result"] = contact["Contact Result - Primary"]
        AB["Charge up"] = contact["Charge Power Up"]
        AB["Charge Down"] = contact["Charge Power Down"]
        AB["SSFS"] = contact["Star Swing Five-Star"]
    else #no contact? we return false to save room within the files
        AB["Contact"] = 0
    end
    return AB,game_stats
end


#get_json("Gobster9",P2="TubbaBlubba")
Collect_Stats("JSON_files/TEST","TubbaBlubba")
display("Done")

















# function get_AB_pitch(Batter_ABS::AbstractDict,Pitcher_Throws::AbstractDict,game_dict::AbstractDict,RIO_ID::AbstractString,Team::AbstractString)
#     #function to get all at bats abd balls pitched by the team
#     Events = game_dict["Events"]
#     #makes dict's to stroe data
#     for i in keys(Events) #run through all events
#         AB = Dict{AbstractString,Any}()
#         Throw = Dict{AbstractString,Any}()
#         if haskey(Events[i],"Pitch")#if a ball was pitched, get its info
#             batter = Events[i]["Runner Batter"]["Runner Char Id"]
#             pitcher = Events[i]["Pitch"]["Pitcher Char Id"]
#             if Events[i]["Half Inning"] == "0"
#                 for char in 0:8
#                     if game_dict["Character Game Stats"]["Home Roster $char"]["CharID"] == pitcher
#                         Throw["Pitch Hand"] = game_dict["Character Game Stats"]["Home Roster $char"]["Fielding Hand"]
#                         AB["Pitch Hand"] = game_dict["Character Game Stats"]["Home Roster $char"]["Fielding Hand"]
#                     end
#                     if game_dict["Character Game Stats"]["Away Roster $char"]["CharID"] == batter
#                         AB["Bat Hand"] = game_dict["Character Game Stats"]["Away Roster $char"]["Batting Hand"]
#                         Throw["Bat Hand"] = game_dict["Character Game Stats"]["Away Roster $char"]["Batting Hand"]
#                     end
#                 end
#             else
#                 for char in 0:8
#                     if game_dict["Character Game Stats"]["Home Roster $char"]["CharID"] == batter
#                         Throw["Bat Hand"] = game_dict["Character Game Stats"]["Home Roster $char"]["Fielding Hand"]
#                         AB["Bat Hand"] = game_dict["Character Game Stats"]["Home Roster $char"]["Fielding Hand"]
#                     end
#                     if game_dict["Character Game Stats"]["Away Roster $char"]["CharID"] == pitcher
#                         Throw["Pitch Hand"] = game_dict["Character Game Stats"]["Away Roster $char"]["Batting Hand"]
#                         AB["Pitch Hand"] = game_dict["Character Game Stats"]["Away Roster $char"]["Batting Hand"]
#                     end
#                 end
#             end
#             Throw["PT"] = Events[i]["Pitch"]["Pitch Type"]
#             Throw["CT"] = Events[i]["Pitch"]["Charge Type"]
#             Throw["ST"] = Events[i]["Pitch"]["Star Pitch"]
#             Throw["BC-X"] = Events[i]["Pitch"]["Bat Contact Pos - X"]
#             Throw["BC-Z"] = Events[i]["Pitch"]["Bat Contact Pos - Z"]
#             Throw["PS"] = Events[i]["Pitch"]["Pitch Speed"]
#             Throw["Erg"] = Events[i]["Pitcher Stamina"]
#             Throw["K"] = Events[i]["Pitch"]["In Strikezone"]
#             Throw["Chem Links"] = Events[i]["Chemistry Links on Base"]
#             Throw["Pos"] = Events[i]["Pitch"]["Ball Position - Strikezone"]
#             Throw["Swing Type"] = Events[i]["Pitch"]["Type of Swing"]
#             Throw["Batter"] = batter
#             #appends data to the pitchers log
#             key = length(Pitcher_Throws[pitcher]) +1
#             Pitcher_Throws[pitcher][key] = Throw
#             if Events[i]["Result of AB"] != "None" #since Ab's can only result of pitched balls we now check to make sure we swung or not
#                 AB["Result"] = Events[i]["Result of AB"]
#                 if AB["Result"] in ["Single","Double","Triple","HR"]
#                     AB["Hit"] =1
#                 else
#                     AB["Hit"] = 0
#                 end
#                 AB["Pitcher"] = pitcher
#                 if haskey(Events[i],"Runner 2B") || haskey(Events[i],"Runner 3B") #check if RISP was present or not 
#                     AB["RISP"] = 1
#                 else
#                     AB["RISP"] = 0
#                 end
#                 AB["RBI"] = Events[i]["RBI"]
#                 AB["PErg"] = Throw["Erg"]
#                 AB["Chem Links"] = Throw["Chem Links"]
#                 AB["Balls"] = Events[i]["Balls"]
#                 AB["Strikes"] = Events[i]["Strikes"]
#                 if haskey(Events[i]["Pitch"],"Contact") #Checks to make sure we made contact 
#                     contact = Events[i]["Pitch"]["Contact"]
#                     AB["Contact"] = 1
#                     AB["Type"] = contact["Type of Contact"]
#                     AB["Ball Power"] = contact["Ball Power"]
#                     AB["Vert Angle"] = contact["Vert Angle"]
#                     AB["Horiz Angle"] = contact["Horiz Angle"]
#                     for coord in ["X","Y","X"]
#                         AB["velo $coord"] = contact["Ball Velocity - $coord"]
#                         AB["Landing $coord"] = contact["Ball Landing Position - $coord"]
#                     end
#                     AB["Con X"] = contact["Ball Contact Pos - X"]
#                     AB["Con Z"] = contact["Ball Contact Pos - Z"]
#                     AB["Frame"] = contact["Frame of Swing Upon Contact"]
#                     AB["Hang"] = contact["Ball Hang Time"]
#                     AB["Height"] = contact["Ball Max Height"]
#                     AB["Quality"] = contact["Contact Quality"]
#                     AB["CAbs"] = contact["Contact Absolute"]
#                     AB["Result"] = contact["Contact Result - Primary"]
#                     AB["Charge up"] = contact["Charge Power Up"]
#                     AB["Charge Down"] = contact["Charge Power Down"]
#                     AB["SSFS"] = contact["Star Swing Five-Star"]
#                 else #no contact? we return false to save room within the files
#                     AB["Contact"] = 0
#                 end
#                 #appends data to the batters log
#             key = length(Batter_ABS[batter]) +1
#             Batter_ABS[batter][key] = AB
#             end
#         end
#         AB = 0
#         Throw = 0
#     end
#     return Batter_ABS,Pitcher_Throws
# end

# function get_AB_pitch_test(Batter_ABS::AbstractDict,Pitcher_Throws::AbstractDict,stat_file::AbstractString,RIO_ID::AbstractString)
#     #Checks if player was Home or Away
#     json_dict = JSON3.parsefile(stat_file)
#     Home_Player = json_dict["Home Player"]
#     if Home_Player == RIO_ID
#         get_AB_pitch(Batter_ABS,Pitcher_Throws,json_dict,RIO_ID,"Home")
#     else
#         get_AB_pitch(Batter_ABS,Pitcher_Throws,json_dict,RIO_ID,"Away")
#     end
# end


# function JSON_to_dict(stat_file::AbstractString)

#     #JSON file for game in form of dictionary
#     json_dict = JSON3.parsefile(stat_file)

#     return json_dict
# end