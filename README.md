# TASC

TASC is a spell checker plugin for textadept.

Spell checking being performed via ispell compatible backend. (aspell and hunspell are supported at the moment)

## Installation

Clone the root of this repository to "${HOME}/.textadept/modules/textadept-spellchecker"
and put following line into your "${HOME}/.textadept/init.lua":
``` lua
require('textadept-spellchecker')
```

## Screenshots

<img src=https://pp.vk.me/c630828/v630828076/13311/vznRv4F45Zo.jpg>
<img src=https://pp.vk.me/c630828/v630828076/13318/LriCUvlQfck.jpg>
<img src=https://pp.vk.me/c630828/v630828076/1331f/Jji1QN24sFs.jpg>

## Features

| Feature                                             | Status              |
|----------------------------------------------------:|:--------------------|
| Basic highlighting of mistakes after file saving    | Done                |
| Suggestions via autocompletion interface            | Done                |
| Live checking support                               | Done                |
| GUI for backend and dictionary management           | Done                |
| Saving/Loading backend and dictionary configuration | Done                |
| Addition to personal dictionary support             | Done                |
| Localization                                        | en, ru, cs          |
| Localization for other languages                    | Assistance required |
| Windows/OSX support                                 | Assistance required |
