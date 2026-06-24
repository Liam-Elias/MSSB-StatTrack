using JSON3,JSONTables,DataFrames,Unicode,BenchmarkTools

const Stat_path = "/Users/joshfenwick/Desktop/MSSB_stat_tracker/MSSB-StatTrack"

const names = ["Mario","Monty","Baby Mario", "Luigi", "Baby Luigi", "Peach", "Daisy","Yoshi","Bowser","DK","Diddy","Dixie","Wario","Waluigi","Birdo","Bowser Jr","King Boo","Boo","Petey","Toadette","Toadsworth","Goomba","Paragoomba","Shy Guy(R)","Shy Guy(B)","Shy Guy(Y)","Shy Guy(G)","Shy Guy(Bk)","Noki(R)","Noki(G)","Noki(B)","Pianta(B)","Pianta(R)","Pianta(Y)","Koopa(R)","Koopa(G)","Dry Bones(Gy)","Dry Bones(R)","Dry Bones(G)","Dry Bones(B)","Magikoopa(R)","Magikoopa(G)","Magikoopa(B)","Magikoopa(Y)","Paratroopa(R)","Paratroopa(G)","Bro(F)","Bro(B)","Bro(H)","Toad(R)","Toad(B)","Toad(Y)","Toad(G)","Toad(P)"]

const O_stats_name = ["AB","H","HR","RBI","SB","2B","3B","K","BB","HBP","SF","PA","R"]

function get_json(P1::AbstractString; P2::AbstractString = nothing)

    #Check for existing JSON file folder and creates one if needed
    if isdir("./JSON_files/"*P1*"-"*P2)
        nothing
    else
        mkpath("./JSON_files/"*P1*"-"*P2)
    end

    #Iteratre through all files in source dir
    for file in readdir(Stat_path)
        src_path = joinpath(Stat_path,file)
        dest_path = joinpath("./JSON_files/"*P1*"-"*P2,file)

        if isnothig(P2)
            #Verify is a decoded JSON file and is a game containing Player 1 (RIO player Id's)
            if isfile(src_path) && endswith(lowercase(file), ".json") && contains(lowercase(file), lowercase("decoded")) && contains(lowercase(file), lowercase(P1)) && !contains(lowercase(file), lowercase(CPU))
                #Copy file if not currently in JSON_files dir or is newer version of file in JSON_files dir
                if !isfile(dest_path) || (mtime(src_path) > mtime(dest_path))
                    cp(src_path,dest_path; force=true)
                    println("Copied: $file")
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


function JSON_to_dict(stat_file::AbstractString)

    #JSON file for game in form of dictionary
    json_dict = JSON3.parsefile(stat_file)

    return json_dict
end

function single_game_stats(stat_file::AbstractString,RIO_ID::AbstractString,Partner_ID::AbstractString="All")

    #JSON file for game in form of dictionary
    json_dict = JSON3.parsefile(stat_file)
    Home_Player = json_dict["Home Player"]
    Away_Player = json_dict["Away Player"]
    if Partner_ID == "All"
        if isequal_normalized(Home_Player,RIO_ID,casefold=true)
            get_game_stats(json_dict,"Home")
        elseif isequal_normalized(Away_Player,RIO_ID,casefold=true)
            get_game_stats(json_dict,"Away")
        else
            return 0,0
        end
    else
        if isequal_normalized(Home_Player,RIO_ID,casefold=true) && isequal_normalized(Away_Player,Partner_ID,casefold=true)
            get_game_stats(json_dict,"Home")
        elseif isequal_normalized(Home_Player,Partner_ID,casefold=true) && isequal_normalized(Away_Player,RIO_ID,casefold=true)
            get_game_stats(json_dict,"Away")
        elseif !isequal_normalized(Home_Player,Partner_ID,casefold=true) && !isequal_normalized(Away_Player,Partner_ID,casefold=true)
            return 0,0
        else
            error("$RIO_ID did not participate in this match")
        end
    end
end

