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

    special = {412: (13, 5), 26: (12, -5), 414: (25, 4), 150: (24, 0), 25: (11, -9), 108: (8, 10), 8: (7, 10), 65: (12, -7), 28: (5, -2), 170: (7, -7), 308: (6, 3),
            83: (7, 8), 76: (7, 12), 105: (7, 11), 16: (8, 7), 33: (10, -1), 344: (24, -10), 17: (4, -1), 144: (11, -5), 24: (10, -9), 6: (5, 5), 307: (5, 1),
            306: (4, 1), 27: (4, 0), 5: (4, 2), 137: (5, -4), 196: (6, -5), 20: (7, -6), 19: (6, -3), 44: (19, 7), 310: (5, 2), 12: (5, 6), 311: (5, 3), 1: (2, 0),
            134: (6, -6), 29: (6, -4), 13: (6, 9), 7: (6, 8), 314: (6, 1), 124: (8, -4), 25: (11, -10), 120: (10, -7), 54: (26, 8), 309: (5, 4), 319: (5, 0), 4: (3, 0)}

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
