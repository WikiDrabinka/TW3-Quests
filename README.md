# TW3-Quests
[Interactive version](https://wikidrabinka.shinyapps.io/TheWitcher3Quests/)
(Might take a bit to load at first, do not worry!)

This is a dashboard designed for a quick analysis and tracking quests from The Witcher 3.

[data.py](data.py) contains a script I used for scraping the data from the fandom wiki and correcting it to make it usable. Data taken into consideration was: Name, type of the quest (main, secondary, contract, treasure hunt, unmarked), Suggested level, estimated rewarded EXP, region(s) and the number of times important characters appeared in the quest description.

The dashboard allows users to track completed quests and get recommendations for next quests to complete.

## Roadmap
- [X] Quest overview tab
    - [x] Quest summary
    - [x] Quests datatable
        - [x] Clickable
    - [x] Quest recommendation table
    - [X] Quest progression graphs
- [ ] Story progression tab
    - [X] Quest link map
        - [X] Graph representation
        - [X] Interactive map
        - [X] Filtering
    - [ ] Graphs
- [ ] About tab
    - [ ] Info
    - [ ] Quest status presets
- [X] CSS theme
- [ ] Gwent Cards