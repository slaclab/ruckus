# Check the GIT status
build_time=`date +%Y%m%d%H%M%S`
repo_path=`git rev-parse --show-toplevel`
repo=`basename ${repo_path}`
#git update-index --refresh | sed -e 's/: needs update//g'

clean=`git status -s`
s=''

branch=`git branch --show-current`

# Check for non-dirty git clone
if [[ -z ${clean} ]] ;
then
   hash_long=`git rev-parse HEAD`
   hash_short=`git rev-parse --short HEAD`
   tag=`git describe --tags --abbrev=0 2>/dev/null`
   status=$?
   if [[ $status != "0" ]] ; then
       tag="None"
   fi

   s+="{ \"Repo\"      : \"${repo}\",
         \"Dirty\"     : False,
         \"Branch\"    : \"${branch}\",
         \"HashLong\"  : \"${hash_long}\",
         \"HashShort\" : \"${hash_short}\",
         \"HashMsg\"   : \"${hash_long}\",
         \"Tag\"       : \"${tag}\" }"
else
   s+="{ \"Repo\"      : \"${repo}\",
         \"Dirty\"     : True,
         \"Branch\"    : \"${branch}\",
         \"HashLong\"  : None,
         \"HashShort\" : None,
         \"HashMsg\"   : \"Dirty\",
         \"Tag\"       : None }"
fi

echo -e $s
