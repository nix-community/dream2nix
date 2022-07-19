# apt


```
result/bin/apt -o dir::state::status=$(realpath .)/status -o Dir::Etc=/etc/apt -o Dir::State=$(realpath .)/state update
```


```
-o Acquire::AllowInsecureRepositories=1
```
