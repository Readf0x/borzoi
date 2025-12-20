---
status: Open
priori: 1
assign: 
labels: 
author: readf0x
crdate: 2025-12-20T23:24:32-06:00
---
# Incorrect ids on commit
```sh
$ borzoi init
$ borzoi new
$ borzoi list
id    title                         status   creation date      
7DCD  Wrap when lines are too long  Open     2025-12-20 17:23:26
$ borzoi commit
[master 9bbbb1d] created issue: borz
 1 file changed, 8 insertions(+)
 create mode 100644 .borzoi/7DCD.md
```
