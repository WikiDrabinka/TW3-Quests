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

    special = {412: (12, 5), 26: (11, -5), 414: (24, 4), 150: (23, 0), 25: (10, -9), 108: (7, 10), 8: (6, 10), 65: (11, -7), 28: (4, -2), 170: (6, -7), 308: (5, 3),
            83: (6, 8), 76: (6, 12), 105: (6, 11), 16: (7, 7), 33: (9, -1), 344: (23, -10), 17: (3, -1), 144: (10, -5), 24: (9, -9), 6: (4, 5), 307: (4, 1),
            306: (3, 1), 27: (3, 0), 5: (3, 2), 137: (4, -4), 196: (5, -5), 20: (6, -6), 19: (5, -3), 44: (18, 7), 310: (4, 2), 12: (4, 6), 311: (4, 3),
            134: (5, -4), 29: (5, -4), 13: (5, 9), 7: (5, 8), 314: (5, 1), 124: (7, -4), 25: (10, -10), 120: (9, -7), 54: (25, 8), 309: (4, 4), 319: (4, 0)}

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
