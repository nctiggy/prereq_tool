# prereq_tool

Run directly from the command line
```
bash <(curl -fsSL https://raw.githubusercontent.com/nctiggy/prereq_tool/main/run.sh) --use-repo-tools --tool-pack pcg -y
```

Prereq tool. Check for installed software.

Options:
  
  [ --tools | -t ]      Specify tools yaml file location
  
  [ --use-repo-tools ]  Use the default tools.yaml in the main repo

  [ --tool-pack | -tp ] Specify tool pack you want to install
  
  [ --accept | -y ]     Auto install unmet pre-reqs. No prompts
  
  [ --help | -h ]       Print this help message
