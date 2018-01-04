if [ -z $1 ]; then
    echo "Usage: " $0 [COMPILER_NAME]
    exit
fi

####################################################################################################
# Pre-parsing of parameters

# Get a using compiler
COMPILER=$1
COMPILER_REPLY=`$COMPILER -Wp,-v -x c++ - <<< "" -fsyntax-only 2>&1`
shift

# Get a command that will be executed after build include-path tree
COMMAND=$1
shift

# Get arguments of the command
COMMAND_ARGS=()
until [ -z "$1"  ]
do
    COMMAND_ARGS+=("$1")
    shift
done

####################################################################################################

# Make a tree
PATH_0=()
DIR_NAMES=(/)
USED_CHECKER=(0)
PARENTS=(-1)
CHILDREN_COUNT=(0)
INDEX_TOP=1

# global FOUND_ROOT)
#  It lets us to know where the root directory of subversion places.
#  In a process of making tree, FOUND_ROOT gets more upper index of table,
#  of which the indices of nodes are described, as the process is progressed.
FOUND_ROOT=0

# arguments)
#  $1: index of current node.
#      a root index 0 means root directory /.
#      this function assumes that all paths are absolute paths.
#      argument $1 must be greater than or equal to 0.
#  $2: array of directory name tokens of which the path is AWKed with delimiter '/'.
#      a first element of the array is must be a child directory of root.
#      argument $2 could be empty and it is a condition to exit this function.
function AddDirectoryNode()
{
    # dbg:
    ##echo $1
    ##echo ${!2}

    INDEX=$1
    PATH_TOKENS=(${!2})
    PATH_COUNT=${#PATH_TOKENS[@]}

    if [ $PATH_COUNT -le 0 ]
    then
        # dbg:
        ##echo "Reaching to the end"
        return
    fi

    # NOTE:
    # 아래는 단순 문자열에 대한 조합을 이용하여 원본 배열명과 모든 원소 나열 기호를
    # 이용한 뒤, 실제 배열에 접근할 땐 인자 확장 기능을 사용하여 배열에 접근, 전체를 복사한다.
    # 이를 통해 얻은 것은 사본이기 때문에 원본 내용의 변경을 위해선 다시 이 과정을 반복해야 한다.
    # IGNORE:
    ##ARRARY_CONCAT=PATH_$INDEX[@]

    # NOTE:
    # 위 IGNORE 처리된 주석은 잘못된 변수명 조합의 이용 예로 기록해둘 것.
    # 변수명을 합칠 때 문자열이 제대로 전달될 수 있도록 ""를 꼭 써야 함
    ARRAY_CONCAT=PATH_"$INDEX""[@]"
    CURRENT_ARRAY=(${!ARRAY_CONCAT})
    CURRENT_COUNT=${#CURRENT_ARRAY[@]}

    # dbg:
    ##echo -: $ARRAY_CONCAT ":: (" ${CURRENT_ARRAY[@]} ") :: size="$CURRENT_COUNT

    NODE=${PATH_TOKENS[0]}

    FOUND_CHILD=-1
    if [ $CURRENT_COUNT -gt 0 ]
    then
        for CHILD_NODE in ${CURRENT_ARRAY[@]}
        do
            # dbg:
            ##echo -: ${DIR_NAMES[$CHILD_NODE]} is equal to $NODE ?
            if [ ${DIR_NAMES[$CHILD_NODE]} == $NODE ]
            then
                FOUND_CHILD=$CHILD_NODE
                # dbg:
                ##echo "CHILD_FOUND!" ${DIR_NAMES[$CHILD_NODE]}
                break
            fi
        done
    fi


    if [ $FOUND_CHILD -eq -1 ]
    then
        # impossible:
        ##let PATH_$INDEX_TOP=()

        # NOTE:
        let PATH_$INDEX[$CURRENT_COUNT]=$INDEX_TOP
        DIR_NAMES[$INDEX_TOP]=$NODE
        USED_CHECKER[$INDEX_TOP]=0
        PARENTS[$INDEX_TOP]=$INDEX
        CHILDREN_COUNT[$INDEX]=`expr $CURRENT_COUNT + 1`
        FOUND_CHILD=$INDEX_TOP

        # dbg:
        #DBG_ARRAY=(${!ARRAY_CONCAT})
        #echo -: No found child! create new child with $INDEX into $ARRAY_CONCAT. - count:${#DBG_ARRAY[@]}
        #echo -- PATH_$INDEX[$CURRENT_COUNT]=${DBG_ARRAY[$CURRENT_COUNT]} - expected:$INDEX_TOP
        #echo -- DIR_NAMES[$INDEX_TOP]=${DIR_NAMES[$INDEX_TOP]} - expected:$NODE

        INDEX_TOP=`expr $INDEX_TOP + 1`
    fi


    # note:
    # CHILDREN_COUNT가 굳이 필요한 것인지 확인할 필요가 있음.
    if [ -z ${CHILDREN_COUNT[$FOUND_CHILD]} ]
    then
        CHILDREN_COUNT[$FOUND_CHILD]=0
        # dbg:
        #echo -: Children_count added.
    fi

    # dbg:
    ##echo -: remain num of paths: $PATH_COUNT "|" used check: ${USED_CHECKER[$FOUND_CHILD]}
    if [ $PATH_COUNT -eq 1 ] && [ ${USED_CHECKER[$FOUND_CHILD]} -eq 0 ]
    then
        USED_CHECKER[$FOUND_CHILD]=1
        FOUND_ROOT=${PARENTS[$FOUND_CHILD]}
        # dbg:
        ##echo "new root candidate found: "$FOUND_ROOT
    fi


    PATH_TOKENS=(${!2:1})
    # dbg:
    #echo --- TEST - PATH_1: ${PATH_1[@]}
    AddDirectoryNode $FOUND_CHILD PATH_TOKENS[@]
}

####################################################################################################

# arguments)
#  $1: index of node that finds direct ancestors.
#  $2: out. name of array that indices of ancestor nodes will be stored.
#  $3: optional. floor boundary which the out array stores into at most
function GetAncestors()
{
    PARENT=$1
    let $2[0]=$1
    TOP=1

    if [ -n "$3" ]
    then
        FLOOR=${PARENTS[$3]}

    else
        FLOOR=-1
    fi

    while [[ ${PARENTS[$PARENT]} -ne $FLOOR ]]
    do
        let $2[$TOP]=${PARENTS[$PARENT]}
        let TOP=TOP+1
        PARENT=${PARENTS[$PARENT]}
    done
}

####################################################################################################

# arguments)
#  $1: index of current node.
#  $2: current level in tree.
function PrintTree()
{
    SPACE="  "
    TAB=
    X=1
    while [[ $X -le $2  ]]
    do
        TAB=$SPACE$TAB
        let X=$X+1
    done
    
    if [ ${USED_CHECKER[$1]} -eq 1 ]
    then
        IS_USED=O
    else
        IS_USED=X
    fi

    echo -e "$TAB""${DIR_NAMES[$1]}" "[$IS_USED]"
    return 1
}

####################################################################################################

function ConcatPath()
{
    CONCAT_PATH="$CONCAT_PATH"${CONCAT_PATH:+/}"${DIR_NAMES[$1]}"
}

function PrintRelativePath()
{
    if [ ${USED_CHECKER[$1]} -eq 1 ]
    then
        PATH_NODES=()
        GetAncestors $1 "PATH_NODES" $FOUND_ROOT
        CONCAT_PATH=
        # dbg:
        ##echo -: ${PATH_NODES[@]}
        WorkWithStack "PATH_NODES" `expr ${#PATH_NODES[@]}` "ConcatPath"

        local OUT_ARRAY_CONCAT="$3""[@]"
        local OUT_ARRAY=(${!OUT_ARRAY_CONCAT})
        local OUT_ARRAY_NUM=${#OUT_ARRAY[@]}
        eval $3[$OUT_ARRAY_NUM]="$CONCAT_PATH\;"

        # Fail cases:
        # let $3[$OUT_ARRAY_NUM]="$CONCAT_PATH"
        #  - let only can be used in arithmetic opration, not string
        # ${!3}+=("$CONCAT_PATH")
        #  - Parameter expansion couldn't substitution to array
        # local TEMP_EXP="$3""[$OUT_ARRAY_NUM]"
        # ${!TEMP_EXP}="$CONCAT_PATH"
        #  - expanding to a value. value=value is not works
        #  - is it works if with 'eval'?
        # $3[$OUT_ARRAY_NUM]="$CONCAT_PATH"
        #  - it needs 'eval'
        
        #${!TEMP_EXP:="$CONCAT_PATH"}

    fi

    return 1
}

####################################################################################################

# arguments)
#  $1: index of first node
#  $2: index of second node
function GetCommonParent()
{
    # dbg:
    ##echo arg1: $1, arg2: $2

    GetAncestors $1 "PARENT_STACK1"
    GetAncestors $2 "PARENT_STACK2"

    # dbg:
    #echo ${PARENT_STACK1[@]}
    #echo ${PARENT_STACK2[@]}

    COMMON=-1
    PARENT_TOP1=`expr ${#PARENT_STACK1[@]} - 1`
    PARENT_TOP2=`expr ${#PARENT_STACK2[@]} - 1`

    SHORT_TOP=$PARENT_TOP1
    if [ $PARENT_TOP1 -gt $PARENT_TOP2 ]
    then
        SHORT_TOP=$PARENT_TOP2
    fi
    
    while [[ ${PARENT_STACK1[$PARENT_TOP1]} -eq ${PARENT_STACK2[$PARENT_TOP2]} ]] && [[ $SHORT_TOP -ge 0 ]]
    do
        COMMON=${PARENT_STACK1[PARENT_TOP1]}

        let PARENT_TOP1=PARENT_TOP1-1
        let PARENT_TOP2=PARENT_TOP2-1
        let SHORT_TOP=SHORT_TOP-1
    done

    return $COMMON
}

function FindNeccesaries()
{
    if [ ${USED_CHECKER[$1]} -eq 0 ]
    then
        return 1
    fi

    GetCommonParent $FOUND_ROOT $1
    RETURN=$?
    if [ $RETURN -ne -1 ]
    then
        FOUND_ROOT=$RETURN
    else
        echo "[ERROR OCCURED] - Unsatisfied situation!"
        echo "-- There are roots more than one..."
        exit -1
    fi

    return 0
}

####################################################################################################

function AddIncludePaths()
{
    if [ ${USED_CHECKER[$1]} -eq 0 ]
    then
        return 1
    fi

    GetAncestors $1 "ANCESTOR_NODES" $FOUND_ROOT

    # Decrease a top of ancvestor stack instead of that remove last element of stack.
    PREV_PWD=`pwd`
    WorkWithStack "ANCESTOR_NODES" ${#ANCESTOR_NODES[@]}-1 "AddAndMoveInto"

    cd $PREV_PWD

    return 0
}

####################################################################################################

# arguments)
#  $1: index of current node.
#  $2: current level in tree.
#      a level starts with 0 which means a root
#  $3: name of function that works with the node index and its level.
#      this returns 1 if it traverse all children otherwise, it stops go down to the child.
#  $4: name of array that includes additional arguments of a function indicated by $3.
#      arguments exported by this array are starts with 3
function Traverse()
{
    ARRAY_CONCAT=PATH_"$1""[@]"
    CURRENT_ARRAY=(${!ARRAY_CONCAT})

    ARGS_CONCAT="$4""[@]"
    ARGS_EXPENDING=(${!ARGS_CONCAT})

    for NODE_INDEX in ${CURRENT_ARRAY[@]}
    do
        $3 $NODE_INDEX $2 ${ARGS_EXPENDING[@]}
        if [ $? -eq 1 ]
        then
            Traverse $NODE_INDEX `expr $2 + 1` "$3" $4
        fi
    done
}

####################################################################################################

# MoveInto
# Functions below use 'cd' command to move into a given directory.
# It is not responsible to restore current directory after the process,
#  following processes have to be care of it and its side-effects.

function MoveInto()
{
    cd ${DIR_NAMES[$1]}
}

function AddAndMoveInto()
{
    DEPTH_OPTION=
    if [ ${USED_CHECKER[$1]} -eq 0 ]
    then
        DEPTH_OPTION="--depth=empty"
    fi
    
    svn add $DEPTH_OPTION --force ${DIR_NAMES[$1]}
    cd ${DIR_NAMES[$1]}
}

####################################################################################################

function WorkWithStack()
{
    STACK_REF="$1""[@]"
    let TOP=$2-1

    STACK=(${!STACK_REF})

    while [[ $TOP -ge 0 ]]
    do
        $3 ${STACK[$TOP]}
        let TOP=TOP-1
    done
}

####################################################################################################

# arguments)
#  $1: index of root node.
#      After this process, a directory directed by a root node is treated as a root directory
#      of SVN repository. and it is called "basecamp".
#  $2: address of SVN repository.
#  $3: ID of the repository.
#  $4: Password of the repository.
function BuildBaseCamp()
{
    GetAncestors $1 "BASECAMP_NODES"

    WorkWithStack "BASECAMP_NODES" ${#BASECAMP_NODES[@]} "MoveInto"

    echo "Basecamp is setup at: "`pwd`

    # issue:
    # There is no behavior when a base directory changes.
    #  Suggestion 1) Clean and rebase
    #   Clear all contents in a repository and remove a .svn meta directory for the basecamp.
    #   It would pollution commit logs of the repo, but is clean.
    #   However, it needs additional proccess that guesses where basecamp places,
    #  or totally clean and rebase for each execution.
    #   Of cource, it accelerates the pollution of repos and consumes many unneccesary spaces
    #  of disk.
    svn checkout "$2" --username "$3" --password "$4" --non-interactive --trust-server-cert --force ./
}

####################################################################################################

while IFS= read -r LINE
do
    # note:
    # Korean
    #  COMPILER_REPLY에 대입한 명령을 직접 수행해보면,
    #  include 경로가 출력되는 행은 맨 앞에 공백을 두고 출력됨.
    #  행의 맨 앞이 공백이면 뒤 따르는 상대경로 꼴의 문자열을 절대경로로
    #  가공해서 출력할 것
    # English
    #  According to a command of which the result is assigned to a COMPILER_REPLY,
    #  include paths are shown in some line of the result, with a space at first.
    #  So that, transform those lines from relative to absolute if
    #  a line has a space at first.
    if [ "${LINE:0:1}" == " " ]; then
        # note:
        #  Recursive removed 
        #INCLUDE_PATH="$(dirname $(readlink -e ${LINE:1}))/$(basename ${LINE:1})"

        # note:
        #  Recursive & symbolic-link removed
        INCLUDE_PATH="$(readlink -f ${LINE:1})"
        PATH_TOKENS=()

        # dbg:
        ##echo $INCLUDE_PATH : ${#PATH_TOKENS[@]} counts

        # note:
        # for는 사용되는 변수 자체를 고쳐서 사용하는 것 같다.
        IFS='/'
        for DIR in $INCLUDE_PATH
        do
            PATH_TOKENS+=($DIR)
        done

        # dbg:
        ##echo $INCLUDE_PATH : ${#PATH_TOKENS[@]} counts

        # note:
        # IFS를 사용해야만 array의 원소를 제거하는 것이 가능하다.
        IFS=' '
        AddDirectoryNode 0 PATH_TOKENS[@]

        IFS=
    fi
done <<< "$COMPILER_REPLY"

####################################################################################################

# dbg:
##echo ${!DIR_NAMES[@]}
##echo ${DIR_NAMES[@]}
##echo ${USED_CHECKER[@]}
##echo ${PARENTS[@]}
##echo "root candidate: "$FOUND_ROOT

Traverse 0 0 "FindNeccesaries"

# dbg:
##echo "root-elect directory: "\'${DIR_NAMES[$FOUND_ROOT]}\' "with index: "$FOUND_ROOT

#GetAncestors 18 "TEST_ARRAY" $FOUND_ROOT
#echo ${TEST_ARRAY[@]}

####################################################################################################

Traverse 0 0 "PrintTree"

function Commit()
{
    EXEC_PWD=`pwd`
    BuildBaseCamp $FOUND_ROOT "$1" "$2" "$3"
    Traverse $FOUND_ROOT 1 "AddIncludePaths"
    svn commit --username "$2" --password "$3"
    cd $EXEC_PWD
}

function ShowIncludePathVS()
{
    #RELATIVE_PATH_ROOT="\$(SolutionDir)TOS_INCLUDE_PATH/"
    # instead:
    DIR_NAMES[$FOUND_ROOT]="\$\(SolutionDir\)TOS_INCLUDE_PATH"


    ARGS_PRINT_REL_PATH=( "REL_PATH_LIST" )
    REL_PATH_LIST=()
    Traverse 0 0 "PrintRelativePath" "ARGS_PRINT_REL_PATH"
    echo ${REL_PATH_LIST[@]}
}

function PrintArgs()
{
    echo $0 $1 $2 $3 $4
}

$COMMAND ${COMMAND_ARGS[@]}
