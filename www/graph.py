import pandas as pd
import plotly.express as px
import plotly.graph_objects as go

def main_graph(path):
    connections = pd.read_csv(path+"/www/connections.csv")
    quests = pd.read_csv(path+"/www/quests.csv")
    type_order = ["Main quest", "Secondary quest", "Contract quest", "Treasure hunt", "Unmarked quest"]
    main = quests.loc[quests["Type"]=="Main quest"]
    main_connections = connections.loc[connections.isin(list(main["ID"])).any(axis=1)]

    while (new_main := quests.loc[quests["ID"].isin(main_connections["Predecessor"]) | quests["ID"].isin(main_connections["Successor"])]).shape[0] > main.shape[0]:
        main = new_main
        main_connections = connections.loc[connections.isin(list(main["ID"])).any(axis=1)]
        
    def find_id(name):
        return list(quests.loc[quests["Name"].apply(lambda quest_name: re.match(f".*{name}", quest_name)).astype(bool)]["ID"])[0]

    special = {"Footsteps": (13, 5), "Speed": (12, -5), "Three": (23, 4), "Reason": (25, 0), "Poet": (11, -9), "Return": (8, 10), "Matters": (7, 10), "Pals": (12, -7), "Live": (5, -2), "Unpaid": (7, -7), "Sesame!": (6, 3), "Payback": (23, 9),
            "Room": (7, 8), "Greedy": (7, 12), "Lamp": (7, 11), "Fleeing": (8, 7), "Passenger": (10, -1), "Pomp": (24, -10), "Pyres": (4, -1), "Now or": (11, -5), "Play's": (10, -9), "Bloody": (5, 5), "Party": (5, 1), "Escape": (23, 8), "Blind": (23, 6),
            "Evil": (4, 1), "Destination": (4, 0), "The Nilfgaardian": (4, 2), "Stakes": (5, -4), "Dreams": (6, -5), "Get Junior": (7, -6), "Flowers": (6, -3), "Arms: Skellige": (18, 7), "Breaking": (5, 2), "Hunting": (5, 6), "Safecracker": (5, 3), "Lilac": (2, 0),
            "Haunted": (6, -6), "Echoes of": (6, -4), "Wandering": (6, 9), "Wolves": (6, 8), "Midnight": (6, 1), "Eye": (8, -4), "Matter of": (10, -7), "Seasonings": (5, 4), "Rose": (5, 0), "Imperial": (3, 0)}
            
    special = {find_id(name): special[name] for name in special.keys()}

    pos = pd.DataFrame(columns=["ID","x","y"])
    pos.loc[-1] = {"ID":0,"x":0,"y":0}
    pos = pos.reset_index(drop=True)

    def order_nodes(node, x, y):
        nonlocal pos, special
        all_children = list(main_connections.loc[main_connections["Predecessor"]==node]["Successor"])
        all_children.sort(key = lambda id: (id in special,
                                            type_order.index(quests.loc[quests["ID"]==id]["Type"].iloc[0]),
                                            list(main_connections["Predecessor"]).count(id),
                                            list(main_connections["Successor"]).count(id)
                                            ))
        i=-((len(all_children)-1)//2)
        for child in all_children[::2]+all_children[1::2][::-1]:
            if child in special:
                child_x = special[child][0]
                child_y = special[child][1]
                pos.loc[-1] = {"ID":child,"x":child_x,"y":child_y}
                pos = pos.reset_index(drop=True)
                order_nodes(child,child_x,child_y)
                continue
            child_x = x + 1
            child_y = y + i
            if child in list(pos["ID"]):
                if pos.loc[pos["ID"]==child]["x"].iloc[0] <= x + 1:
                    j = 1
                    while len(pos.loc[pos["x"]==child_x].loc[pos["y"]==child_y]) > 0:
                        child_y = child_y - j*(-1)**j
                        j += 1
                    pos.loc[pos["ID"]==child,"x"] = child_x
                    pos.loc[pos["ID"]==child,"y"] = child_y
                    order_nodes(child,child_x,child_y)
                    i+=1
            else:
                j = 1
                while len(pos.loc[pos["x"]==child_x].loc[pos["y"]==child_y]) > 0:
                    child_y = child_y - j*(-1)**j
                    j += 1
                pos.loc[-1] = {"ID":child,"x":child_x,"y":child_y}
                pos = pos.reset_index(drop=True)
                order_nodes(child,child_x,child_y)
                i+=1

    order_nodes(0,0,0)
    while len(set(main["ID"]) - set(pos["ID"])) > 0:
        i=0
        while i<len(set(main["ID"]) - set(pos["ID"])) and (next_node := (list(set(main["ID"]) - set(pos["ID"]))[0])) in main_connections["Successor"]:
            i+=1
        neighbours = [node for node in list(main_connections.loc[connections["Predecessor"] == next_node]["Successor"]) if node in list(pos["ID"])]
        if len(neighbours) > 0:
            successor = min(neighbours, key=lambda node: pos.loc[pos["ID"] == node]["x"].iloc[0])
            x = pos.loc[pos["ID"] == successor]["x"].iloc[0] - 1
            y = pos.loc[pos["ID"] == successor]["y"].iloc[0]
            i = 1
            while len(pos.loc[pos["x"]==x].loc[pos["y"]==y]) > 0:
                y = y - i*(-1)**(i+1)
                i+=1
        else:
            x = 0
            y = max(list(pos["y"]))+1

        pos.loc[-1] = {"ID":next_node,"x":x,"y":y}
        pos = pos.reset_index(drop=True)
        order_nodes(next_node,0,max(list(pos["y"]))+1)

    pos.drop(pos.loc[pos.duplicated()].index, inplace=True)

    return pos
