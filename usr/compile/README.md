# Compiling

Create a [nginx](https://github.com/boekkooi/openshift-cartridge-nginx) based app and clone the repo.
Create a folder php in the git repo.
Now copy the folder compile into this folder and commit and push.

Ssh into you application and run the following commands:
```BASH
cd ${OPENSHIFT_REPO_DIR}/php/compile
./libs
./php
./libs_package
```

Now the builds will be packaged and ready for download in your folder.

TODO :
- research replacing paths in include/php/main/build-defs.h
- research replacing paths in *.pc, *.la and *.inc files
