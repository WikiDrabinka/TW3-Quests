# TW3-Quests
[Interactive version](https://wikidrabinka.shinyapps.io/TheWitcher3Quests/)

This is a dashboard designed for a quick analysis and tracking quests from The Witcher 3.

[data.py](data.py) contains a script I used for scraping the data from the fandom wiki and correcting it to make it usable. Data taken into consideration was: Name, type of the quest (main, secondary, contract, treasure hunt, unmarked), Suggested level, estimated rewarded EXP, region(s) and the number of times important characters appeared in the quest description.

The dashboard allows users to track completed quests and get recommendations for next quests to complete.

## Roadmap
- [x] Quest overview tab
    - [x] Quest summary
    - [x] Quests datatable
        - [x] Clickable
    - [x] Quest recommendation table
    - [ ] Quest progression graphs
- [ ] Story progression tab
    - [ ] Quest link map
        - [ ] Graph representation
        - [ ] Interactive map
        - [ ] Filtering
    - [ ] Graphs (TBD)
- [ ] Character analysis tab (TBD)