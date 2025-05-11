# %%
import requests
from bs4 import BeautifulSoup
import pandas as pd
import re
import numpy as np

# %%
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

len(links)

# %%
characters_tracked = ["Ciri","Yennefer","Triss","Dandelion","Dijkstra","Baron","Keira","Crach","Mousesack","Ermion","Eredin"]
regions = ["White Orchard","Velen","Novigrad","Skellige","Vizima","Kaer Morhen","Toussaint"]
other_regions = {"Kaedwen":"Kaer Morhen","Temeria":"Vizima","The Mire":"Velen","Harborside":"Novigrad",
                 "Ard Skellig":"Skellige","Crow's Perch":"Velen","The Descent":"Velen",
                 "Redania":"Novigrad","Spitfire Bluff":"Velen","Oxenfurt":"Novigrad",
                 "Grayrocks":"Velen","Gustfields":"Novigrad","Grassy Knoll":"Novigrad",
                 "Brunwich":"Novigrad","Deadwight Wood":"Novigrad"}

# %%
quests = pd.DataFrame(columns=["ID","Type","Name","Suggested Level","Max Exp"] + characters_tracked + regions)
connections = {}

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
    if name == "Next Quest":
        for next in tag.find_all('a'):
            if row["ID"] not in connections:
                connections[row["ID"]] = set()
            try:
                connections[row["ID"]].add(links.index(next.get("href")))
            except ValueError:
                queue.append(next.get("href"))
                links.append(next.get("href"))
                connections[row["ID"]].add(len(links) - 1)
    if name == "Previous Quest":
        for next in tag.find_all('a'):
            try: 
                predecessor = links.index(next.get("href"))
            except ValueError:
                queue.append(next.get("href"))
                links.append(next.get("href"))
                predecessor = len(links) - 1
            if predecessor not in connections:
                connections[predecessor] = set()
            connections[predecessor].add(row["ID"])

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
while len(queue) > 0:
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
        for character in characters_tracked:
            row[character] = int("".join([tag.prettify().lower() for tag in quest_soup.find('div',class_='mw-content-ltr mw-parser-output').find_all('p')]).count(character.lower()))
        if table.find('a',attrs={"href":"/wiki/Blood_and_Wine_quests"}):
            row["Toussaint"] = 1
        quests.loc[-1] = row
        quests = quests.reset_index(drop=True)
        i += 1
    except AttributeError:
        failed += 1

print(f"Failed: {failed}")
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
connections = pd.DataFrame({"Predecessor":[key for key in connections for value in connections[key]],"Successor":[value for key in connections for value in connections[key]]})

# %%
quests.to_csv("quests.csv",index=False)
connections.to_csv("connections.csv",index=False)


