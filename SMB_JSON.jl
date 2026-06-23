using JSON3,JSONTables,DataFrames,Unicode,BenchmarkTools

const Stat_path = "C:/Users/elias/AppData/Roaming/Project Rio/StatFiles/MarioSuperstarBaseball/"

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

function single_game_stats(stat_file::AbstractString,RIO_ID::AbstractString)

    #JSON file for game in form of dictionary
    json_dict = JSON_to_dict(stat_file)

    if isequal_normalized(json_dict["Home Player"],RIO_ID,casefold=true)
        get_game_stats(json_dict,"Home")
    elseif isequal_normalized(json_dict["Away Player"],RIO_ID,casefold=true)
        get_game_stats(json_dict,"Away")
    else
        error("Given Player did not participate in this match")
    end

end

function get_game_stats(json_dict::AbstractDict,team::AbstractString)

    #New dictionary which holds calculated states for each player
    Stats_dict = Dict{AbstractString,Dict{AbstractString,Any}}()

    #Iterate over each $team Player
    for i in 0:8
        ID = json_dict["Character Game Stats"]["$team Roster $i"]["CharID"] #Char name

        Stats_dict[ID] = Dict{AbstractString,Any}() #Create a Key player using ID

        Stats_dict[ID]["SuperS"] = json_dict["Character Game Stats"]["$team Roster $i"]["Superstar"] #Check if Superstar was enabled on Char

        Stats_dict[ID]["F-hand"] = json_dict["Character Game Stats"]["$team Roster $i"]["Fielding Hand"]

        Stats_dict[ID]["B-hand"] = json_dict["Character Game Stats"]["$team Roster $i"]["Batting Hand"]

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

        elseif O_stats["At Bats"] == 0 && ( O_stats["Walks (4 Balls)"] != 0 || O_stats["Walks (Hit)"] != 0 || O_stats["Sac Flys"])
        
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

@btime single_game_stats("JSON_files/TubbaBlubba-Gobster9/decoded.20260618T220153_Gobster9-Vs-TubbaBlubba_2630012857.json","tubbablubba")

