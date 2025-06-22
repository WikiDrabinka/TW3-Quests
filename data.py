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
characters_tracked = ["Ciri","Yennefer","Triss","Dandelion","Dijkstra","Baron","Keira","Crach","Mousesack","Ermion","Eredin","Olgierd","Regis"]
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
            region_text = tag.find('div').text.strip()
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
    row[name] = tag.find('div').text.strip()
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
    if isinstance(predecessor, int):
        predecessors = [predecessor]
    else:
        predecessors = list(quests.loc[quests["Name"].apply(lambda name: re.match(f".*{predecessor}", name)).astype(bool)]["ID"])
    if isinstance(successor, int):
        successors = [successors]
    else:
        successors = list(quests.loc[quests["Name"].apply(lambda name: re.match(f".*{successor}", name)).astype(bool)]["ID"])
    global connections
    for predecessor in predecessors:
        for successor in successors:
            connections.loc[-1] = {"Predecessor" : predecessor, "Successor": successor}
            connections = connections.reset_index(drop=True)

def remove_connection(predecessor, successor):
    if isinstance(predecessor, int):
        predecessors = [predecessor]
    else:
        predecessors = list(quests.loc[quests["Name"].apply(lambda name: re.match(f".*{predecessor}", name)).astype(bool)]["ID"])
    if isinstance(successor, int):
        successors = [successors]
    else:
        successors = list(quests.loc[quests["Name"].apply(lambda name: re.match(f".*{successor}", name)).astype(bool)]["ID"])
    global connections
    for predecessor in predecessors:
        for successor in successors:
            connections.drop(connections.loc[connections["Predecessor"] == predecessor].loc[connections["Successor"] == successor].index,inplace=True)

to_add = [("Shadows", "Footsteps"), ("Fleeing", "Footsteps"), ("Speed", "Footsteps"), ("Passenger", "Footsteps"), ("Eternal", "Forgotten"), ("Poet", "Envoys"),
  ("Get Junior", "Visiting Junior"), ("Visiting Junior", "Reuven"), ("Elaine", "Mists"), ("Ugly", "Bait"), ("Imperial", "Evil"), ("Belgaard", "Deus"), ("Bald", "Three"), ("Imperial", "Fists of Fury: Velen"), ("Imperial", "Fists of Fury: Novigrad"), ("Imperial", "Fists of Fury: Skellige"), ("Sunstone", "Thin Ice"), ("Vigo", "Thin Ice")]
to_remove = [("Disturbance", "Bait"), ("Ugly", "Mists"), ("Imperial", "Footsteps"), ("Coronata", "Deus"), ("Deus", "Belgaard"), ("Consorting", "Belgaard"), ("All", "Big City"), ("Shakedown", "Feast"), ("Get Junior", "Play's"), ("Final Preparations", "Three"), ("Get Junior", "Plot"), ("Battle Preparations", "Thin Ice"), ("Evil", "Sesame!"), (0, "Lilac"), ("Get Junior", "Reuven"), ("Bald", "Final Preparations")]

for predecessor, successor in to_add:
  add_connection(predecessor, successor)

for predecessor, successor in to_remove:
  remove_connection(predecessor, successor)

for name in ["Blind", "Escape", "Payback", "Space"]:
    add_connection("Bald", name)
    add_connection(name, "Final Preparations")
    remove_connection("Final Preparations", name)

name = "Brothers In"
remove_connection("Mists", name)
add_connection("Elaine", name)
add_connection(name, "Mists")

name = "Sesame:"
remove_connection("Sesame!", name)
add_connection("Evil", name)
add_connection(name, "Sesame!")
    
name = "Orchard"
remove_connection("Lilac", name)
add_connection(0, name)
add_connection(name, "Lilac")
    
def set_completion(name, rate):
    global quests
    id = list(quests.loc[quests["Name"].apply(lambda quest_name: re.match(f".*{name}", quest_name)).astype(bool)]["ID"])[-1]
    quests.loc[quests["ID"] == id, "Completion Rate"] = rate
    
completion_rates = [("Lilac",0.619), ("Matters",0.388), ("Learning",0.352), ("Poet",0.317), ("Shrieker",0.316), ("Nameless",0.302), ("Coronation",0.257), ("Mists",0.256), ("Elusive",0.246), ("Space",0.244), ("Byways",0.23), ("Ends",0.229), ("Thin Ice",0.229), ("Beast of T",0.196), ("Evil",0.195), ("Missing Son",0.187), ("Soweth",0.17), ("Fury: Skellige",0.159), ("Reason",0.157), ("Champion",0.141), ("No Place",0.136), ("Heart of",0.13), ("Stakes",0.114), ("Fear",0.071), ("All",0.049)]

for name, rate in completion_rates:
  set_completion(name, rate)

# %%
quests.to_csv(output_path+"quests.csv",index=False)
connections.to_csv(output_path+"connections.csv",index=False)


