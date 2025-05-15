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
    pos = pd.DataFrame(columns=["ID","x","y"])
    pos.loc[-1] = {"ID":0,"x":0,"y":0}
    pos = pos.reset_index(drop=True)

    def order_nodes(node, x, y):
        nonlocal pos
        all_children = list(main_connections.loc[main_connections["Predecessor"]==node]["Successor"])
        all_children.sort(key = lambda id: (type_order.index(quests.loc[quests["ID"]==id]["Type"].iloc[0]),
                                            list(main_connections["Predecessor"]).count(id),
                                            list(main_connections["Successor"]).count(id)
                                            ))
        i=-((len(all_children)-1)//2)
        for child in all_children[::2]+all_children[1::2][::-1]:
            child_x = x + 1
            child_y = y + i
            if child in list(pos["ID"]):
                if pos.loc[pos["ID"]==child]["x"].iloc[0] < x + 1:
                    while len(pos.loc[pos["x"]==child_x].loc[pos["y"]==child_y]) > 0 and child_y==y:
                        child_y = child_y + 1
                    pos.loc[pos["ID"]==child,"x"] = child_x
                    pos.loc[pos["ID"]==child,"y"] = child_y
                    order_nodes(child,x+1,y+i)
                    i+=1
            else:
                while len(pos.loc[pos["x"]==child_x].loc[pos["y"]==child_y]) > 0:
                    child_y = child_y + 1
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
                y = y - i*(-1)**i
                i+=1
        else:
            x = 0
            y = max(list(pos["y"]))+1

        pos.loc[-1] = {"ID":next_node,"x":x,"y":y}
        pos = pos.reset_index(drop=True)
        order_nodes(next_node,0,max(list(pos["y"]))+1)

    return pos
