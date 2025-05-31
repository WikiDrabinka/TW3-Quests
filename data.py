# %%
import requests
from bs4 import BeautifulSoup
import pandas as pd
import re

# %%
output_path = "./www/"

main_path = "https://witcher.fandom.com"
main_links = ["/wiki/The_Witcher_3_main_quests","/wiki/The_Witcher_3_secondary_quests","/wiki/The_Witcher_3_contracts",
              "/wiki/The_Witcher_3_treasure_hunts","/wiki/Hearts_of_Stone_quests","/wiki/Blood_and_Wine_quests"]
soups = []
for main_link in main_links:
    soups.append(BeautifulSoup(requests.get(main_path + main_link).content,'html.parser'))

links = []
for soup in soups:
    for table in soup.find_all('tbody'):
        links.extend([el.find('a').get('href') for el in table.find_all('tr')[1:]])
del links[112]
# %%
characters_tracked = ["Ciri","Yennefer","Triss","Dandelion","Dijkstra","Baron","Keira","Crach","Mousesack","Ermion","Eredin","Regis"]
regions = ["White Orchard","Velen","Novigrad","Skellige","Vizima","Kaer Morhen","Toussaint"]
other_tracked = ["Gwent", "Fistfight", "Race", "Diagram"]
other_regions = {"Kaedwen":"Kaer Morhen","Temeria":"Vizima","The Mire":"Velen","Harborside":"Novigrad",
                 "Ard Skellig":"Skellige","Crow's Perch":"Velen","The Descent":"Velen",
                 "Redania":"Novigrad","Spitfire Bluff":"Velen","Oxenfurt":"Novigrad",
                 "Grayrocks":"Velen","Gustfields":"Novigrad","Grassy Knoll":"Novigrad",
                 "Brunwich":"Novigrad","Deadwight Wood":"Novigrad"}

# %%
quests = pd.DataFrame(columns=["ID","Type","Name","Suggested Level","Max Exp", "Completion Rate"] + characters_tracked + regions + other_tracked)
connections = pd.DataFrame(columns=["Predecessor","Successor"])

def process(tag, row: dict):

    global connections
    if not tag.find('h3'):
        return
    if (name := tag.find('h3').text) == "Region(s)":
        for region in regions:
            region_text = tag.findChild('div').text.strip()
            for replacement in other_regions:
                region_text = region_text.replace(replacement,other_regions[replacement])
            if region in region_text:
                row[region] = 1
            else:
                row[region] = 0
        return
    if name == "Previous Quest":
        for next in tag.find_all('a'):
            try: 
                predecessor = links.index(next.get("href"))
            except ValueError:
                queue.append(next.get("href"))
                links.append(next.get("href"))
                predecessor = len(links) - 1
            connections.loc[-1] = {"Predecessor": predecessor, "Successor": row["ID"]}
            connections = connections.reset_index(drop=True)
        return
    if name == "Next Quest":
        for next in tag.find_all('a'):
            if next.get("href") not in links:
                queue.append(next.get("href"))
                links.append(next.get("href"))
        return
    if name == "Reward(s)":
        def clear_exp(arg):
            if (isinstance(arg,int)):
                return arg
            if len(find := re.findall(r'[0-9]+[,]*[0-9]*',arg))>0:
                return int(find[0].replace(",",""))
            return 0
        row["Max Exp"] = 0
        for exp in tag.find_all('a', attrs = {"href":"/wiki/XP#The_Witcher_3:_Wild_Hunt"}):
            row["Max Exp"] = max(clear_exp((exp.previous.previous)), row["Max Exp"])
        return
    row[name] = tag.findChild('div').text.strip()
    return

queue = links.copy()
failed = 0
i = 0