function get_game_stats(json_dict::AbstractDict,team::AbstractString)
    #Gets all stats for a single game separated by defensive stats and offensive stats for a given game, returns a dict with all characters and their stats
    Game_stats = Dict{AbstractString,Dict{AbstractString,Dict{AbstractString,Any}}}()
    Off_dict = get_offensive_stats(json_dict,team)
    Def_dict = get_defensive_stats(json_dict,team)
    for char in keys(Off_dict)
        Game_stats[char] = Dict{AbstractString,Dict{AbstractString,Any}}()
        Game_stats[char]["O_Stats"] = Off_dict[char]
        Game_stats[char]["D_Stats"] = Def_dict[char]
    end
        if team == "Home"
            if json_dict["Home Score"] > json_dict["Away Score"]
                win = 1
            else
                win = 0
            end
        else
            if json_dict["Away Score"] > json_dict["Home Score"]
                win = 1
            else
                win = 0
            end
        end
    return Game_stats,win
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

        Stats_dict[ID]["SB"] = O_stats["Bases Stolen"] 

        Stats_dict[ID]["2B"] = O_stats["Doubles"] 

        Stats_dict[ID]["3B"] = O_stats["Triples"] 

        Stats_dict[ID]["K"] = O_stats["Strikeouts"] 

        Stats_dict[ID]["BB"] = O_stats["Walks (4 Balls)"]

        Stats_dict[ID]["HBP"] = O_stats["Walks (Hit)"]
        
        Stats_dict[ID]["SF"] = O_stats["Sac Flys"]   

        Stats_dict[ID]["PA"] = Stats_dict[ID]["AB"] + Stats_dict[ID]["BB"] + Stats_dict[ID]["HBP"] + Stats_dict[ID]["SB"]

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

        #This part is a pain in the ass because runs scored by players is not kept track in player stats, so we have to search through events and identify them

        RS = 0

        for j in 1:json_dict["Events"][end]["Event Num"]+1  

            if true #json_dict["Events"][j]["RBI"] != 0 # only care about runs with non-zero RBI

                if json_dict["Events"][j]["Result of AB"] == "HR" # on HR starting base and ending base are same so have to check if current ID shows up anywhere
                   
                    if json_dict["Events"][j]["Runner Batter"]["Runner Char Id"] == ID
                        RS +=1
                    end
                    
                    if haskey(json_dict["Events"][j], "Runner 1B" )

                        if json_dict["Events"][j]["Runner 1B"]["Runner Char Id"] == ID
                            RS += 1
                        end
                    end

                    if haskey(json_dict["Events"][j], "Runner 2B" )

                        if json_dict["Events"][j]["Runner 2B"]["Runner Char Id"] == ID
                            RS += 1
                        end
                    end

                    if haskey(json_dict["Events"][j], "Runner 3B" )

                        if json_dict["Events"][j]["Runner 3B"]["Runner Char Id"] == ID
                            RS += 1
                        end
                    end

                end

                    
                
                #Check if Batter made it home and is the current charecter ID
                if json_dict["Events"][j]["Runner Batter"]["Runner Char Id"] == ID &&  json_dict["Events"][j]["Runner Batter"]["Runner Result Base"] == 4 
                    RS += 1
                end

                #Check if there was a 1st base man and if they made it home and is the current charecter ID
                if haskey(json_dict["Events"][j], "Runner 1B" )

                    if json_dict["Events"][j]["Runner 1B"]["Runner Char Id"] == ID &&  json_dict["Events"][j]["Runner 1B"]["Runner Result Base"] == 4
                        RS += 1
                    end
                end

                #Check if there was a 2nd base man and if they made it home and is the current charecter ID
                if haskey(json_dict["Events"][j], "Runner 2B" )

                    if json_dict["Events"][j]["Runner 2B"]["Runner Char Id"] == ID &&  json_dict["Events"][j]["Runner 2B"]["Runner Result Base"] == 4
                        RS += 1
                    end
                end

                #Check if there was a 3rd base man and if they made it home and is the current charecter ID
                if haskey(json_dict["Events"][j], "Runner 3B" )

                    if json_dict["Events"][j]["Runner 3B"]["Runner Char Id"] == ID &&  json_dict["Events"][j]["Runner 3B"]["Runner Result Base"] == 4
                        RS += 1
                    end
                end
            end
        end

        Stats_dict[ID]["R"] = RS
             
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
    return Stats_dict
