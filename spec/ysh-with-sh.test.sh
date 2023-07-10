## our_shell: osh
## oils_failures_allowed: 5
# compare_shells: bash

#### Can't use x+= on YSH Int (issue #840)

sh_str=2
echo sh_str=$sh_str

sh_str+=1
echo sh_str=$sh_str

sh_str+=1
echo sh_str=$sh_str

echo

var ysh_int = 2
echo ysh_int=$ysh_int

# What should happen here?

ysh_int+=1
echo ysh_int=$ysh_int

ysh_int+=1
echo ysh_int=$ysh_int

## status: 1
## STDOUT:
sh_str=2
sh_str=21
sh_str=211

ysh_int=2
## END

#### Can't x+= on other YSH types

$SH -c '
var x = /d+/
x+=1
'
echo eggex $?

$SH -c '
var d = {}
d+=1
'
echo Dict $?

# This is unspecified for now, could try to match bash
$SH -c '
declare -A A=()
A+=1
declare -A
'
#echo AssocArray $?

## STDOUT:
eggex 1
Dict 1
## END

#### Shell ${x:-default} with YSH List (issue #954)

var mylist = [1, 2, 3]

echo mylist ${mylist:-default}

var myint = 42

echo myint ${myint:-default}

## STDOUT:
## END


#### Shell ${a[0]} with YSH List (issue #1092)

var a = [1, 2, 3]
echo first ${a[0]}

## STDOUT:
## END


#### Cannot splice nested List

shopt --set parse_at

var mylist = ["ls", {name: 42}]

echo @mylist

## status: 3
## STDOUT:
## END

#### Splice nested Dict

declare -A A=([k]=v [k2]=v2)
echo ${A[@]}

var d ={name: [1, 2, 3]}
echo ${d[@]}

## STDOUT:
v v2
## END


#### Concatenate shell arrays and ${#a}

var a = :|a|
var b = :|b|

echo "len a ${#a[@]}"
echo "len b ${#b[@]}"

pp cell a

var c = a ++ b
pp cell c

echo len c ${#c[@]}

## STDOUT:
len a 1
len b 1
a = (Cell exported:F readonly:F nameref:F val:(value.MaybeStrArray strs:[a]))
c = (Cell exported:F readonly:F nameref:F val:(value.MaybeStrArray strs:[a b]))
len c 2
## END


#### ${#x} on List and Dict

var L = [1,2,3]

echo List ${#L[@]}
echo List ${#L}
# Not supported.  TODO: could be a problem
#echo List ${#L[0]}

declare -a a=(abc d)

echo array ${#a[@]}
echo array ${#a}
echo array ${#a[0]}

var d = {k: 'v', '0': 'abc'}

echo Dict ${#d[@]}
echo Dict ${#d}
# Not supported.  TODO: could be a problem
#echo Dict ${#d[0]}

declare -A d=([k]=v [0]=abc)

echo Assoc ${#d[@]}
echo Assoc ${#d}
echo Assoc ${#d[0]}

## STDOUT:
## END

#### $x for List and Dict

declare -a a=(abc d)
echo array $a
echo array ${a[0]}

var L = [1,2,3]
echo List $L

declare -A A=([k]=v [0]=abc)
echo Assoc $A
echo Assoc ${A[0]}

var d = {k: 'v', '0': 'abc'}
#echo Dict $d

## STDOUT:
array abc
array abc
Assoc abc
Assoc abc
## END