print("Downloading 000/"+str(len(links))+" (00%)",end="",flush=True)
while len(queue) > 0:
    print("\b"*13+f"{i+1:03d}"+"/"+str(len(links))+" ("+f"{(i+1)*100//len(links):02d}"+"%)",end="",flush=True)
    try:
        link = queue.pop(0)
        quest_soup = BeautifulSoup(requests.get(main_path+link).content,'html.parser')
        table = quest_soup.find('aside')
        row = {"ID":i, "Name":table.find('h2').text.strip()}
        sections = table.find_all('section')
        for section in sections:
            info = section.find_all('div', recursive=False)
            for tag in info:
                process(tag, row)
        content = "".join([tag.text.lower() for tag in quest_soup.find('div',class_='mw-content-ltr mw-parser-output').find_all('p')]+
                                       [tag.text.lower() for tag in quest_soup.find('div',class_='mw-content-ltr mw-parser-output').find_all('i')])
        for character in characters_tracked:
            row[character] = len(list(re.findall(re.compile(" "+character.lower()+"[,. ]"), content)))
        for tracked in other_tracked:
            tracked_count = len(list(re.findall(re.compile(" "+tracked.lower()+"(ing)*[s,. ]"), content)))
            if tracked == "Race":
                tracked_count -= len(list(re.findall(r"race for", content)))
            row[tracked] = tracked_count > 0
        if table.find('a',attrs={"href":"/wiki/Blood_and_Wine_quests"}):
            row["Toussaint"] = 1
        elif re.search(r"Gwent.*",row["Name"]):
            connections.loc[-1] = {"Predecessor": row["ID"], "Successor": links.index("/wiki/Collect_%27Em_All")}
            connections = connections.reset_index(drop=True)
        quests.loc[-1] = row
        quests = quests.reset_index(drop=True)
        i += 1
    except AttributeError:
        failed += 1

print(f"\nFailed: {failed}")
quests

# %%
quests["Mousesack"] = quests["Mousesack"] + quests["Ermion"]
quests.drop(columns="Ermion",inplace=True)

# %%
quests.loc[quests.Toussaint.isna(), "Novigrad"] = 1

# %%
quests = quests.fillna(0)

# %%
def clear_level(arg):
    if isinstance(arg, int):
        return arg
    new_str = re.findall(r"[0-9]+",arg)
    if len(new_str) == 0:
        return 0
    else:
        return int(new_str[0])

quests["Suggested Level"] = quests["Suggested Level"].apply(clear_level)

# %%
quests["Max Exp"] = quests["Max Exp"].apply(int)
quests.rename(columns={"Max Exp":"Exp"},inplace=True)

# %%
def add_connection(predecessor, successor):
    global connections
    connections.loc[-1] = {"Predecessor" : predecessor, "Successor": successor}
    connections = connections.reset_index(drop=True)

def remove_connection(predecessor, successor):
    global connections
    connections.drop(connections.loc[connections["Predecessor"] == predecessor].loc[connections["Successor"] == successor].index,inplace=True)

to_add = [(11, 412), (16, 412), (26, 412), (33, 412), (100, 303), (25, 331), (20, 21), (21, 22), (39, 44), (34, 36), (4, 306), (382, 385), (47, 413), (4, 89), (4, 130), (4, 179), (54, 58), (55, 58)]
to_remove = [(35, 36), (34, 44), (4, 412), (384, 385), (385, 382), (383, 382), (62, 131), (156, 119), (20, 24), (48, 413), (20, 118), (53, 58), (306, 308), (0, 1)]

for predecessor, successor in to_add:
  add_connection(predecessor, successor)

for predecessor, successor in to_remove:
  remove_connection(predecessor, successor)

for id in range(49, 53):
    add_connection(47, id)
    add_connection(id, 48)
    remove_connection(48, id)

for id in range(40, 44):
    remove_connection(44, id)
    add_connection(39, id)
    add_connection(id, 44)
    
for id in range(309, 312):
    remove_connection(308, id)
    add_connection(306, id)
    add_connection(id, 308)
    
for id in range(2, 4):
    remove_connection(1, id)
    add_connection(0, id)
    add_connection(id, 1)
    
def set_completion(id, rate):
    global quests
    quests.loc[quests["ID"] == id, "Completion Rate"] = rate
    
completion_rates = [(1,0.619), (8,0.388), (91,0.352), (25,0.317), (225,0.316), (31,0.302), (174,0.257), (44,0.256), (232,0.246), (52,0.244), (230,0.23), (60,0.229), (58,0.229), (332,0.196), (306,0.195), (243,0.187), (313,0.17), (179,0.159), (150,0.157), (178,0.141), (366,0.136), (248,0.13), (137,0.114), (361,0.071), (62,0.049)]

for id, rate in completion_rates:
  set_completion(id, rate)

# %%
quests.to_csv(output_path+"quests.csv",index=False)
connections.to_csv(output_path+"connections.csv",index=False)