end

function get_all_games(Path::AbstractString,RIO_ID::AbstractString,Partner_ID::AbstractString="All")

    #Makes a empth dict for all characters and all stats to be filled in later
    #File goes, character name -> superstar state -> Offensive vs Defensive -> stat name -> stat value
    Full_stats = Dict{AbstractString,Dict{Int,Dict{AbstractString,Dict{AbstractString,Any}}}}()
    for char in names
        Full_stats[char] = Dict{Int,Dict{AbstractString,Dict{AbstractString,Any}}}()
        Full_stats[char][0] = Dict{AbstractString,Dict{AbstractString,Any}}()
        Full_stats[char][1] = Dict{AbstractString,Dict{AbstractString,Any}}()
        Full_stats[char][0]["O_Stats"] = Dict{AbstractString,Any}()
        Full_stats[char][1]["O_Stats"] = Dict{AbstractString,Any}()
        for stat in O_stats_name
            Full_stats[char][0]["O_Stats"][stat] = 0
            Full_stats[char][1]["O_Stats"][stat] = 0
        end
    end

    wins = 0
    games = 0
    #Iteratre through all games with given RIO_ID or Partner_ID and add stats to Full_stats dict
    for game in readdir(Path)
        if contains(game, "decoded") && contains(game, ".json")
            src_path = joinpath(Path,game)
            game_stats = single_game_stats(src_path,RIO_ID,Partner_ID)[1]
            if single_game_stats(src_path,RIO_ID,Partner_ID)[2] == 1
                wins += 1
            end
            #Skips game if RIO_ID did not participate in the game or if Partner_ID was specified and did not participate in the game
            if game_stats == 0
                continue
            else 
                games += 1 
                #Appends stats from game_stats to Full_stats
                for char in keys(game_stats)
                    SuperS = pop!(game_stats[char]["O_Stats"], "SuperS")
                    for stat in O_stats_name
                        Full_stats[char][SuperS]["O_Stats"][stat] += game_stats[char]["O_Stats"][stat]
                    end
                end
            end
        end
    end
    #Calulates BA, SLG, OBP, OPS for each character and each superstar state
    for char in keys(Full_stats)
        for key in keys(Full_stats[char])
            stats = Full_stats[char][key]["O_Stats"]
            #Skips if no AB to avoid division by zero, but still calculates OBP if there are BB, HBP, or SF
            if stats["AB"] != 0

                Full_stats[char][key]["O_Stats"]["BA"] = round(stats["H"]/stats["AB"],digits=3)

                Full_stats[char][key]["O_Stats"]["SLG"] = round((stats["H"] + stats["2B"] + 2*stats["3B"] + 3*stats["HR"])/(stats["AB"]),digits=3)

                Full_stats[char][key]["O_Stats"]["OBP"] = round((stats["H"]+stats["BB"]+stats["HBP"])/(stats["AB"]+stats["BB"]+stats["HBP"]+stats["SF"]),digits=3)

            elseif stats["AB"] == 0 && ( stats["BB"] != 0 || stats["HBP"] != 0 || stats["SF"] != 0)
            
                Full_stats[char][key]["O_Stats"]["BA"] = 0

                 Full_stats[char][key]["O_Stats"]["SLG"] = 0

                 Full_stats[char][key]["O_Stats"]["OBP"] = round((stats["H"]+stats["BB"]+stats["HBP"])/(stats["AB"]+stats["BB"]+stats["HBP"]+stats["SF"]),digits=3)

            else

                 Full_stats[char][key]["O_Stats"]["BA"] = 0

                 Full_stats[char][key]["O_Stats"]["SLG"] = 0

                 Full_stats[char][key]["O_Stats"]["OBP"] = 0

            end
            Full_stats[char][key]["O_Stats"]["OPS"] = round(stats["SLG"] + stats["OBP"],digits=3)
        end
    end
    return Full_stats,games,wins
end


#single_game_stats("JSON_games/decoded.20260620T223211_Gobster9-Vs-TubbaBlubba_3669907432.json","Gobster9")

X = get_all_games("JSON_games","Gobster9")